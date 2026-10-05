import AppKit

/// Drives the cat: a direct port of the oneko.js state machine (run in 8
/// directions, alert, idle, random wash/wall-scratch, tired, sleep), adapted
/// to AppKit's y-up coordinate space. Runs on a ~100 ms timer, matching the
/// original's frame cadence.
final class CatController {
    private let window = CatWindow()
    private var timer: Timer?
    private var activity: NSObjectProtocol?

    var strategy: TargetStrategy = FullChaseStrategy() {
        didSet { wake() }
    }
    /// Pixels moved per tick; oneko.js default is 10 per 100 ms.
    var speed: CGFloat = 10
    var variant: SpriteVariant = .cat {
        didSet { wake() }
    }
    /// 1-in-N chance per idle tick of starting a sleep or scratch animation;
    /// oneko.js uses 200. Lower means a sleepier cat.
    var idleAnimationOdds = 200
    /// How far from its target the cat stops, in points. 0 keeps the classic
    /// oneko distance. Above that the cat slows down as it closes in.
    var personalSpace: CGFloat = 0 {
        didSet { wake() }
    }
    /// Whether a violent mouse swing frightens the cat off to a screen edge.
    var startles = false {
        didSet { if !startles { fright = .none } }
    }

    /// Mouse travel over the last few ticks, for spotting violent swings.
    private var lastMouse: CGPoint?
    private var recentTravel: [CGFloat] = []
    private static let startleTravel: CGFloat = 1500   // points in 0.3 s
    private static let calmTravel: CGFloat = 8         // points per tick
    private static let calmTicksToReturn = 30          // 3 s of calm

    private enum Fright {
        case none
        case jumping(ticksLeft: Int)
        case fleeing(to: CGPoint)
        case hiding(at: CGPoint, calmTicks: Int)
    }
    private var fright = Fright.none

    private var pos: CGPoint
    private var frameCount = 0
    private var idleTime = 0
    private var idleAnimation: String?
    private var idleAnimationFrame = 0

    /// Starts at `position`, or the middle of the main screen.
    init(position: CGPoint? = nil) {
        let screen = NSScreen.main?.frame ?? .init(x: 0, y: 0, width: 800, height: 600)
        pos = position ?? CGPoint(x: screen.midX, y: screen.midY)
    }

    func start() {
        guard timer == nil else { return }
        // Mouse travel from before a hide would read as one huge swing.
        lastMouse = nil
        recentTravel.removeAll()
        // Keep the timer steady while the cat is visible; ended in stop() so
        // the process can App Nap whenever the cat is hidden.
        activity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "Cat animation")
        window.move(center: pos)
        window.orderFrontRegardless()
        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in self?.tick() }
        t.tolerance = 0.02
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        window.orderOut(nil)
        if let activity = activity { ProcessInfo.processInfo.endActivity(activity) }
        activity = nil
    }

    var isRunning: Bool { timer != nil }

    /// Interrupt sleep/idle animations, e.g. when settings change.
    private func wake() {
        resetIdleAnimation()
        idleTime = 0
    }

    private func resetIdleAnimation() {
        idleAnimation = nil
        idleAnimationFrame = 0
    }

    private func setSprite(_ name: String, _ index: Int) {
        window.show(SpriteSheet.sheet(for: variant).frame(name, index))
    }

    private func tick() {
        let mouse = NSEvent.mouseLocation
        let travel = lastMouse.map { hypot(mouse.x - $0.x, mouse.y - $0.y) } ?? 0
        lastMouse = mouse
        recentTravel.append(travel)
        if recentTravel.count > 3 { recentTravel.removeFirst() }
        frameCount += 1

        if startles, handleFright(travel: travel) { return }

        let target = strategy.target(forMouse: mouse, cat: pos)
        let dx = target.x - pos.x
        let dy = target.y - pos.y
        let distance = (dx * dx + dy * dy).squareRoot()

        // With personal space, a settled cat waits until the cursor is
        // clearly further away, so small mouse moves don't make it hop.
        var threshold = max(speed, 48, personalSpace)
        if personalSpace > 0, idleTime > 0 { threshold *= 1.4 }
        if strategy.isSettled(dx: dx, dy: dy, threshold: threshold) {
            idle()
            return
        }
        resetIdleAnimation()

        if idleTime > 1 {
            setSprite("alert", 0)
            // Delay leaving alert pose proportional to how long the cat slept.
            idleTime = min(idleTime, 7) - 1
            return
        }

        // Never overshoot: lets the cat land exactly on a pinned row.
        var step = min(speed, distance)
        if personalSpace > 0 {
            // Ease in over the last stretch instead of stopping dead.
            step = min(step, max(2, (distance - personalSpace) / 3))
        }
        run(dx: dx, dy: dy, distance: distance, step: step)

        // Keep the cat on the screen it's headed toward.
        let bounds = screenContaining(target).frame
        let half = SpriteSheet.frameSize / 2
        pos.x = min(max(pos.x, bounds.minX + half), bounds.maxX - half)
        pos.y = min(max(pos.y, bounds.minY + half), bounds.maxY - half)

        window.move(center: pos)
    }

    /// One running step of `step` points along (dx, dy), with the matching
    /// direction sprite.
    private func run(dx: CGFloat, dy: CGFloat, distance: CGFloat, step: CGFloat) {
        // AppKit is y-up, so dy > 0 means the target is above the cat → run N.
        var direction = ""
        if dy / distance > 0.5 { direction += "N" }
        if dy / distance < -0.5 { direction += "S" }
        if dx / distance < -0.5 { direction += "W" }
        if dx / distance > 0.5 { direction += "E" }
        setSprite(direction, frameCount)
        pos.x += dx / distance * step
        pos.y += dy / distance * step
    }

    /// Startle: a violent swing makes the cat jump, run to the nearest screen
    /// edge and peek out half hidden until the mouse has been calm for a few
    /// seconds. Returns true while the fright owns this tick.
    private func handleFright(travel: CGFloat) -> Bool {
        switch fright {
        case .none:
            guard recentTravel.reduce(0, +) > Self.startleTravel else { return false }
            resetIdleAnimation()
            idleTime = 0
            fright = .jumping(ticksLeft: 3)
            setSprite("alert", 0)
        case .jumping(let ticksLeft):
            setSprite("alert", 0)
            fright = ticksLeft > 1 ? .jumping(ticksLeft: ticksLeft - 1)
                                   : .fleeing(to: nearestEdgeSpot())
        case .fleeing(let spot):
            let dx = spot.x - pos.x
            let dy = spot.y - pos.y
            let distance = (dx * dx + dy * dy).squareRoot()
            if distance < 1 {
                fright = .hiding(at: spot, calmTicks: 0)
                setSprite("idle", 0)
            } else {
                run(dx: dx, dy: dy, distance: distance, step: min(speed * 2.5, distance))
            }
            window.move(center: pos)
        case .hiding(let spot, let calmTicks):
            setSprite("idle", 0)
            let calm = travel < Self.calmTravel ? calmTicks + 1 : 0
            if calm >= Self.calmTicksToReturn {
                fright = .none
                recentTravel.removeAll()
                // Come back out with the usual alert pause.
                idleTime = 4
            } else {
                fright = .hiding(at: spot, calmTicks: calm)
            }
        }
        return true
    }

    /// The point on the nearest edge of the cat's screen where half the cat
    /// is tucked out of sight.
    private func nearestEdgeSpot() -> CGPoint {
        let f = screenContaining(pos).frame
        let spots = [
            (pos.x - f.minX, CGPoint(x: f.minX, y: pos.y)),
            (f.maxX - pos.x, CGPoint(x: f.maxX, y: pos.y)),
            (pos.y - f.minY, CGPoint(x: pos.x, y: f.minY)),
            (f.maxY - pos.y, CGPoint(x: pos.x, y: f.maxY)),
        ]
        return spots.min { $0.0 < $1.0 }!.1
    }

    private func idle() {
        idleTime += 1

        // Rarely start a one-off idle animation (sleep, wash, or scratch a
        // nearby screen edge) — same odds as oneko.js.
        if idleTime > 10, Int.random(in: 0..<idleAnimationOdds) == 0, idleAnimation == nil {
            var options = ["sleeping", "scratchSelf"]
            let bounds = screenContaining(pos).frame
            if pos.x < bounds.minX + 32 { options.append("scratchWallW") }
            if pos.x > bounds.maxX - 32 { options.append("scratchWallE") }
            if pos.y > bounds.maxY - 32 { options.append("scratchWallN") }
            if pos.y < bounds.minY + 32 { options.append("scratchWallS") }
            idleAnimation = options.randomElement()
        }

        switch idleAnimation {
        case "sleeping":
            if idleAnimationFrame < 8 {
                setSprite("tired", 0)
            } else {
                setSprite("sleeping", idleAnimationFrame / 4)
            }
            if idleAnimationFrame > 192 { resetIdleAnimation() }
        case "scratchSelf", "scratchWallN", "scratchWallS", "scratchWallE", "scratchWallW":
            setSprite(idleAnimation!, idleAnimationFrame)
            if idleAnimationFrame > 9 { resetIdleAnimation() }
        default:
            setSprite("idle", 0)
            return
        }
        idleAnimationFrame += 1
    }
}

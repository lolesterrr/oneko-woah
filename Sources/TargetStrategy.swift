import AppKit

/// Computes where the cat should run to for a given global mouse location.
/// This is the single swappable piece that distinguishes full 2D chasing from
/// horizontal-only mode; the animation/direction code never branches on mode.
protocol TargetStrategy {
    func target(forMouse mouse: CGPoint) -> CGPoint
    /// Called by the controller each tick; `cat` is the cat's current center.
    /// Strategies that don't care where the cat is only implement the
    /// single-argument version.
    func target(forMouse mouse: CGPoint, cat: CGPoint) -> CGPoint
    /// Movement to apply to the cat without walking, e.g. riding along on a
    /// window that's being dragged. Asked once per tick, after `target`.
    func takeDrift() -> CGVector
    /// Whether the cat is close enough to its target to stop and idle.
    /// `dx`/`dy` are target minus cat position; `threshold` is the classic
    /// oneko stop distance.
    func isSettled(dx: CGFloat, dy: CGFloat, threshold: CGFloat) -> Bool
}

extension TargetStrategy {
    func target(forMouse mouse: CGPoint, cat: CGPoint) -> CGPoint {
        target(forMouse: mouse)
    }

    func takeDrift() -> CGVector { .zero }

    func isSettled(dx: CGFloat, dy: CGFloat, threshold: CGFloat) -> Bool {
        (dx * dx + dy * dy).squareRoot() < threshold
    }
}

func screenContaining(_ point: CGPoint) -> NSScreen {
    NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
        ?? NSScreen.main
        ?? NSScreen.screens[0]
}

/// Classic behavior: chase the cursor anywhere on any screen.
struct FullChaseStrategy: TargetStrategy {
    func target(forMouse mouse: CGPoint) -> CGPoint { mouse }
}

enum DockEdge: String {
    case top, bottom
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}

/// Locks the cat to a single display by clamping the cursor into that
/// display's frame before the base strategy sees it: when the cursor is on
/// another screen the cat waits at the nearest edge instead of following.
/// Falls back to the base behavior while the display is disconnected.
struct DisplayLockedStrategy: TargetStrategy {
    let base: TargetStrategy
    let displayID: CGDirectDisplayID

    func target(forMouse mouse: CGPoint) -> CGPoint {
        guard let frame = NSScreen.screens.first(where: { $0.displayID == displayID })?.frame
        else { return base.target(forMouse: mouse) }
        // NSMouseInRect (unflipped) counts [minX, maxX) × (minY, maxY] as
        // inside; clamp just within those bounds so screenContaining can't
        // resolve to a neighboring screen.
        let clamped = CGPoint(x: min(max(mouse.x, frame.minX), frame.maxX.nextDown),
                              y: min(max(mouse.y, frame.minY.nextUp), frame.maxY))
        return base.target(forMouse: clamped)
    }

    func isSettled(dx: CGFloat, dy: CGFloat, threshold: CGFloat) -> Bool {
        base.isSettled(dx: dx, dy: dy, threshold: threshold)
    }
}

/// Horizontal-only mode: the cat ignores the cursor's y entirely and stays
/// pinned to a row along the top or bottom edge. The row belongs to whichever
/// screen currently contains the cursor, so the cat follows the cursor across
/// monitors (running to the new screen's edge row when the cursor switches).
struct HorizontalPinnedStrategy: TargetStrategy {
    let edge: DockEdge

    func target(forMouse mouse: CGPoint) -> CGPoint {
        let frame = screenContaining(mouse).frame
        let half = SpriteSheet.frameSize / 2
        let y = edge == .top ? frame.maxY - half : frame.minY + half
        return CGPoint(x: mouse.x, y: y)
    }

    /// The cat keeps its distance horizontally but must land exactly on the
    /// pinned row — otherwise it stops a few pixels off the edge.
    func isSettled(dx: CGFloat, dy: CGFloat, threshold: CGFloat) -> Bool {
        abs(dx) < threshold && abs(dy) < 1
    }
}

/// The lazy cat: ignores the cursor. It sits where it is and, every few
/// minutes, strolls somewhere new: half the time a random spot on its
/// screen, otherwise the top of the frontmost app's window, where it sits
/// and rides along when the window is dragged. When the app in front
/// changes it moves over to the new front window; when its window closes,
/// minimizes or goes full screen it hops back down.
final class WanderStrategy: TargetStrategy {
    /// Whether the cat may sit on windows.
    var perches = true {
        didSet { if !perches { perch = nil } }
    }
    /// Seconds between strolls.
    private let interval: ClosedRange<TimeInterval> = 90...300
    private var spot: CGPoint?
    /// The first stroll comes sooner, so the cat shows it can move.
    private var nextStroll = Date().addingTimeInterval(.random(in: 20...60))

    private struct Perch {
        let window: CGWindowID
        let pid: pid_t
        /// Where along the window's top edge the cat sits.
        let offsetX: CGFloat
    }
    private var perch: Perch?
    private var drift = CGVector.zero

    /// Unused: the controller always asks with the cat's position.
    func target(forMouse mouse: CGPoint) -> CGPoint { spot ?? mouse }

    func target(forMouse mouse: CGPoint, cat: CGPoint) -> CGPoint {
        let now = Date()
        if now >= nextStroll {
            nextStroll = now.addingTimeInterval(.random(in: interval))
            perch = nil
            if perches, Bool.random() { perchOnFrontWindow() }
            if perch == nil { spot = Self.randomSpot(near: cat) }
        }
        if let current = perch {
            followPerch(current, cat: cat)
        }
        if let spot = spot { return spot }
        spot = cat
        return cat
    }

    func takeDrift() -> CGVector {
        defer { drift = .zero }
        return drift
    }

    private func perchOnFrontWindow() {
        guard let front = WindowWatch.frontWindow() else { return }
        let margin = SpriteSheet.frameSize
        perch = Perch(window: front.id, pid: front.pid,
                      offsetX: .random(in: margin...(front.frame.width - margin)))
        spot = Self.spot(on: front.frame, offsetX: perch!.offsetX)
    }

    private func followPerch(_ current: Perch, cat: CGPoint) {
        // Another app came to the front: go and sit on its window instead.
        if NSWorkspace.shared.frontmostApplication?.processIdentifier != current.pid {
            perch = nil
            perchOnFrontWindow()
            if perch == nil { spot = Self.randomSpot(near: cat) }
            return
        }
        guard let frame = WindowWatch.frame(of: current.window) else {
            // The window went away: hop back down.
            perch = nil
            spot = Self.randomSpot(near: cat)
            return
        }
        let newSpot = Self.spot(on: frame, offsetX: min(current.offsetX, frame.width - 8))
        // Sitting on the window (not still walking to it): ride along.
        if let old = spot, hypot(cat.x - old.x, cat.y - old.y) < 48 {
            drift = CGVector(dx: newSpot.x - old.x, dy: newSpot.y - old.y)
        }
        spot = newSpot
    }

    /// The cat's center when sitting on top of `frame`, feet on the edge.
    private static func spot(on frame: CGRect, offsetX: CGFloat) -> CGPoint {
        CGPoint(x: frame.minX + offsetX, y: frame.maxY + SpriteSheet.frameSize / 2)
    }

    /// Somewhere on the cat's current screen, clear of the menu bar and Dock.
    private static func randomSpot(near cat: CGPoint) -> CGPoint {
        let area = screenContaining(cat).visibleFrame
            .insetBy(dx: SpriteSheet.frameSize, dy: SpriteSheet.frameSize)
        guard area.width > 0, area.height > 0 else { return cat }
        return CGPoint(x: .random(in: area.minX...area.maxX),
                       y: .random(in: area.minY...area.maxY))
    }
}

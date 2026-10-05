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
    /// Whether the cat is close enough to its target to stop and idle.
    /// `dx`/`dy` are target minus cat position; `threshold` is the classic
    /// oneko stop distance.
    func isSettled(dx: CGFloat, dy: CGFloat, threshold: CGFloat) -> Bool
}

extension TargetStrategy {
    func target(forMouse mouse: CGPoint, cat: CGPoint) -> CGPoint {
        target(forMouse: mouse)
    }

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
/// minutes, picks a random spot on the screen it's on and strolls there.
final class WanderStrategy: TargetStrategy {
    /// Seconds between strolls.
    private let interval: ClosedRange<TimeInterval> = 90...300
    private var spot: CGPoint?
    /// The first stroll comes sooner, so the cat shows it can move.
    private var nextStroll = Date().addingTimeInterval(.random(in: 20...60))

    /// Unused: the controller always asks with the cat's position.
    func target(forMouse mouse: CGPoint) -> CGPoint { spot ?? mouse }

    func target(forMouse mouse: CGPoint, cat: CGPoint) -> CGPoint {
        let now = Date()
        if now >= nextStroll {
            spot = Self.randomSpot(near: cat)
            nextStroll = now.addingTimeInterval(.random(in: interval))
        }
        if let spot = spot { return spot }
        spot = cat
        return cat
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

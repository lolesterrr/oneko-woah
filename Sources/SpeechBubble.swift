import AppKit

/// A small comic-style speech bubble that floats above a cat and follows it
/// while it's showing. Click-through; it fades out on its own, or on a click
/// of the cat.
final class SpeechBubble {
    private let window: NSWindow
    private let bubbleView = BubbleView()
    private var followTimer: Timer?
    private var hideWork: DispatchWorkItem?
    private var anchor: (() -> CGPoint)?

    var isShowing: Bool { window.isVisible }

    init() {
        window = NSWindow(contentRect: .zero, styleMask: .borderless,
                          backing: .buffered, defer: true)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.ignoresMouseEvents = true
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary,
                                     .ignoresCycle]
        window.isReleasedWhenClosed = false
        window.contentView = bubbleView
    }

    /// Shows `text` above the point `anchor` returns (a cat's center), for
    /// a few seconds depending on its length.
    func say(_ text: String, above anchor: @escaping () -> CGPoint) {
        self.anchor = anchor
        bubbleView.text = text
        window.setContentSize(bubbleView.fittingSize)
        bubbleView.frame = NSRect(origin: .zero, size: bubbleView.fittingSize)
        reposition()
        window.alphaValue = 1
        window.orderFrontRegardless()

        followTimer?.invalidate()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.reposition()
        }
        RunLoop.main.add(timer, forMode: .common)
        followTimer = timer

        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.dismiss() }
        hideWork = work
        let seconds = min(14, 4 + Double(text.count) / 12)
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    func dismiss() {
        hideWork?.cancel()
        hideWork = nil
        followTimer?.invalidate()
        followTimer = nil
        guard window.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            // A new bubble may have started during the fade.
            guard let self = self, self.followTimer == nil else { return }
            self.window.orderOut(nil)
        })
    }

    /// Above the cat with the tail pointing down at it, kept on screen. Near
    /// the top of the screen it flips below the cat.
    private func reposition() {
        guard let point = anchor?() else { return }
        let size = window.frame.size
        let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main
        let bounds = screen?.visibleFrame ?? NSRect(origin: .zero, size: size)
        let catHalf = SpriteSheet.frameSize / 2
        var origin = NSPoint(x: point.x - BubbleView.tailInset - BubbleView.tailWidth / 2,
                             y: point.y + catHalf)
        var flipped = false
        if origin.y + size.height > bounds.maxY {
            origin.y = point.y - catHalf - size.height
            flipped = true
        }
        origin.x = min(max(origin.x, bounds.minX), bounds.maxX - size.width)
        bubbleView.tailX = point.x - origin.x
        bubbleView.tailOnTop = flipped
        window.setFrameOrigin(origin)
    }
}

/// Draws the bubble: rounded box, little tail, the text inside.
private final class BubbleView: NSView {
    static let tailWidth: CGFloat = 10
    static let tailHeight: CGFloat = 8
    static let tailInset: CGFloat = 14
    private static let padding: CGFloat = 8
    private static let maxTextWidth: CGFloat = 240

    private let label = NSTextField(wrappingLabelWithString: "")

    var text = "" {
        didSet {
            label.stringValue = text
            needsLayout = true
        }
    }
    /// Where the tail meets the cat, in this view's coordinates.
    var tailX: CGFloat = 20 { didSet { if tailX != oldValue { needsDisplay = true } } }
    var tailOnTop = false {
        didSet {
            guard tailOnTop != oldValue else { return }
            needsLayout = true
            needsDisplay = true
        }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .black
        label.isSelectable = false
        label.preferredMaxLayoutWidth = Self.maxTextWidth
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private var textSize: NSSize {
        let size = label.cell?.cellSize(forBounds: NSRect(
            x: 0, y: 0, width: Self.maxTextWidth, height: .greatestFiniteMagnitude))
            ?? .zero
        return NSSize(width: ceil(min(size.width, Self.maxTextWidth)), height: ceil(size.height))
    }

    override var fittingSize: NSSize {
        let text = textSize
        return NSSize(width: text.width + Self.padding * 2,
                      height: text.height + Self.padding * 2 + Self.tailHeight)
    }

    private var boxRect: NSRect {
        var rect = bounds
        rect.size.height -= Self.tailHeight
        if !tailOnTop { rect.origin.y += Self.tailHeight }
        return rect
    }

    override func layout() {
        super.layout()
        let size = textSize
        label.frame = NSRect(x: Self.padding, y: boxRect.minY + Self.padding,
                             width: size.width, height: size.height)
    }

    override func draw(_ dirtyRect: NSRect) {
        let box = boxRect.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: box, xRadius: 8, yRadius: 8)
        let x = min(max(tailX, box.minX + 10), box.maxX - 10)
        let half = Self.tailWidth / 2
        let tail = NSBezierPath()
        if tailOnTop {
            tail.move(to: NSPoint(x: x - half, y: box.maxY - 1))
            tail.line(to: NSPoint(x: x, y: bounds.maxY - 1))
            tail.line(to: NSPoint(x: x + half, y: box.maxY - 1))
        } else {
            tail.move(to: NSPoint(x: x - half, y: box.minY + 1))
            tail.line(to: NSPoint(x: x, y: bounds.minY + 1))
            tail.line(to: NSPoint(x: x + half, y: box.minY + 1))
        }
        tail.close()
        path.append(tail)
        NSColor.white.setFill()
        path.fill()
        NSColor.black.setStroke()
        path.lineWidth = 1.5
        path.stroke()
        // Paint over the seam between box and tail.
        let seam = NSRect(x: x - half + 1.5, y: tailOnTop ? box.maxY - 1.5 : box.minY - 1,
                          width: Self.tailWidth - 3, height: 2.5)
        NSColor.white.setFill()
        seam.fill()
    }
}

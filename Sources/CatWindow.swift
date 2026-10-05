import AppKit

/// Borderless transparent 32x32 overlay that hosts the cat sprite.
/// Click-through, above full-screen apps and the menu bar, on every Space.
final class CatWindow: NSWindow {
    private let spriteLayer = CALayer()
    private var lastImage: CGImage?

    init() {
        let size = SpriteSheet.frameSize
        super.init(contentRect: NSRect(x: 0, y: 0, width: size, height: size),
                   styleMask: .borderless, backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary,
                              .ignoresCycle]
        isReleasedWhenClosed = false

        let view = CatView(frame: contentRect(forFrameRect: frame))
        view.wantsLayer = true
        spriteLayer.frame = view.bounds
        spriteLayer.magnificationFilter = .nearest  // keep pixel art crisp on retina
        view.layer?.addSublayer(spriteLayer)
        contentView = view
    }

    func show(_ image: CGImage?) {
        // Frames are cached per sheet, so identity is stable: skip the commit
        // when the sprite hasn't changed (idle/sleeping cat, 10x/sec).
        guard image !== lastImage else { return }
        lastImage = image
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        spriteLayer.contents = image
        CATransaction.commit()
    }

    /// Lets this cat take clicks and file drops instead of passing them
    /// through: left click pets it, right click (or control-click) opens
    /// `menu()`, and files dropped on it go to `onDrop`.
    func makeInteractive(menu: @escaping () -> NSMenu?,
                         onDrop: @escaping ([URL]) -> Void,
                         onClick: @escaping () -> Void) {
        guard let view = contentView as? CatView else { return }
        view.menuProvider = menu
        view.onDrop = onDrop
        view.onClick = onClick
        view.registerForDraggedTypes([.fileURL])
        ignoresMouseEvents = false
    }

    /// Positions the window so the cat's center sits at `center` (global coords).
    func move(center: CGPoint) {
        let half = SpriteSheet.frameSize / 2
        setFrameOrigin(NSPoint(x: center.x - half, y: center.y - half))
    }
}

/// The cat's content view; only handles input once the window is made
/// interactive.
private final class CatView: NSView {
    var menuProvider: (() -> NSMenu?)?
    var onDrop: (([URL]) -> Void)?
    var onClick: (() -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            showMenu(event)
        } else {
            onClick?()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        showMenu(event)
    }

    private func showMenu(_ event: NSEvent) {
        guard let menu = menuProvider?() else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onDrop == nil ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(
                  forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
              !urls.isEmpty
        else { return false }
        onDrop?(urls)
        return true
    }
}

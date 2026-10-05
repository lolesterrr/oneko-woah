import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// The chaser: the classic cat that follows the cursor.
    private let cat = CatController()
    /// The lazy cat ignores the cursor, naps a lot and wanders now and then.
    private let wander = WanderStrategy()
    private let clipboard = ClipboardHolder()
    private let mail = MailWatch()
    private let bubble = SpeechBubble()
    private var jokeTimer: Timer?
    private let lazyCat: CatController = {
        let screen = NSScreen.main?.visibleFrame ?? .init(x: 0, y: 0, width: 800, height: 600)
        let cat = CatController(position: CGPoint(x: screen.minX + screen.width * 0.25,
                                                  y: screen.minY + SpriteSheet.frameSize))
        cat.speed = 4
        cat.idleAnimationOdds = 50
        cat.variant = .pierre
        return cat
    }()
    private var statusItem: NSStatusItem!

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let hidden = "catHidden"
        static let speed = "catSpeed"
        static let horizontal = "horizontalMode"
        static let edge = "dockEdge"
        static let variant = "spriteVariant"
        static let display = "lockedDisplay"
        static let displayName = "lockedDisplayName"
        static let displayUUID = "lockedDisplayUUID"
        static let loginItemDefaulted = "loginItemDefaulted"
        static let lazyHidden = "lazyCatHidden"
        static let personalSpace = "personalSpace"
        static let lazyPerches = "lazyCatPerches"
        static let clipboard = "lazyCatHoldsClipboard"
        static let mail = "lazyCatWatchesMail"
        static let jokes = "lazyCatTellsJokes"
        static let startle = "startle"
        static let reactions = "reactions"
    }

    // Menu items whose state we refresh.
    private var showHideItem: NSMenuItem!
    private var lazyShowHideItem: NSMenuItem!
    private var perchItem: NSMenuItem!
    private var clipboardItem: NSMenuItem!
    private var mailItem: NSMenuItem!
    private var jokesItem: NSMenuItem!
    private var horizontalItem: NSMenuItem!
    private var spaceItems: [NSMenuItem] = []
    private var startleItem: NSMenuItem!
    private var reactionsItem: NSMenuItem!
    private var topItem: NSMenuItem!
    private var bottomItem: NSMenuItem!
    private var speedItems: [NSMenuItem] = []
    private var variantItems: [NSMenuItem] = []
    private var displayMenu: NSMenu!
    private var displayItems: [NSMenuItem] = []
    private var loginItem: NSMenuItem!

    private static let speeds: [(String, CGFloat)] = [
        ("Slow", 5), ("Normal", 10), ("Fast", 20),
    ]
    /// How far from the cursor the chaser stops; 0 is the classic oneko
    /// behaviour of curling up right next to it.
    private static let spaces: [(String, CGFloat)] = [
        ("Off (Classic)", 0), ("Close", 50), ("Comfortable", 75), ("Far", 100),
    ]

    /// URLs can arrive before applicationDidFinishLaunching when the app is
    /// launched by an open request; the menu isn't built yet, so hold them.
    private var pendingURLs: [URL] = []
    private var finishedLaunching = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        lazyCat.strategy = wander
        setUpClipboard()
        setUpMail()
        scheduleJoke(first: true)
        enableLaunchAtLoginOnFirstRun()
        reconcileLockedDisplay()
        setUpStatusItem()
        applySettings()
        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        watchClicksAndScrolls()
        if !defaults.bool(forKey: Keys.hidden) {
            cat.start()
        }
        if !defaults.bool(forKey: Keys.lazyHidden) {
            lazyCat.start()
        }
        updateLazyCatFeatures()
        refreshMenuState()
        finishedLaunching = true
        pendingURLs.forEach(handle)
        pendingURLs.removeAll()
    }

    // MARK: - URL scheme (oneko://)

    func application(_ application: NSApplication, open urls: [URL]) {
        guard finishedLaunching else {
            pendingURLs.append(contentsOf: urls)
            return
        }
        urls.forEach(handle)
    }

    /// oneko://show | hide | toggle | quit
    /// oneko://skin/<variant>       (SpriteVariant rawValue, e.g. sakura)
    /// oneko://speed/<slow|normal|fast>
    private func handle(_ url: URL) {
        let argument = url.pathComponents.dropFirst().first
        switch url.host {
        case "show": setShown(true)
        case "hide": setShown(false)
        case "toggle": setShown(!cat.isRunning)
        case "quit": NSApp.terminate(nil)
        case "skin":
            guard let variant = argument.flatMap(SpriteVariant.init(rawValue:)) else {
                return NSLog("Unknown skin in URL: \(url)")
            }
            defaults.set(variant.rawValue, forKey: Keys.variant)
            applySettings()
            refreshMenuState()
        case "speed":
            guard let value = Self.speeds.first(where: {
                $0.0.lowercased() == argument?.lowercased()
            })?.1 else {
                return NSLog("Unknown speed in URL: \(url)")
            }
            defaults.set(Double(value), forKey: Keys.speed)
            applySettings()
            refreshMenuState()
        default:
            NSLog("Unknown URL command: \(url)")
        }
    }

    private func setUpStatusItem() {
        // Variable length so the unread mail count can sit next to the icon.
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.imagePosition = .imageLeft
        // Fallbacks if the bundled icon is missing: cat.fill needs macOS 14,
        // pawprint.fill covers 11.
        if let icon = Self.makeStatusIcon() {
            statusItem.button?.image = icon
        } else if let icon = NSImage(systemSymbolName: "cat.fill", accessibilityDescription: "Monsieur Pierre")
            ?? NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "Monsieur Pierre") {
            statusItem.button?.image = icon
        } else {
            statusItem.button?.title = "🐱"
        }

        let menu = NSMenu()

        let speedMenu = NSMenu()
        for (name, value) in Self.speeds {
            let item = speedMenu.addItem(withTitle: name,
                                         action: #selector(setSpeed(_:)), keyEquivalent: "")
            item.representedObject = value
            speedItems.append(item)
        }
        let speedItem = menu.addItem(withTitle: "Speed", action: nil, keyEquivalent: "")
        speedItem.submenu = speedMenu

        let variantMenu = NSMenu()
        for (groupName, variants) in SpriteVariant.groups {
            let groupMenu = NSMenu()
            for variant in variants {
                let item = groupMenu.addItem(withTitle: variant.title,
                                             action: #selector(setVariant(_:)), keyEquivalent: "")
                item.representedObject = variant.rawValue
                item.image = SpriteSheet.menuIcon(for: variant)
                variantItems.append(item)
            }
            let groupItem = variantMenu.addItem(withTitle: groupName, action: nil, keyEquivalent: "")
            groupItem.submenu = groupMenu
        }
        let variantItem = menu.addItem(withTitle: "Sprite", action: nil, keyEquivalent: "")
        variantItem.submenu = variantMenu

        displayMenu = NSMenu()
        // Manual isEnabled control for the "(disconnected)" indicator row.
        displayMenu.autoenablesItems = false
        rebuildDisplayMenu()
        let displayItem = menu.addItem(withTitle: "Display", action: nil, keyEquivalent: "")
        displayItem.submenu = displayMenu

        let spaceMenu = NSMenu()
        for (name, value) in Self.spaces {
            let item = spaceMenu.addItem(withTitle: name,
                                         action: #selector(setPersonalSpace(_:)), keyEquivalent: "")
            item.representedObject = value
            spaceItems.append(item)
        }
        let spaceItem = menu.addItem(withTitle: "Personal Space", action: nil, keyEquivalent: "")
        spaceItem.submenu = spaceMenu
        startleItem = menu.addItem(withTitle: "Startled by Fast Moves",
                                   action: #selector(toggleStartle), keyEquivalent: "")
        reactionsItem = menu.addItem(withTitle: "Reacts to Clicks, Scrolling & Typing",
                                     action: #selector(toggleReactions), keyEquivalent: "")

        horizontalItem = menu.addItem(withTitle: "Horizontal-Only Mode",
                                      action: #selector(toggleHorizontal), keyEquivalent: "")
        let edgeMenu = NSMenu()
        // Auto-enablement would keep these clickable even when horizontal mode
        // is off; refreshMenuState manages isEnabled itself.
        edgeMenu.autoenablesItems = false
        topItem = edgeMenu.addItem(withTitle: "Dock to Top",
                                   action: #selector(setEdge(_:)), keyEquivalent: "")
        topItem.representedObject = DockEdge.top.rawValue
        bottomItem = edgeMenu.addItem(withTitle: "Dock to Bottom",
                                      action: #selector(setEdge(_:)), keyEquivalent: "")
        bottomItem.representedObject = DockEdge.bottom.rawValue
        let edgeItem = menu.addItem(withTitle: "Dock Edge", action: nil, keyEquivalent: "")
        edgeItem.submenu = edgeMenu

        menu.addItem(.separator())
        loginItem = menu.addItem(withTitle: "Launch at Login",
                                 action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        menu.addItem(.separator())
        showHideItem = menu.addItem(withTitle: "Hide Chaser",
                            action: #selector(toggleShown), keyEquivalent: "")
        lazyShowHideItem = menu.addItem(withTitle: "Hide Lazy Cat",
                                        action: #selector(toggleLazyShown), keyEquivalent: "")
        perchItem = menu.addItem(withTitle: "Lazy Cat Sits on Windows",
                                 action: #selector(togglePerches), keyEquivalent: "")
        clipboardItem = menu.addItem(withTitle: "Lazy Cat Holds Your Clipboard",
                                     action: #selector(toggleClipboard), keyEquivalent: "")
        mailItem = menu.addItem(withTitle: "Lazy Cat Watches Your Mail",
                                action: #selector(toggleMail), keyEquivalent: "")
        jokesItem = menu.addItem(withTitle: "Lazy Cat Tells Jokes",
                                 action: #selector(toggleJokes), keyEquivalent: "")
        menu.addItem(withTitle: "Quit Monsieur Pierre", action: #selector(quit), keyEquivalent: "q")

        for item in menu.items { item.target = self }
        for item in speedItems + spaceItems + variantItems + [topItem!, bottomItem!] {
            item.target = self
        }
        statusItem.menu = menu
    }

    /// One item per connected screen, plus "All Displays". Rebuilt whenever
    /// displays are added, removed, or rearranged.
    private func rebuildDisplayMenu() {
        displayMenu.removeAllItems()
        displayItems.removeAll()
        let all = displayMenu.addItem(withTitle: "All Displays",
                                      action: #selector(setDisplay(_:)), keyEquivalent: "")
        displayItems.append(all)
        displayMenu.addItem(.separator())
        var seenNames: [String: Int] = [:]
        for screen in NSScreen.screens {
            guard let id = screen.displayID else { continue }
            // Identical monitors report the same localizedName; number them.
            var name = screen.localizedName
            let n = seenNames[name, default: 0] + 1
            seenNames[name] = n
            if n > 1 { name += " (\(n))" }
            let item = displayMenu.addItem(withTitle: name,
                                           action: #selector(setDisplay(_:)), keyEquivalent: "")
            item.representedObject = Int(id)
            displayItems.append(item)
        }
        // Keep the lock visible while its display is unplugged, so the
        // unchecked list doesn't read as "no lock active".
        if let id = lockedDisplayID, !NSScreen.screens.contains(where: { $0.displayID == id }) {
            let name = defaults.string(forKey: Keys.displayName) ?? "Locked Display"
            let item = displayMenu.addItem(withTitle: "\(name) (disconnected)",
                                           action: nil, keyEquivalent: "")
            item.isEnabled = false
            item.representedObject = Int(id)
            displayItems.append(item)
        }
        for item in displayItems { item.target = self }
    }

    @objc private func screensChanged() {
        // Re-apply only when the ID moved: the active DisplayLockedStrategy
        // captured its ID at applySettings time, but replacing the strategy
        // wakes the cat, so don't do it for every resolution change.
        if reconcileLockedDisplay() { applySettings() }
        rebuildDisplayMenu()
        refreshMenuState()
    }

    /// oneko-icon.png is 15x15 pixel art. A drawing handler renders it per
    /// backing scale with interpolation off, so it stays crisp on any display.
    private static func makeStatusIcon() -> NSImage? {
        guard let url = Bundle.main.url(forResource: "oneko-icon", withExtension: "png"),
              let base = NSImage(contentsOf: url),
              let cg = base.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return nil }
        // The asset is 1x art: its pixel size is its point size.
        let size = NSSize(width: cg.width, height: cg.height)
        let icon = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.interpolationQuality = .none
            ctx.draw(cg, in: rect)
            return true
        }
        icon.accessibilityDescription = "Monsieur Pierre"
        return icon
    }

    // MARK: - Settings

    private var dockEdge: DockEdge {
        DockEdge(rawValue: defaults.string(forKey: Keys.edge) ?? "") ?? .bottom
    }

    private var spriteVariant: SpriteVariant {
        SpriteVariant(rawValue: defaults.string(forKey: Keys.variant) ?? "") ?? .cat
    }

    private var speed: Double {
        defaults.object(forKey: Keys.speed) as? Double ?? 10
    }

    /// Defaults to Comfortable: the cat keeps you company rather than
    /// sitting on the cursor.
    private var personalSpace: Double {
        defaults.object(forKey: Keys.personalSpace) as? Double ?? 75
    }

    private var startles: Bool {
        defaults.object(forKey: Keys.startle) as? Bool ?? true
    }

    private var lazyPerches: Bool {
        defaults.object(forKey: Keys.lazyPerches) as? Bool ?? true
    }

    private var holdsClipboard: Bool {
        defaults.object(forKey: Keys.clipboard) as? Bool ?? true
    }

    /// Off until turned on: the first check makes macOS ask for permission
    /// to control Mail.
    private var watchesMail: Bool {
        defaults.bool(forKey: Keys.mail)
    }

    private var tellsJokes: Bool {
        defaults.object(forKey: Keys.jokes) as? Bool ?? true
    }

    private var reactions: Bool {
        defaults.object(forKey: Keys.reactions) as? Bool ?? true
    }

    /// UInt32(exactly:) guards against out-of-range values from a corrupted
    /// plist or a manual `defaults write`; invalid means unlocked.
    private var lockedDisplayID: CGDirectDisplayID? {
        (defaults.object(forKey: Keys.display) as? Int).flatMap { UInt32(exactly: $0) }
    }

    private static func uuid(forDisplay id: CGDirectDisplayID) -> String? {
        guard let cf = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue()
        else { return nil }
        return CFUUIDCreateString(nil, cf) as String
    }

    /// Display IDs aren't stable across reboots or some dock reconnects, and
    /// can even swap between two still-connected monitors. Re-match the lock
    /// by display UUID and adopt that screen's current ID. Returns true when
    /// the stored ID changed.
    @discardableResult
    private func reconcileLockedDisplay() -> Bool {
        guard let id = lockedDisplayID,
              let uuid = defaults.string(forKey: Keys.displayUUID),
              let newID = NSScreen.screens.first(where: {
                  $0.displayID.flatMap(Self.uuid(forDisplay:)) == uuid
              })?.displayID,
              newID != id
        else { return false }
        defaults.set(Int(newID), forKey: Keys.display)
        return true
    }

    private func applySettings() {
        cat.speed = CGFloat(speed)
        cat.personalSpace = CGFloat(personalSpace)
        cat.startles = startles
        cat.reacts = reactions
        wander.perches = lazyPerches
        updateLazyCatFeatures()
        cat.variant = spriteVariant
        var strategy: TargetStrategy = defaults.bool(forKey: Keys.horizontal)
            ? HorizontalPinnedStrategy(edge: dockEdge)
            : FullChaseStrategy()
        if let id = lockedDisplayID {
            strategy = DisplayLockedStrategy(base: strategy, displayID: id)
        }
        cat.strategy = strategy
    }

    private func refreshMenuState() {
        showHideItem.title = cat.isRunning ? "Hide Chaser" : "Show Chaser"
        lazyShowHideItem.title = lazyCat.isRunning ? "Hide Lazy Cat" : "Show Lazy Cat"
        perchItem.state = lazyPerches ? .on : .off
        clipboardItem.state = holdsClipboard ? .on : .off
        mailItem.state = watchesMail ? .on : .off
        jokesItem.state = tellsJokes ? .on : .off
        let horizontal = defaults.bool(forKey: Keys.horizontal)
        horizontalItem.state = horizontal ? .on : .off
        topItem.state = dockEdge == .top ? .on : .off
        bottomItem.state = dockEdge == .bottom ? .on : .off
        topItem.isEnabled = horizontal
        bottomItem.isEnabled = horizontal
        for item in speedItems {
            item.state = (item.representedObject as? CGFloat) == CGFloat(speed) ? .on : .off
        }
        for item in spaceItems {
            item.state = (item.representedObject as? CGFloat) == CGFloat(personalSpace)
                ? .on : .off
        }
        startleItem.state = startles ? .on : .off
        reactionsItem.state = reactions ? .on : .off
        for item in variantItems {
            item.state = (item.representedObject as? String) == spriteVariant.rawValue ? .on : .off
        }
        for item in displayItems {
            item.state = (item.representedObject as? Int) == lockedDisplayID.map(Int.init)
                ? .on : .off
        }
        loginItem.state = LoginItem.isEnabled ? .on : .off
    }

    /// Clicks and scrolls anywhere feed the chaser's reactions. Mouse events
    /// can be watched without any permission (key events can't, so typing
    /// is only counted, in CatController).
    private func watchClicksAndScrolls() {
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
            [weak self] _ in self?.cat.noteClick()
        }
        NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.cat.noteScroll(event.scrollingDeltaY)
        }
    }

    // MARK: - Actions

    @objc private func toggleShown() {
        setShown(!cat.isRunning)
    }

    @objc private func toggleLazyShown() {
        lazyCat.isRunning ? lazyCat.stop() : lazyCat.start()
        defaults.set(!lazyCat.isRunning, forKey: Keys.lazyHidden)
        updateLazyCatFeatures()
        refreshMenuState()
    }

    private func setShown(_ shown: Bool) {
        if shown != cat.isRunning {
            shown ? cat.start() : cat.stop()
        }
        defaults.set(!shown, forKey: Keys.hidden)
        refreshMenuState()
    }

    @objc private func setSpeed(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? CGFloat else { return }
        defaults.set(Double(value), forKey: Keys.speed)
        applySettings()
        refreshMenuState()
    }

    @objc private func setVariant(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String else { return }
        defaults.set(raw, forKey: Keys.variant)
        applySettings()
        refreshMenuState()
    }

    @objc private func setDisplay(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? Int, let did = UInt32(exactly: id) {
            defaults.set(id, forKey: Keys.display)
            // UUID is the durable identity (reconcile key); raw localizedName
            // (not the menu title with its "(2)" suffix) only labels the
            // disconnected-indicator row.
            if let uuid = Self.uuid(forDisplay: did) {
                defaults.set(uuid, forKey: Keys.displayUUID)
            } else {
                defaults.removeObject(forKey: Keys.displayUUID)
            }
            if let name = NSScreen.screens
                .first(where: { $0.displayID == did })?.localizedName {
                defaults.set(name, forKey: Keys.displayName)
            } else {
                defaults.removeObject(forKey: Keys.displayName)
            }
        } else {
            defaults.removeObject(forKey: Keys.display)
            defaults.removeObject(forKey: Keys.displayName)
            defaults.removeObject(forKey: Keys.displayUUID)
        }
        applySettings()
        refreshMenuState()
    }

    @objc private func setPersonalSpace(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? CGFloat else { return }
        defaults.set(Double(value), forKey: Keys.personalSpace)
        applySettings()
        refreshMenuState()
    }

    @objc private func toggleClipboard() {
        defaults.set(!holdsClipboard, forKey: Keys.clipboard)
        applySettings()
        refreshMenuState()
    }

    // MARK: - Clipboard holder

    /// The lazy cat swallows copies (and files dropped on it) with a little
    /// hop; right-click shows what it holds, left click pets it.
    private func setUpClipboard() {
        clipboard.onSwallow = { [weak self] in self?.lazyCat.bounce() }
        lazyCat.makeInteractive(
            menu: { [weak self] in self?.lazyCatMenu() },
            onDrop: { [weak self] urls in
                guard let self = self, self.holdsClipboard else { return }
                self.clipboard.add(files: urls)
                self.lazyCat.bounce()
            },
            onClick: { [weak self] in
                guard let self = self else { return }
                if self.bubble.isShowing {
                    self.bubble.dismiss()
                } else {
                    self.lazyCat.bounce()
                }
            })
    }

    /// Only while the lazy cat is out: hiding it stops the clipboard and
    /// mail watches and forgets what they held.
    private func updateLazyCatFeatures() {
        clipboard.isEnabled = holdsClipboard && lazyCat.isRunning
        mail.isEnabled = watchesMail && lazyCat.isRunning
        if !lazyCat.isRunning || !tellsJokes { bubble.dismiss() }
    }

    /// Right-click on the lazy cat: unread mail first (when watching), then
    /// what it's holding.
    private func lazyCatMenu() -> NSMenu {
        let menu = NSMenu()
        if watchesMail {
            addMailItems(to: menu)
            menu.addItem(.separator())
        }
        addClipboardItems(to: menu)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Tell Me a Joke", action: #selector(tellJoke),
                     keyEquivalent: "").target = self
        menu.addItem(withTitle: "Add Your Own Jokes…", action: #selector(editJokes),
                     keyEquivalent: "").target = self
        return menu
    }

    private func addClipboardItems(to menu: NSMenu) {
        guard holdsClipboard else {
            menu.addItem(withTitle: "Clipboard holding is off", action: nil, keyEquivalent: "")
            return
        }
        let items = clipboard.items
        menu.addItem(withTitle: items.isEmpty ? "Nothing swallowed yet"
                                              : "Monsieur Pierre is holding:",
                     action: nil, keyEquivalent: "")
        for (index, clip) in items.enumerated() {
            let item = menu.addItem(withTitle: clip.title,
                                    action: #selector(restoreClip(_:)), keyEquivalent: "")
            item.tag = index
            item.image = clip.thumbnail
            item.target = self
            item.toolTip = "Put back on the clipboard"
        }
        if !items.isEmpty {
            menu.addItem(.separator())
            menu.addItem(withTitle: "Forget All", action: #selector(forgetClips),
                         keyEquivalent: "").target = self
        }
    }

    @objc private func restoreClip(_ sender: NSMenuItem) {
        clipboard.restore(at: sender.tag)
    }

    @objc private func forgetClips() {
        clipboard.clear()
    }

    @objc private func toggleMail() {
        defaults.set(!watchesMail, forKey: Keys.mail)
        applySettings()
        refreshMenuState()
    }

    // MARK: - Mail

    /// The lazy cat perks up when new mail lands in Apple Mail, the menu bar
    /// shows the unread count, and right-clicking the cat lists the newest
    /// unread messages to open.
    private func setUpMail() {
        mail.onNewMail = { [weak self] in
            guard let self = self else { return }
            // Three hops in a row, so it reads as excitement, not a pet.
            for delay in [0.0, 0.5, 1.0] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self.lazyCat.bounce()
                }
            }
            if let newest = self.mail.unread.first {
                self.say("You've got mail!\n\(newest.title)")
            }
        }
        mail.onChange = { [weak self] in self?.showUnreadCount() }
    }

    private func showUnreadCount() {
        let count = mail.unreadCount
        statusItem.button?.title = mail.isEnabled && count > 0 ? " \(count)" : ""
        statusItem.button?.toolTip = mail.isEnabled && count > 0
            ? "\(count) unread in Mail" : nil
    }

    private func addMailItems(to menu: NSMenu) {
        if let problem = mail.problem {
            menu.addItem(withTitle: problem, action: nil, keyEquivalent: "")
        } else if mail.unreadCount == 0 {
            menu.addItem(withTitle: "No new mail", action: nil, keyEquivalent: "")
        } else {
            let count = mail.unreadCount
            menu.addItem(withTitle: count == 1 ? "1 unread message" : "\(count) unread messages",
                         action: nil, keyEquivalent: "")
            // Per-account counts, only when there's more than one account.
            let accounts = mail.accounts.filter { $0.unread > 0 }
            if mail.accounts.count > 1 && !accounts.isEmpty {
                for account in accounts {
                    let item = menu.addItem(withTitle: "\(account.name): \(account.unread)",
                                            action: nil, keyEquivalent: "")
                    item.indentationLevel = 1
                }
            }
            for (index, message) in mail.unread.enumerated() {
                let item = menu.addItem(withTitle: message.title,
                                        action: #selector(openMessage(_:)), keyEquivalent: "")
                item.tag = index
                item.target = self
                item.image = NSImage(systemSymbolName: "envelope",
                                     accessibilityDescription: nil)
                item.toolTip = "Open in Mail"
            }
        }
        menu.addItem(withTitle: "Open Mail", action: #selector(openMail),
                     keyEquivalent: "").target = self
        menu.addItem(withTitle: "Check Now", action: #selector(checkMail),
                     keyEquivalent: "").target = self
    }

    @objc private func openMessage(_ sender: NSMenuItem) {
        guard mail.unread.indices.contains(sender.tag) else { return }
        mail.open(mail.unread[sender.tag])
    }

    @objc private func openMail() {
        mail.openMail()
    }

    @objc private func checkMail() {
        mail.check()
    }

    @objc private func toggleJokes() {
        defaults.set(!tellsJokes, forKey: Keys.jokes)
        applySettings()
        refreshMenuState()
    }

    // MARK: - Jokes

    private func say(_ text: String) {
        guard lazyCat.isRunning else { return }
        bubble.say(text) { [weak self] in self?.lazyCat.position ?? .zero }
    }

    /// Now and then, the lazy cat wakes up long enough for a joke: the first
    /// a few minutes after launch, then every 20 to 45 minutes.
    private func scheduleJoke(first: Bool = false) {
        jokeTimer?.invalidate()
        let delay = first ? Double.random(in: 120...300) : Double.random(in: 1200...2700)
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if self.tellsJokes && !self.bubble.isShowing {
                self.tellJoke()
            }
            self.scheduleJoke()
        }
        timer.tolerance = 30
        RunLoop.main.add(timer, forMode: .common)
        jokeTimer = timer
    }

    @objc private func tellJoke() {
        lazyCat.bounce()
        say(Jokes.next())
    }

    /// Opens jokes.txt in the default text editor, creating it with a short
    /// how-to the first time.
    @objc private func editJokes() {
        let url = Jokes.userFile
        if !FileManager.default.fileExists(atPath: url.path) {
            let template = """
                # Monsieur Pierre's extra jokes: one per line. Write \\n to start
                # a new line in the speech bubble. Lines starting with # are skipped.
                Why did Monsieur Pierre sit on the laptop?\\nIt was warm. That's the whole joke.

                """
            do {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try template.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                return NSLog("Couldn't create jokes file: \(error)")
            }
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func togglePerches() {
        defaults.set(!lazyPerches, forKey: Keys.lazyPerches)
        applySettings()
        refreshMenuState()
    }

    @objc private func toggleReactions() {
        defaults.set(!reactions, forKey: Keys.reactions)
        applySettings()
        refreshMenuState()
    }

    @objc private func toggleStartle() {
        defaults.set(!startles, forKey: Keys.startle)
        applySettings()
        refreshMenuState()
    }

    @objc private func toggleHorizontal() {
        defaults.set(!defaults.bool(forKey: Keys.horizontal), forKey: Keys.horizontal)
        applySettings()
        refreshMenuState()
    }

    @objc private func setEdge(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String else { return }
        defaults.set(raw, forKey: Keys.edge)
        applySettings()
        refreshMenuState()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            try LoginItem.setEnabled(!LoginItem.isEnabled)
        } catch {
            NSLog("Launch at login toggle failed: \(error)")
        }
        refreshMenuState()
    }

    /// Launch at Login is on by default: turned on once, at first launch.
    /// Turning it off in the menu sticks, since this never runs again.
    private func enableLaunchAtLoginOnFirstRun() {
        guard !defaults.bool(forKey: Keys.loginItemDefaulted) else { return }
        defaults.set(true, forKey: Keys.loginItemDefaulted)
        do {
            try LoginItem.setEnabled(true)
        } catch {
            NSLog("Enabling launch at login failed: \(error)")
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

import AppKit

/// An unread message in Apple Mail's inbox.
struct MailMessage: Equatable {
    let messageID: String
    let sender: String
    let subject: String
    let received: Date

    /// One line for the menu.
    var title: String {
        // "Jane Doe <jane@example.com>" reads better as just "Jane Doe".
        var name = sender
        if let open = name.firstIndex(of: "<"), open != name.startIndex {
            name = String(name[..<open]).trimmingCharacters(in: .whitespaces)
        }
        name = name.trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
        let subject = self.subject.isEmpty ? "(no subject)" : self.subject
        let line = "\(name): \(subject)"
        return line.count > 60 ? String(line.prefix(60)) + "…" : line
    }

    /// Mail opens `message://<Message-ID>` links itself.
    var url: URL? {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_@"))
        guard let encoded = "<\(messageID)>".addingPercentEncoding(withAllowedCharacters: allowed)
        else { return nil }
        return URL(string: "message://\(encoded)")
    }
}

/// Watches Apple Mail's inbox (every account set up in Mail) for unread
/// messages. Read-only: it asks Mail over Apple Events, which needs the
/// Automation permission the first time, and only while Mail is open so it
/// never launches Mail by itself.
final class MailWatch {
    var isEnabled = false {
        didSet {
            guard isEnabled != oldValue else { return }
            isEnabled ? start() : stop()
        }
    }
    /// Called when an unread message arrives that wasn't there before.
    var onNewMail: (() -> Void)?
    /// Called after every check that changed what's known.
    var onChange: (() -> Void)?

    /// Newest first, at most `listLimit`.
    private(set) var unread: [MailMessage] = []
    private(set) var unreadCount = 0
    /// Unread count per account, in Mail's account order.
    private(set) var accounts: [(name: String, unread: Int)] = []
    /// Why there's nothing to show, when there's a reason.
    private(set) var problem: String?

    static let mailBundleID = "com.apple.mail"
    private static let listLimit = 8
    private static let interval: TimeInterval = 60

    private var timer: Timer?
    private var seenIDs: Set<String> = []
    private var firstCheck = true
    /// NSAppleScript isn't safe to run concurrently; one serial queue keeps
    /// the (sometimes slow) Apple Events off the main thread.
    private let queue = DispatchQueue(label: "com.lolesterrr.monsieurpierre.mail")
    private var checking = false

    private func start() {
        firstCheck = true
        check()
        let timer = Timer(timeInterval: Self.interval, repeats: true) { [weak self] _ in
            self?.check()
        }
        timer.tolerance = 10
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(appsChanged(_:)),
                           name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        center.addObserver(self, selector: #selector(appsChanged(_:)),
                           name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        center.addObserver(self, selector: #selector(appsChanged(_:)),
                           name: NSWorkspace.didDeactivateApplicationNotification, object: nil)
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        unread = []
        unreadCount = 0
        accounts = []
        problem = nil
        seenIDs = []
        onChange?()
    }

    /// Re-check when Mail opens or quits, and when you leave Mail (you may
    /// have just read something).
    @objc private func appsChanged(_ note: Notification) {
        let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        guard app?.bundleIdentifier == Self.mailBundleID else { return }
        check()
    }

    /// Checks right away (also used by the menu's "Check Now").
    func check() {
        guard isEnabled, !checking else { return }
        guard Self.mailIsRunning else {
            update(Check(problem: "Mail isn't open"))
            return
        }
        checking = true
        queue.async {
            let result = Self.fetch()
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.checking = false
                guard self.isEnabled else { return }
                self.update(result)
            }
        }
    }

    static var mailIsRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: mailBundleID).isEmpty
    }

    func open(_ message: MailMessage) {
        guard let url = message.url else { return openMail() }
        NSWorkspace.shared.open(url)
    }

    func openMail() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.mailBundleID)
        else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Talking to Mail

    private struct Check {
        var count = 0
        var messages: [MailMessage] = []
        var accounts: [(name: String, unread: Int)] = []
        var problem: String?
    }

    private func update(_ result: Check) {
        let ids = Set(result.messages.map(\.messageID))
        let arrived = !firstCheck && !ids.subtracting(seenIDs).isEmpty
            && result.count >= unreadCount
        if result.problem == nil {
            firstCheck = false
            seenIDs = ids
        }
        unread = result.messages
        unreadCount = result.count
        accounts = result.accounts
        problem = result.problem
        onChange?()
        if arrived { onNewMail?() }
    }

    /// Fields and records are split by the ASCII unit and record separators,
    /// which don't turn up in names or subjects.
    private static let script = """
        set us to character id 31
        set rs to character id 30
        if application "Mail" is not running then return ""
        tell application "Mail"
            set out to (unread count of inbox) as text
            set accountLine to ""
            try
                repeat with mb in (mailboxes of inbox)
                    set accountLine to accountLine & (name of account of mb) & us & ((unread count of mb) as text) & us
                end repeat
            end try
            set out to out & rs & accountLine
            set ids to message id of (messages of inbox whose read status is false)
            set senders to sender of (messages of inbox whose read status is false)
            set subjects to subject of (messages of inbox whose read status is false)
            set dates to date received of (messages of inbox whose read status is false)
            -- Seconds before now, since date literals depend on the region.
            set nowDate to current date
            if (count of ids) = (count of dates) and (count of ids) = (count of subjects) and (count of ids) = (count of senders) then
                repeat with i from 1 to count of ids
                    set out to out & rs & (item i of ids) & us & (item i of senders) & us & (item i of subjects) & us & ((nowDate - (item i of dates)) as text)
                end repeat
            end if
            return out
        end tell
        """

    private static func fetch() -> Check {
        var error: NSDictionary?
        guard let compiled = NSAppleScript(source: script) else {
            return Check(problem: "Couldn't ask Mail")
        }
        let output = compiled.executeAndReturnError(&error)
        if let error = error {
            let code = error[NSAppleScript.errorNumber] as? Int ?? 0
            NSLog("Mail check failed: \(error)")
            switch code {
            case -1743: return Check(problem: "Allow Monsieur Pierre to control Mail in Security & Privacy › Automation")
            case -600: return Check(problem: "Mail isn't open")
            default: return Check(problem: "Couldn't ask Mail")
            }
        }
        return parse(output.stringValue ?? "")
    }

    private static func parse(_ text: String) -> Check {
        guard !text.isEmpty else { return Check(problem: "Mail isn't open") }
        let records = text.components(separatedBy: "\u{1E}")
        var result = Check()
        result.count = Int(records[0]) ?? 0
        if records.count > 1 {
            let fields = records[1].components(separatedBy: "\u{1F}")
            var i = 0
            while i + 1 < fields.count {
                result.accounts.append((fields[i], Int(fields[i + 1]) ?? 0))
                i += 2
            }
        }
        // Ages in seconds. AppleScript writes big numbers as "1.2E+7" and may
        // use a comma as the decimal separator, depending on the region.
        let now = Date()
        let messages: [MailMessage] = records.dropFirst(2).compactMap { record in
            let fields = record.components(separatedBy: "\u{1F}")
            guard fields.count == 4 else { return nil }
            let age = Double(fields[3].replacingOccurrences(of: ",", with: ".")) ?? 0
            return MailMessage(messageID: fields[0], sender: fields[1], subject: fields[2],
                               received: now.addingTimeInterval(-age))
        }
        result.messages = Array(messages.sorted { $0.received > $1.received }.prefix(listLimit))
        return result
    }
}

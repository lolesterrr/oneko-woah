import Foundation
#if compiler(>=5.7)
import ServiceManagement
#endif

/// Launch at Login. macOS 13+ uses SMAppService. macOS 11 and 12 have no
/// equivalent for an app without a helper bundle, so there a per-user
/// LaunchAgent opens the app by bundle id at login (surviving a move to
/// another folder).
///
/// SMAppService is only in the macOS 13 SDK (Xcode 14, Swift 5.7). The
/// compiler check keeps the code building with Xcode 13 on Big Sur; such a
/// build always uses the LaunchAgent.
enum LoginItem {
    private static let bundleID = Bundle.main.bundleIdentifier ?? "com.lolesterrr.monsieurpierre"

    private static var agentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(bundleID).plist")
    }

    static var isEnabled: Bool {
        #if compiler(>=5.7)
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        #endif
        return FileManager.default.fileExists(atPath: agentURL.path)
    }

    static func setEnabled(_ enabled: Bool) throws {
        #if compiler(>=5.7)
        if #available(macOS 13.0, *) {
            // Drop an agent left over from before a macOS upgrade, so the app
            // isn't opened twice.
            try? FileManager.default.removeItem(at: agentURL)
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return
        }
        #endif
        if enabled {
            try writeAgent()
        } else if FileManager.default.fileExists(atPath: agentURL.path) {
            try FileManager.default.removeItem(at: agentURL)
        }
    }

    /// launchd loads every agent in ~/Library/LaunchAgents at login, so
    /// writing the file is enough; it takes effect from the next login.
    private static func writeAgent() throws {
        let agent: [String: Any] = [
            "Label": bundleID,
            "ProgramArguments": ["/usr/bin/open", "-b", bundleID],
            "RunAtLoad": true,
            "LimitLoadToSessionType": "Aqua",
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: agent, format: .xml, options: 0)
        try FileManager.default.createDirectory(
            at: agentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: agentURL, options: .atomic)
    }
}

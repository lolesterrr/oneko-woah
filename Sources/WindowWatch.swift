import AppKit

/// Where other apps' windows are, from the window server. Only positions and
/// sizes are read, never titles or contents, so this needs no Screen
/// Recording permission. Frames are converted to AppKit's y-up coordinates.
enum WindowWatch {
    /// The frontmost app's front window, when it's a normal window the cat
    /// could sit on.
    static func frontWindow() -> (id: CGWindowID, pid: pid_t, frame: CGRect)? {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              pid != ProcessInfo.processInfo.processIdentifier,
              let list = CGWindowListCopyWindowInfo(
                  [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                  as? [[String: Any]]
        else { return nil }
        // The list runs front to back, so the app's first normal-layer
        // window is the one in front.
        for info in list {
            guard (info[kCGWindowOwnerPID as String] as? pid_t) == pid,
                  (info[kCGWindowLayer as String] as? Int) == 0,
                  let id = info[kCGWindowNumber as String] as? CGWindowID,
                  let frame = appKitFrame(info)
            else { continue }
            return isPerchable(frame) ? (id, pid, frame) : nil
        }
        return nil
    }

    /// The window's current frame, or nil once it's closed, minimized, on
    /// another Space or full screen.
    static func frame(of id: CGWindowID) -> CGRect? {
        guard let list = CGWindowListCopyWindowInfo(.optionIncludingWindow, id)
                  as? [[String: Any]],
              let info = list.first,
              (info[kCGWindowIsOnscreen as String] as? Bool) == true,
              let frame = appKitFrame(info),
              isPerchable(frame)
        else { return nil }
        return frame
    }

    /// Big enough to sit on, and not a full-screen window.
    private static func isPerchable(_ frame: CGRect) -> Bool {
        frame.width >= 160 && frame.height >= 80
            && !NSScreen.screens.contains { $0.frame == frame }
    }

    private static func appKitFrame(_ info: [String: Any]) -> CGRect? {
        guard let bounds = info[kCGWindowBounds as String] as? NSDictionary,
              let rect = CGRect(dictionaryRepresentation: bounds),
              let primary = NSScreen.screens.first?.frame
        else { return nil }
        // Window server coordinates are y-down from the primary screen's top.
        return CGRect(x: rect.minX, y: primary.maxY - rect.maxY,
                      width: rect.width, height: rect.height)
    }
}

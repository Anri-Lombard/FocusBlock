import AppKit
import Foundation

public class BrowserMonitor {
    private let browserIdentifiers = [
        "company.thebrowser.Browser", // Arc
        "com.google.Chrome",
        "com.brave.Browser",
        "org.mozilla.firefox",
        "com.microsoft.edgemac",
        "com.apple.Safari",
    ]

    private let notificationManager: NotificationManager

    public init(notificationManager: NotificationManager) {
        self.notificationManager = notificationManager
    }

    public func killBrowsersIfNeeded() throws {
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications

        for app in runningApps {
            guard let bundleId = app.bundleIdentifier else { continue }
            guard browserIdentifiers.contains(bundleId) else { continue }

            let browserName = app.localizedName ?? "Browser"

            app.terminate()

            Thread.sleep(forTimeInterval: 0.5)

            if !app.isTerminated {
                app.forceTerminate()
            }

            notificationManager.browserKilled(browserName: browserName)
        }
    }

    public func hasBrowsersRunning() -> Bool {
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications

        for app in runningApps {
            if let bundleId = app.bundleIdentifier,
               browserIdentifiers.contains(bundleId)
            {
                return true
            }
        }

        return false
    }
}

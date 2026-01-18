import AppKit
import Foundation

public class SoftBlockMonitor {
    private let config: Configuration
    private var gracePeriods: [String: Date] = [:]

    private let supportedBrowsers: [(bundleId: String, name: String)] = [
        ("com.apple.Safari", "Safari"),
        ("com.google.Chrome", "Google Chrome"),
        ("com.brave.Browser", "Brave Browser"),
        ("company.thebrowser.Browser", "Arc"),
    ]

    public init(config: Configuration) {
        self.config = config
    }

    public func checkBrowsers() {
        let softBlockedSites = config.softBlockSites
        guard !softBlockedSites.isEmpty else { return }

        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications

        for (bundleId, browserName) in supportedBrowsers {
            guard runningApps.contains(where: { $0.bundleIdentifier == bundleId }) else {
                continue
            }

            if let url = getCurrentURL(for: bundleId, browserName: browserName) {
                handleURL(url, browser: browserName, bundleId: bundleId)
            }
        }
    }

    private func getCurrentURL(for bundleId: String, browserName: String) -> String? {
        let script: String

        switch bundleId {
        case "com.apple.Safari":
            script = """
                tell application "Safari"
                    if (count of windows) > 0 then
                        return URL of current tab of front window
                    end if
                end tell
                return ""
                """
        case "com.google.Chrome", "com.brave.Browser":
            script = """
                tell application "\(browserName)"
                    if (count of windows) > 0 then
                        return URL of active tab of front window
                    end if
                end tell
                return ""
                """
        case "company.thebrowser.Browser":
            script = """
                tell application "Arc"
                    if (count of windows) > 0 then
                        return URL of active tab of front window
                    end if
                end tell
                return ""
                """
        default:
            return nil
        }

        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        let result = appleScript?.executeAndReturnError(&error)

        if error != nil {
            return nil
        }

        return result?.stringValue
    }

    private func handleURL(_ urlString: String, browser: String, bundleId: String) {
        guard let url = URL(string: urlString),
              let host = url.host?.lowercased()
        else {
            return
        }

        let softBlockedSites = config.softBlockSites
        let matchedSite = softBlockedSites.first { site in
            host == site.lowercased() || host.hasSuffix("." + site.lowercased())
        }

        guard let site = matchedSite else { return }

        if let graceExpiry = gracePeriods[site], Date() < graceExpiry {
            return
        }

        closeCurrentTab(for: bundleId, browserName: browser)

        let wantsToReopen = showDialogWithContinuousMonitoring(
            site: site,
            url: urlString,
            bundleId: bundleId,
            browserName: browser
        )

        if wantsToReopen {
            let gracePeriodSeconds = config.softBlockGracePeriod
            gracePeriods[site] = Date().addingTimeInterval(TimeInterval(gracePeriodSeconds))
            openURL(urlString, in: bundleId, browserName: browser)
        }
    }

    private func showInterventionDialog(site: String, url: String) -> Bool {
        let script = """
            display dialog "Is visiting \(site) worth your attention right now, or is this just habit?" \
                buttons {"No, stay focused", "Yes, reopen"} \
                default button "No, stay focused" \
                with title "FocusBlock" \
                with icon caution
            return button returned of result
            """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus != 0 {
                return false  // Fail-closed: don't reopen if dialog fails
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return output == "Yes, reopen"
        } catch {
            return false  // Fail-closed: don't reopen if dialog fails
        }
    }

    private func openURL(_ urlString: String, in bundleId: String, browserName: String) {
        let script: String

        switch bundleId {
        case "com.apple.Safari":
            script = """
                tell application "Safari"
                    open location "\(urlString)"
                    activate
                end tell
                """
        default:
            script = """
                tell application "\(browserName)"
                    open location "\(urlString)"
                    activate
                end tell
                """
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }

    private func isSoftBlocked(url urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              let host = url.host?.lowercased()
        else {
            return false
        }

        return config.softBlockSites.contains { site in
            host == site.lowercased() || host.hasSuffix("." + site.lowercased())
        }
    }

    private func showDialogWithContinuousMonitoring(
        site: String,
        url: String,
        bundleId: String,
        browserName: String
    ) -> Bool {
        var dialogResult: Bool?
        let lock = NSLock()

        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.showInterventionDialog(site: site, url: url)
            lock.lock()
            dialogResult = result
            lock.unlock()
        }

        while true {
            lock.lock()
            let result = dialogResult
            lock.unlock()

            if let finalResult = result {
                return finalResult
            }

            for (browserBundleId, browser) in supportedBrowsers {
                if let currentURL = getCurrentURL(for: browserBundleId, browserName: browser),
                   isSoftBlocked(url: currentURL) {
                    closeCurrentTab(for: browserBundleId, browserName: browser)
                }
            }

            usleep(500_000)  // 500ms
        }
    }

    private func closeCurrentTab(for bundleId: String, browserName: String) {
        let script: String

        switch bundleId {
        case "com.apple.Safari":
            script = """
                tell application "Safari"
                    if (count of windows) > 0 then
                        close current tab of front window
                    end if
                end tell
                """
        case "com.google.Chrome", "com.brave.Browser":
            script = """
                tell application "\(browserName)"
                    if (count of windows) > 0 then
                        close active tab of front window
                    end if
                end tell
                """
        case "company.thebrowser.Browser":
            script = """
                tell application "Arc"
                    if (count of windows) > 0 then
                        close active tab of front window
                    end if
                end tell
                """
        default:
            return
        }

        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        appleScript?.executeAndReturnError(&error)
    }
}

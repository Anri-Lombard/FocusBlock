import AppKit
import ArgumentParser
import FocusBlockCore
import Foundation

struct StartCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "start",
        abstract: "Start a focus session")

    @Argument(help: "Session duration in minutes (default: configured value)")
    var duration: Int?

    @Option(name: .long, help: "Comma-separated list of sites to block")
    var sites: String?

    @Flag(name: .shortAndLong, help: "Skip browser restart prompt")
    var yes: Bool = false

    func run() throws {
        let (_, sessionManager, _, config) = try initializeCore()

        disableDoHSettings()
        checkAndRestartBrowsers()
        flushDNSCache()

        let sitesToBlock: [String]? = sites?.split(separator: ",").map {
            String($0).trimmingCharacters(in: .whitespaces)
        }

        let durationToUse = duration ?? config.defaultDuration

        print("🔒 Starting focus session...")
        print("Duration: \(durationToUse) minutes (\(formatDuration(durationToUse)))")

        let session = try sessionManager.startSession(
            durationMinutes: durationToUse,
            sites: sitesToBlock)

        let blockedSites = try sessionManager.getBlockedSites(for: session.id)
        print("Blocking \(blockedSites.count) sites:")
        for site in blockedSites.prefix(5) {
            print("  • \(site)")
        }
        if blockedSites.count > 5 {
            print("  ... and \(blockedSites.count - 5) more")
        }

        let endDate = Date(timeIntervalSince1970: TimeInterval(session.endTime))
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        print("\n✅ Session started! Ends at \(formatter.string(from: endDate))")

        do {
            let daemonManager = try DaemonManager()
            if !daemonManager.isDaemonRunning() {
                if try daemonManager.startDaemon() {
                    print("🔄 Background monitor started")
                }
            }
        } catch {
            print("⚠️  Could not start background monitor: \(error.localizedDescription)")
        }

        print("Stay focused! 💪")
    }

    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0, mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }

    private func checkAndRestartBrowsers() {
        let runningApps = NSWorkspace.shared.runningApplications
        let browserIds = [
            "company.thebrowser.Browser",
            "com.google.Chrome",
            "com.brave.Browser",
            "org.mozilla.firefox",
        ]

        var runningBrowsers: [(name: String, app: NSRunningApplication)] = []
        for app in runningApps {
            guard let bundleId = app.bundleIdentifier else { continue }
            guard browserIds.contains(bundleId) else { continue }

            let name = app.localizedName ?? "Browser"
            runningBrowsers.append((name: name, app: app))
        }

        if runningBrowsers.isEmpty {
            return
        }

        let browserNames = runningBrowsers.map(\.name).joined(separator: ", ")
        print("\n⚠️  Warning: \(browserNames) is currently running.")
        print("   For website blocking to work properly, the browser needs to be restarted.")

        let shouldRestart: Bool
        if yes {
            shouldRestart = true
            print("   Auto-restarting browsers...")
        } else {
            print("\n   Restart browser now? (y/n): ", terminator: "")
            fflush(stdout)

            if let response = readLine()?.lowercased().trimmingCharacters(in: .whitespaces) {
                shouldRestart = response == "y" || response == "yes"
            } else {
                shouldRestart = false
            }
        }

        if shouldRestart {
            print("\n   Restarting browsers...")

            var browsersToReopen: [(name: String, bundleId: String)] = []
            for (name, app) in runningBrowsers {
                guard let bundleId = app.bundleIdentifier else { continue }

                print("   Closing \(name)...")
                browsersToReopen.append((name: name, bundleId: bundleId))

                app.terminate()
                Thread.sleep(forTimeInterval: 0.5)

                if !app.isTerminated {
                    app.forceTerminate()
                }
            }

            Thread.sleep(forTimeInterval: 1.0)

            for (name, bundleId) in browsersToReopen {
                print("   Reopening \(name)...")
                if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                    NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
                }
            }

            print("   ✅ Browsers restarted. Blocking is now active.\n")
        } else {
            print("\n   ⚠️  Continuing without restart. Blocking may not work until you restart the browser.\n")
        }
    }

    private func disableDoHSettings() {
        do {
            let dohDisabler = try DohDisabler()
            _ = try dohDisabler.disableDoH(restartBrowsers: false)
        } catch {
            // Silently continue - DoH disable is best-effort
        }
    }

    private func flushDNSCache() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/dscacheutil")
        process.arguments = ["-flushcache"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }
}

import ArgumentParser
import Foundation
import FocusBlockCore

struct DaemonCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "daemon",
        abstract: "Manage the FocusBlock background daemon",
        subcommands: [Install.self, Uninstall.self, Status.self, Restart.self, Logs.self, DisableDoH.self, EnableDoH.self, VerifyDoH.self]
    )
}

extension DaemonCommand {
    struct Install: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Install and start the background daemon"
        )

        func run() throws {
            let scriptPath = findInstallScript()

            guard FileManager.default.fileExists(atPath: scriptPath) else {
                print("❌ Error: Install script not found at \(scriptPath)")
                print("Make sure you're running from the project directory.")
                throw ExitCode.failure
            }

            print("Installing FocusBlock daemon...")
            let result = shell(scriptPath)

            if result.exitCode == 0 {
                print(result.output)
            } else {
                print("❌ Installation failed:")
                print(result.output)
                throw ExitCode.failure
            }
        }

        private func findInstallScript() -> String {
            let possiblePaths = [
                "./Scripts/install-daemon.sh",
                "../Scripts/install-daemon.sh",
                "../../Scripts/install-daemon.sh"
            ]

            for path in possiblePaths {
                let expandedPath = (path as NSString).expandingTildeInPath
                if FileManager.default.fileExists(atPath: expandedPath) {
                    return expandedPath
                }
            }

            return "./Scripts/install-daemon.sh"
        }
    }

    struct Uninstall: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Uninstall and stop the background daemon"
        )

        func run() throws {
            let scriptPath = findUninstallScript()

            guard FileManager.default.fileExists(atPath: scriptPath) else {
                print("❌ Error: Uninstall script not found at \(scriptPath)")
                throw ExitCode.failure
            }

            print("Uninstalling FocusBlock daemon...")
            let result = shell(scriptPath)

            if result.exitCode == 0 {
                print(result.output)
            } else {
                print("❌ Uninstallation failed:")
                print(result.output)
                throw ExitCode.failure
            }
        }

        private func findUninstallScript() -> String {
            let possiblePaths = [
                "./Scripts/uninstall-daemon.sh",
                "../Scripts/uninstall-daemon.sh",
                "../../Scripts/uninstall-daemon.sh"
            ]

            for path in possiblePaths {
                let expandedPath = (path as NSString).expandingTildeInPath
                if FileManager.default.fileExists(atPath: expandedPath) {
                    return expandedPath
                }
            }

            return "./Scripts/uninstall-daemon.sh"
        }
    }

    struct Status: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Check daemon status"
        )

        func run() {
            let result = shell("launchctl list | grep focusblock")

            if result.output.isEmpty {
                print("❌ Daemon not running")
                print("\nTo start the daemon:")
                print("  focus daemon install")
            } else {
                print("✅ Daemon is running")
                print("")
                print(result.output)
                print("\nLogs:")
                print("  Standard output: /tmp/focusblock-daemon.log")
                print("  Error output:    /tmp/focusblock-daemon.error.log")
            }
        }
    }

    struct Restart: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Restart the background daemon"
        )

        func run() {
            print("Restarting daemon...")

            print("Stopping daemon...")
            _ = shell("launchctl unload ~/Library/LaunchAgents/com.focusblock.daemon.plist 2>/dev/null || true")

            sleep(1)

            print("Starting daemon...")
            let result = shell("launchctl load ~/Library/LaunchAgents/com.focusblock.daemon.plist")

            if result.exitCode == 0 {
                sleep(1)
                let status = shell("launchctl list | grep focusblock")
                if !status.output.isEmpty {
                    print("✅ Daemon restarted successfully")
                } else {
                    print("⚠️  Daemon may not be running. Check logs:")
                    print("  tail /tmp/focusblock-daemon.error.log")
                }
            } else {
                print("❌ Failed to restart daemon")
                print(result.output)
            }
        }
    }

    struct Logs: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "View daemon logs"
        )

        @Flag(name: .shortAndLong, help: "Follow log output")
        var follow: Bool = false

        @Flag(name: .shortAndLong, help: "Show error logs instead")
        var error: Bool = false

        func run() {
            let logPath = error ? "/tmp/focusblock-daemon.error.log" : "/tmp/focusblock-daemon.log"

            if !FileManager.default.fileExists(atPath: logPath) {
                print("❌ Log file not found: \(logPath)")
                print("The daemon may not be installed or running.")
                return
            }

            if follow {
                print("Following \(logPath)...")
                print("Press Ctrl+C to stop\n")
                _ = shell("tail -f \(logPath)")
            } else {
                let result = shell("tail -n 50 \(logPath)")
                print(result.output)
            }
        }
    }

    struct DisableDoH: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "disable-doh",
            abstract: "Disable DNS over HTTPS in browsers"
        )

        func run() throws {
            let disabler = try DohDisabler()
            let result = try disabler.disableDoH()

            if !result.success.isEmpty {
                print("✅ Successfully disabled DoH:")
                for browser in result.success {
                    print("   - \(browser)")
                }
            }

            if !result.skipped.isEmpty {
                print("\n⏭️  Skipped (not installed):")
                for browser in result.skipped {
                    print("   - \(browser)")
                }
            }

            if !result.failed.isEmpty {
                print("\n❌ Failed:")
                for (browser, error) in result.failed {
                    print("   - \(browser): \(error.localizedDescription)")
                }
            }

            print("\n⚠️  Note: Chrome, Arc, and Brave will show 'Managed by your organization'")
            print("   This is expected and safe. It indicates DoH has been disabled successfully.")
            print("\n💡 Browsers may need to be restarted for changes to take effect.")
        }
    }

    struct EnableDoH: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "enable-doh",
            abstract: "Re-enable DNS over HTTPS in browsers"
        )

        func run() throws {
            let disabler = try DohDisabler()
            let result = try disabler.enableDoH()

            if !result.success.isEmpty {
                print("✅ DoH restored for:")
                for browser in result.success {
                    print("   - \(browser)")
                }
            }

            if !result.skipped.isEmpty {
                print("\n⏭️  Skipped (not installed):")
                for browser in result.skipped {
                    print("   - \(browser)")
                }
            }

            if !result.failed.isEmpty {
                print("\n❌ Failed:")
                for (browser, error) in result.failed {
                    print("   - \(browser): \(error.localizedDescription)")
                }
            }

            print("\n💡 Browsers may need to be restarted for changes to take effect.")
        }
    }

    struct VerifyDoH: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "verify-doh",
            abstract: "Check DoH status for all browsers"
        )

        func run() throws {
            let disabler = try DohDisabler()
            let status = disabler.verifyDoHStatus()

            print("DoH Status for Installed Browsers:\n")

            for browser in status.browsers {
                if !browser.installed {
                    continue
                }

                let icon = browser.dohDisabled ? "✅" : "⚠️ "
                let statusText = browser.dohDisabled ? "disabled" : "enabled"
                print("\(icon) \(browser.name): DoH \(statusText)")
            }

            let installedBrowsers = status.browsers.filter { $0.installed }
            if installedBrowsers.isEmpty {
                print("No supported browsers found.")
            } else {
                let allDisabled = installedBrowsers.allSatisfy { $0.dohDisabled }
                if allDisabled {
                    print("\n✅ All installed browsers have DoH disabled.")
                } else {
                    print("\n⚠️  Some browsers still have DoH enabled.")
                    print("   Run 'focus daemon disable-doh' to disable it.")
                }
            }
        }
    }
}

private func shell(_ command: String) -> (output: String, exitCode: Int32) {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/bash")
    task.arguments = ["-c", command]

    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe

    do {
        try task.run()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        return (output, task.terminationStatus)
    } catch {
        return ("Error: \(error)", 1)
    }
}

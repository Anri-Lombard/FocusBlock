import Foundation

public class DaemonManager {
    private let pidFileURL: URL
    private let fileManager = FileManager.default

    public init() throws {
        let appSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true)

        let focusBlockDir = appSupportURL.appendingPathComponent("FocusBlock", isDirectory: true)
        try fileManager.createDirectory(at: focusBlockDir, withIntermediateDirectories: true)

        pidFileURL = focusBlockDir.appendingPathComponent("daemon.pid")
    }

    public func startDaemon() throws -> Bool {
        killAllDaemons()

        guard let daemonPath = findDaemonExecutable() else {
            throw DaemonManagerError.daemonNotFound
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: daemonPath)
        process.arguments = []
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try process.run()

        let pid = process.processIdentifier
        try String(pid).write(to: pidFileURL, atomically: true, encoding: .utf8)

        return true
    }

    public func stopDaemon() {
        killAllDaemons()
    }

    public func isDaemonRunning() -> Bool {
        guard let pid = readPID() else {
            return false
        }

        return kill(pid, 0) == 0
    }

    private func readPID() -> pid_t? {
        guard let content = try? String(contentsOf: pidFileURL, encoding: .utf8),
              let pid = Int32(content.trimmingCharacters(in: .whitespacesAndNewlines))
        else {
            return nil
        }
        return pid
    }

    private func cleanup() {
        try? fileManager.removeItem(at: pidFileURL)
    }

    private func killAllDaemons() {
        let launchctl = Process()
        launchctl.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        launchctl.arguments = ["unload", NSHomeDirectory() + "/Library/LaunchAgents/com.focusblock.daemon.plist"]
        launchctl.standardOutput = FileHandle.nullDevice
        launchctl.standardError = FileHandle.nullDevice
        try? launchctl.run()
        launchctl.waitUntilExit()

        let pkill = Process()
        pkill.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        pkill.arguments = ["-x", "focus-daemon"]
        pkill.standardOutput = FileHandle.nullDevice
        pkill.standardError = FileHandle.nullDevice
        try? pkill.run()
        pkill.waitUntilExit()

        usleep(100_000)
        cleanup()
    }

    private func findDaemonExecutable() -> String? {
        if let focusPath = ProcessInfo.processInfo.arguments.first {
            let focusURL = URL(fileURLWithPath: focusPath)
            let daemonPath = focusURL.deletingLastPathComponent().appendingPathComponent("focus-daemon").path
            if fileManager.isExecutableFile(atPath: daemonPath) {
                return daemonPath
            }
        }

        let bundlePath = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("focus-daemon").path
        if fileManager.isExecutableFile(atPath: bundlePath) {
            return bundlePath
        }

        let systemPaths = [
            "/usr/local/bin/focus-daemon",
            "/opt/homebrew/bin/focus-daemon",
        ]

        for path in systemPaths {
            if fileManager.isExecutableFile(atPath: path) {
                return path
            }
        }

        return nil
    }
}

public enum DaemonManagerError: Error, LocalizedError {
    case daemonNotFound

    public var errorDescription: String? {
        switch self {
        case .daemonNotFound:
            "focus-daemon executable not found. Ensure it's installed alongside focus."
        }
    }
}

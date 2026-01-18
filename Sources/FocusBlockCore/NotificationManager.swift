import AppKit
import Foundation

public class NotificationManager {
    private var notificationsAvailable = true

    public init() {
        checkNotificationAvailability()
    }

    private func checkNotificationAvailability() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", "return 1"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            notificationsAvailable = process.terminationStatus == 0
        } catch {
            notificationsAvailable = false
        }
    }

    public func send(title: String, body: String) {
        guard notificationsAvailable else {
            print("📬 \(title): \(body)")
            return
        }

        let script = """
        display notification "\(body.replacingOccurrences(of: "\"", with: "\\\""))" with title "\(title.replacingOccurrences(of: "\"", with: "\\\""))"
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        do {
            try process.run()
        } catch {
            print("📬 \(title): \(body)")
        }
    }

    public func sessionStarted(durationMinutes: Int) {
        send(
            title: "Focus Session Started",
            body: "Stay focused for \(durationMinutes) minutes! 🎯")
    }

    public func sessionCompleted() {
        send(
            title: "Focus Session Completed",
            body: "Great work! Session finished successfully. ✅")
    }

    public func browserKilled(browserName: String) {
        send(
            title: "FocusBlock Active",
            body: "\(browserName) was closed. Stay focused! 💪")
    }

    public func hostsFileTampered() {
        send(
            title: "FocusBlock Alert",
            body: "Hosts file was modified. Blocks have been re-applied. 🔒")
    }
}

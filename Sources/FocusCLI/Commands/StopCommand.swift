import ArgumentParser
import FocusBlockCore
import Foundation

struct StopCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "stop",
        abstract: "Stop the active focus session")

    @Flag(name: .long, help: "Force stop even if session hasn't ended (emergency use only)")
    var force: Bool = false

    func run() throws {
        let (_, sessionManager, _, _) = try initializeCore()

        guard let session = try sessionManager.getActiveSession() else {
            print("❌ No active session found.")
            return
        }

        let now = Int64(Date().timeIntervalSince1970)
        let remaining = session.endTime - now

        if remaining > 0 && !force {
            let minutes = Int(remaining / 60)
            print("⏰ Session still has \(minutes) minutes remaining.")
            print("Cannot stop early. Stay focused! 💪")
            print("")
            print("If something is broken, use: focus stop --force")
            throw ExitCode(1)
        }

        if force && remaining > 0 {
            print("⚠️  Force stopping session early...")
        }

        let overtime = abs(Int(remaining))
        let overtimeMinutes = overtime / 60
        let overtimeSeconds = overtime % 60

        if overtimeMinutes > 0 || overtimeSeconds > 0 {
            print("🎉 Well done! You stayed focused for \(formatTime(minutes: overtimeMinutes, seconds: overtimeSeconds)) longer than needed!")
            print("")
        }

        try sessionManager.autoCompleteSession(session)

        print("✅ Focus session stopped and sites unblocked!")
        print("Great work! 💪")
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

    private func formatTime(minutes: Int, seconds: Int) -> String {
        String(format: "%dm %02ds", minutes, seconds)
    }
}

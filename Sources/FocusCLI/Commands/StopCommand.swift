import ArgumentParser
import Foundation
import FocusBlockCore

struct StopCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "stop",
        abstract: "Stop the active focus session"
    )

    func run() throws {
        let (_, sessionManager, _, _) = try initializeCore()

        guard let session = try sessionManager.getActiveSession() else {
            print("❌ No active session found.")
            return
        }

        let now = Int64(Date().timeIntervalSince1970)
        let remaining = session.endTime - now

        if remaining > 0 {
            let minutes = Int(remaining / 60)
            print("⏰ Session still has \(minutes) minutes remaining.")
            print("Cannot stop early. Stay focused! 💪")
            throw ExitCode(1)
        }

        try sessionManager.stopSession()

        let durationMinutes = session.durationSeconds / 60
        print("✅ Session completed!")
        print("Duration: \(formatDuration(durationMinutes))")
        print("Blocks removed. Great work! 🎉")
    }

    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }
}

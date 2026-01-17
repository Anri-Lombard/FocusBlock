import ArgumentParser
import Foundation
import FocusBlockCore

struct StatusCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show current session status"
    )

    func run() throws {
        let (_, sessionManager, _, _) = try initializeCore()

        guard let session = try sessionManager.getActiveSession() else {
            print("⚪️ No active session")
            print("Run 'focus start' to begin a new session")
            return
        }

        let now = Int64(Date().timeIntervalSince1970)
        let elapsed = now - session.startTime
        let remaining = session.endTime - now

        let totalMinutes = session.durationSeconds / 60
        let elapsedMinutes = Int(elapsed / 60)
        let remainingMinutes = max(0, Int(remaining / 60))

        let progress = min(1.0, Double(elapsed) / Double(session.durationSeconds))
        let progressPercent = Int(progress * 100)

        print("🔒 Active Focus Session")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Duration:  \(formatDuration(totalMinutes))")
        print("Elapsed:   \(formatDuration(elapsedMinutes))")
        print("Remaining: \(formatDuration(remainingMinutes))")
        print("")

        printProgressBar(progress: progress)
        print(" \(progressPercent)%")
        print("")

        let blockedSites = try sessionManager.getBlockedSites(for: session.id)
        print("Blocking \(blockedSites.count) sites")

        let endDate = Date(timeIntervalSince1970: TimeInterval(session.endTime))
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        if remaining <= 0 {
            print("Session completed! Run 'focus stop' to finish. ✅")
        } else {
            print("Ends at \(formatter.string(from: endDate))")
        }
    }

    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return String(format: "%dh %02dm", hours, mins)
        } else {
            return "\(mins)m"
        }
    }

    private func printProgressBar(progress: Double) {
        let barWidth = 30
        let filled = Int(progress * Double(barWidth))
        let empty = barWidth - filled

        print("[", terminator: "")
        print(String(repeating: "█", count: filled), terminator: "")
        print(String(repeating: "░", count: empty), terminator: "")
        print("]", terminator: "")
    }
}

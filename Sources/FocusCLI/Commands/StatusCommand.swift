import ArgumentParser
import FocusBlockCore
import Foundation

struct StatusCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show current session status")

    func run() throws {
        let (_, sessionManager, _, _) = try initializeCore()
        let blockEngine = BlockEngine()

        guard let session = try sessionManager.getActiveSession() else {
            if try blockEngine.isBlocking() {
                print("⚠️  No active session, but sites are still blocked!")
                print("This can happen if the daemon couldn't clean up properly.")
                print("")
                print("Run 'focus unblock' to remove all blocks.")
                return
            }
            print("⚪️ No active session")
            print("Run 'focus start' to begin a new session")
            return
        }

        let now = Int64(Date().timeIntervalSince1970)
        let elapsed = now - session.startTime
        let remaining = session.endTime - now

        let totalMinutes = session.durationSeconds / 60
        let elapsedMinutes = Int(elapsed / 60)
        let elapsedSeconds = Int(elapsed % 60)
        let remainingTotalSeconds = max(0, Int(remaining))
        let remainingMinutes = remainingTotalSeconds / 60
        let remainingSeconds = remainingTotalSeconds % 60

        let progress = min(1.0, Double(elapsed) / Double(session.durationSeconds))
        let progressPercent = Int(progress * 100)

        print("🔒 Active Focus Session")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Duration:  \(formatDuration(totalMinutes))")
        print("Elapsed:   \(formatTime(minutes: elapsedMinutes, seconds: elapsedSeconds))")
        print("Remaining: \(formatTime(minutes: remainingMinutes, seconds: remainingSeconds))")
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
            let overtime = abs(Int(remaining))
            let overtimeMinutes = overtime / 60
            let overtimeSeconds = overtime % 60

            print("Session completed! ✅")
            print("")

            if overtimeMinutes > 0 || overtimeSeconds > 0 {
                print("🎉 Well done! You stayed focused for \(formatTime(minutes: overtimeMinutes, seconds: overtimeSeconds)) longer than needed!")
                print("")
            }

            print("Stop session and unblock sites? (y/n): ", terminator: "")
            fflush(stdout)

            if let response = readLine()?.lowercased().trimmingCharacters(in: .whitespaces),
               response == "y" || response == "yes" {
                try sessionManager.autoCompleteSession(session)
                print("")
                print("✅ Focus session stopped and sites unblocked!")
                print("Great work! 💪")
            } else {
                print("")
                print("Run 'focus stop' when ready to unblock sites.")
            }
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

    private func formatTime(minutes: Int, seconds: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return String(format: "%dh %02dm %02ds", hours, mins, seconds)
        } else {
            return String(format: "%dm %02ds", mins, seconds)
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

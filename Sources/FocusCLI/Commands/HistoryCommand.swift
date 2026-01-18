import ArgumentParser
import FocusBlockCore
import Foundation

struct HistoryCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "history",
        abstract: "Show recent session history")

    @Option(name: .long, help: "Number of sessions to show")
    var limit: Int = 10

    func run() throws {
        let (_, sessionManager, _, _) = try initializeCore()

        let sessions = try sessionManager.getRecentSessions(limit: limit)

        if sessions.isEmpty {
            print("No sessions found.")
            print("Run 'focus start' to begin your first session!")
            return
        }

        print("📜 Recent Sessions")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("")

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, h:mm a"

        for (index, session) in sessions.enumerated() {
            let startDate = Date(timeIntervalSince1970: TimeInterval(session.startTime))
            let durationMinutes = session.durationSeconds / 60

            let statusIcon = session.status == .completed ? "✅" : "⚪️"
            let statusText = session.status == .completed ? "completed" : session.status.rawValue

            print("\(index + 1). \(statusIcon) \(dateFormatter.string(from: startDate))")
            print("   Duration: \(formatDuration(durationMinutes)) • Status: \(statusText)")

            if index < sessions.count - 1 {
                print("")
            }
        }
    }

    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
}

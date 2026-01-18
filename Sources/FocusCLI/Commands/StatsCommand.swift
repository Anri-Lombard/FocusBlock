import ArgumentParser
import FocusBlockCore
import Foundation

struct StatsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "stats",
        abstract: "Display focus statistics and heatmap")

    @Option(name: .long, help: "Range: week, month, year, or all")
    var range: String?

    func run() throws {
        let (_, _, statsTracker, _) = try initializeCore()

        let snapshot = try statsTracker.getStatsSnapshot()

        print("📊 Focus Statistics")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("")

        print("🔥 Current Streak: \(snapshot.currentStreak) day\(snapshot.currentStreak == 1 ? "" : "s")")
        print("🏆 Longest Streak: \(snapshot.longestStreak) day\(snapshot.longestStreak == 1 ? "" : "s")")
        print("⏱️  Total Focus Time: \(formatHoursMinutes(snapshot.totalFocusTimeMinutes))")
        print("📅 Sessions This Week: \(snapshot.sessionsThisWeek)")

        if snapshot.averageSessionMinutes > 0 {
            print("📊 Average Session: \(formatHoursMinutes(snapshot.averageSessionMinutes))")
        }

        print("")
        let currentYear = Calendar.current.component(.year, from: Date())
        print("Activity Heatmap (\(currentYear))")
        print("")

        let renderer = HeatmapRenderer()
        let heatmap = renderer.render(data: snapshot.heatmapData, weeks: 52)
        print(heatmap)
    }

    private func formatHoursMinutes(_ totalMinutes: Int) -> String {
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0, minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
}

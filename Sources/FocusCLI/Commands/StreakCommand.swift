import ArgumentParser
import Foundation
import FocusBlockCore

struct StreakCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "streak",
        abstract: "Show current and longest streak"
    )

    func run() throws {
        let (_, _, statsTracker, _) = try initializeCore()

        let currentStreak = try statsTracker.calculateCurrentStreak()
        let longestStreak = try statsTracker.calculateLongestStreak()

        print("🔥 Focus Streaks")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("")
        print("Current Streak: \(currentStreak) days \(currentStreak > 0 ? "🔥" : "")")
        print("Longest Streak: \(longestStreak) days")
        print("")

        if currentStreak == 0 {
            print("Start a focus session today to begin your streak! 💪")
        } else if currentStreak >= 7 {
            print("Amazing! Keep it going! 🎉")
        } else if currentStreak >= 3 {
            print("Great progress! 🌟")
        }
    }
}

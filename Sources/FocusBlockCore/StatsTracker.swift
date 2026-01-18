import Foundation
import GRDB

public struct StatsSnapshot {
    public let currentStreak: Int
    public let longestStreak: Int
    public let totalFocusTimeMinutes: Int
    public let sessionsThisWeek: Int
    public let averageSessionMinutes: Int
    public let heatmapData: [String: Int]

    public init(
        currentStreak: Int,
        longestStreak: Int,
        totalFocusTimeMinutes: Int,
        sessionsThisWeek: Int,
        averageSessionMinutes: Int,
        heatmapData: [String: Int])
    {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.totalFocusTimeMinutes = totalFocusTimeMinutes
        self.sessionsThisWeek = sessionsThisWeek
        self.averageSessionMinutes = averageSessionMinutes
        self.heatmapData = heatmapData
    }
}

public class StatsTracker {
    private let db: DatabaseManager
    private let dateFormatter: DateFormatter

    public init(db: DatabaseManager) {
        self.db = db
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
    }

    public func getStatsSnapshot() throws -> StatsSnapshot {
        let currentStreak = try calculateCurrentStreak()
        let longestStreak = try calculateLongestStreak()
        let totalTime = try getTotalFocusTime()
        let sessionsThisWeek = try getSessionsThisWeek()
        let averageSession = try getAverageSessionDuration()
        let heatmap = try getHeatmapData(weeks: 52)

        return StatsSnapshot(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            totalFocusTimeMinutes: totalTime,
            sessionsThisWeek: sessionsThisWeek,
            averageSessionMinutes: averageSession,
            heatmapData: heatmap)
    }

    public func calculateCurrentStreak() throws -> Int {
        let stats = try getAllDailyStats()
        guard !stats.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var checkDate = today

        for _ in 0 ..< 365 {
            let dateString = dateFormatter.string(from: checkDate)
            if stats.contains(where: { $0.date == dateString && $0.totalMinutes > 0 }) {
                streak += 1
                guard let previousDate = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                    break
                }
                checkDate = previousDate
            } else {
                if checkDate == today {
                    guard let previousDate = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                        break
                    }
                    checkDate = previousDate
                    continue
                }
                break
            }
        }

        return streak
    }

    public func calculateLongestStreak() throws -> Int {
        let stats = try getAllDailyStats()
        guard !stats.isEmpty else { return 0 }

        let sortedStats = stats.sorted { $0.date < $1.date }
        var longestStreak = 0
        var currentStreak = 0
        var lastDate: Date?

        let calendar = Calendar.current

        for stat in sortedStats where stat.totalMinutes > 0 {
            guard let date = dateFormatter.date(from: stat.date) else { continue }

            if let last = lastDate {
                let daysBetween = calendar.dateComponents([.day], from: last, to: date).day ?? 0
                if daysBetween == 1 {
                    currentStreak += 1
                } else {
                    longestStreak = max(longestStreak, currentStreak)
                    currentStreak = 1
                }
            } else {
                currentStreak = 1
            }

            lastDate = date
        }

        return max(longestStreak, currentStreak)
    }

    public func getTotalFocusTime() throws -> Int {
        try db.reader.read { db in
            try DailyStats
                .select(sum(Column("total_minutes")))
                .asRequest(of: Int.self)
                .fetchOne(db) ?? 0
        }
    }

    public func getSessionsThisWeek() throws -> Int {
        let calendar = Calendar.current
        let today = Date()
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else {
            return 0
        }

        let weekStartString = dateFormatter.string(from: weekStart)

        return try db.reader.read { db in
            try DailyStats
                .filter(Column("date") >= weekStartString)
                .select(sum(Column("session_count")))
                .asRequest(of: Int.self)
                .fetchOne(db) ?? 0
        }
    }

    public func getAverageSessionDuration() throws -> Int {
        let totalMinutes = try getTotalFocusTime()
        let totalSessions = try db.reader.read { db in
            try Session
                .filter(Column("status") == SessionStatus.completed.rawValue)
                .fetchCount(db)
        }

        guard totalSessions > 0 else { return 0 }
        return totalMinutes / totalSessions
    }

    public func getHeatmapData(weeks: Int) throws -> [String: Int] {
        let calendar = Calendar.current
        let today = Date()
        guard let startDate = calendar.date(byAdding: .weekOfYear, value: -weeks, to: today) else {
            return [:]
        }

        let startString = dateFormatter.string(from: startDate)

        let stats = try db.reader.read { db in
            try DailyStats
                .filter(Column("date") >= startString)
                .fetchAll(db)
        }

        var heatmap: [String: Int] = [:]
        for stat in stats {
            heatmap[stat.date] = stat.totalMinutes
        }

        return heatmap
    }

    public func getDailyStats(for date: Date) throws -> DailyStats? {
        let dateString = dateFormatter.string(from: date)
        return try db.reader.read { db in
            try DailyStats.fetchOne(db, key: dateString)
        }
    }

    private func getAllDailyStats() throws -> [DailyStats] {
        try db.reader.read { db in
            try DailyStats.fetchAll(db)
        }
    }
}

import Foundation
import GRDB

public class DatabaseManager {
    private let dbQueue: DatabaseQueue
    private static let databaseFileName = "focusblock.db"

    public init() throws {
        let fileManager = FileManager.default
        let appSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let focusBlockDir = appSupportURL.appendingPathComponent("FocusBlock", isDirectory: true)
        try fileManager.createDirectory(at: focusBlockDir, withIntermediateDirectories: true)

        let dbURL = focusBlockDir.appendingPathComponent(Self.databaseFileName)
        dbQueue = try DatabaseQueue(path: dbURL.path)

        try migrator.migrate(dbQueue)
    }

    public var reader: DatabaseReader { dbQueue }
    public var writer: DatabaseWriter { dbQueue }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: "sessions") { t in
                t.column("id", .text).primaryKey()
                t.column("start_time", .integer).notNull()
                t.column("end_time", .integer).notNull()
                t.column("duration_seconds", .integer).notNull()
                t.column("status", .text).notNull()
                t.column("created_at", .integer).notNull()
            }

            try db.create(index: "idx_sessions_date", on: "sessions", columns: ["start_time"])

            try db.create(table: "blocked_sites") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("session_id", .text).notNull()
                    .references("sessions", onDelete: .cascade)
                t.column("site", .text).notNull()
            }

            try db.create(table: "daily_stats") { t in
                t.column("date", .text).primaryKey()
                t.column("total_minutes", .integer).notNull()
                t.column("session_count", .integer).notNull()
                t.column("longest_session", .integer).notNull()
                t.column("created_at", .integer).notNull()
            }

            try db.create(index: "idx_daily_stats_date", on: "daily_stats", columns: ["date"])
        }

        return migrator
    }
}

import Foundation
import GRDB

public class SessionManager {
    private let db: DatabaseManager
    private let blockEngine: BlockEngine
    private let config: Configuration

    public init(db: DatabaseManager, blockEngine: BlockEngine, config: Configuration) {
        self.db = db
        self.blockEngine = blockEngine
        self.config = config
    }

    public func startSession(durationMinutes: Int? = nil, sites: [String]? = nil) throws -> Session {
        if let activeSession = try getActiveSession() {
            throw SessionError.sessionAlreadyActive(activeSession.id)
        }

        let duration = durationMinutes ?? config.defaultDuration
        let sitesToBlock = sites ?? config.defaultSites

        let now = Int64(Date().timeIntervalSince1970)
        let endTime = now + Int64(duration * 60)

        let session = Session(
            startTime: now,
            endTime: endTime,
            durationSeconds: duration * 60,
            status: .active
        )

        try db.writer.write { db in
            try session.insert(db)

            for site in sitesToBlock {
                let blockedSite = BlockedSite(sessionId: session.id, site: site)
                try blockedSite.insert(db)
            }
        }

        try blockEngine.enableBlocking(for: sitesToBlock)

        return session
    }

    public func stopSession() throws {
        guard let session = try getActiveSession() else {
            throw SessionError.noActiveSession
        }

        let now = Int64(Date().timeIntervalSince1970)

        if now < session.endTime {
            let remainingSeconds = session.endTime - now
            let remainingMinutes = Int(remainingSeconds / 60)
            throw SessionError.sessionNotExpired(remainingMinutes)
        }

        var updatedSession = session
        updatedSession.status = .completed

        try db.writer.write { db in
            try updatedSession.update(db)
        }

        try blockEngine.disableBlocking()

        try updateDailyStats(for: session)
    }

    public func getActiveSession() throws -> Session? {
        try db.reader.read { db in
            try Session
                .filter(Column("status") == SessionStatus.active.rawValue)
                .fetchOne(db)
        }
    }

    public func getSessionById(_ id: String) throws -> Session? {
        try db.reader.read { db in
            try Session.fetchOne(db, key: id)
        }
    }

    public func getRecentSessions(limit: Int = 10) throws -> [Session] {
        try db.reader.read { db in
            try Session
                .order(Column("start_time").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    public func getBlockedSites(for sessionId: String) throws -> [String] {
        try db.reader.read { db in
            try BlockedSite
                .filter(Column("session_id") == sessionId)
                .fetchAll(db)
                .map { $0.site }
        }
    }

    private func updateDailyStats(for session: Session) throws {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(session.startTime)))

        let durationMinutes = session.durationSeconds / 60

        try db.writer.write { db in
            if var stats = try DailyStats.fetchOne(db, key: date) {
                stats.totalMinutes += durationMinutes
                stats.sessionCount += 1
                stats.longestSession = max(stats.longestSession, durationMinutes)
                try stats.update(db)
            } else {
                let stats = DailyStats(
                    date: date,
                    totalMinutes: durationMinutes,
                    sessionCount: 1,
                    longestSession: durationMinutes
                )
                try stats.insert(db)
            }
        }
    }
}

public enum SessionError: Error, LocalizedError {
    case sessionAlreadyActive(String)
    case noActiveSession
    case sessionNotExpired(Int)
    case sessionNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .sessionAlreadyActive(let id):
            return "A session is already active (ID: \(id)). Stop it before starting a new one."
        case .noActiveSession:
            return "No active session found."
        case .sessionNotExpired(let minutes):
            return "Cannot stop session early. \(minutes) minutes remaining."
        case .sessionNotFound(let id):
            return "Session not found: \(id)"
        }
    }
}

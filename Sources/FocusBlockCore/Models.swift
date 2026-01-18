import Foundation
import GRDB

public enum SessionStatus: String, Codable, DatabaseValueConvertible {
    case active
    case completed
    case cancelled
}

public struct Session: Codable, FetchableRecord, PersistableRecord {
    public var id: String
    public var startTime: Int64
    public var endTime: Int64
    public var durationSeconds: Int
    public var status: SessionStatus
    public var createdAt: Int64

    public init(
        id: String = UUID().uuidString,
        startTime: Int64,
        endTime: Int64,
        durationSeconds: Int,
        status: SessionStatus = .active,
        createdAt: Int64 = Int64(Date().timeIntervalSince1970))
    {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.durationSeconds = durationSeconds
        self.status = status
        self.createdAt = createdAt
    }

    public static let databaseTableName = "sessions"

    enum CodingKeys: String, CodingKey {
        case id
        case startTime = "start_time"
        case endTime = "end_time"
        case durationSeconds = "duration_seconds"
        case status
        case createdAt = "created_at"
    }
}

public struct BlockedSite: Codable, FetchableRecord, PersistableRecord {
    public var id: Int64?
    public var sessionId: String
    public var site: String

    public init(id: Int64? = nil, sessionId: String, site: String) {
        self.id = id
        self.sessionId = sessionId
        self.site = site
    }

    public static let databaseTableName = "blocked_sites"

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case site
    }
}

public struct DailyStats: Codable, FetchableRecord, PersistableRecord {
    public var date: String
    public var totalMinutes: Int
    public var sessionCount: Int
    public var longestSession: Int
    public var createdAt: Int64

    public init(
        date: String,
        totalMinutes: Int = 0,
        sessionCount: Int = 0,
        longestSession: Int = 0,
        createdAt: Int64 = Int64(Date().timeIntervalSince1970))
    {
        self.date = date
        self.totalMinutes = totalMinutes
        self.sessionCount = sessionCount
        self.longestSession = longestSession
        self.createdAt = createdAt
    }

    public static let databaseTableName = "daily_stats"

    enum CodingKeys: String, CodingKey {
        case date
        case totalMinutes = "total_minutes"
        case sessionCount = "session_count"
        case longestSession = "longest_session"
        case createdAt = "created_at"
    }
}

public struct Config: Codable {
    public var defaultDuration: Int
    public var defaultSites: [String]
    public var dohEnabled: Bool
    public var dohRestoreOnUninstall: Bool
    public var dohExcludedBrowsers: [String]

    public init(
        defaultDuration: Int = 90,
        defaultSites: [String] = Config.defaultBlockedSites,
        dohEnabled: Bool = true,
        dohRestoreOnUninstall: Bool = true,
        dohExcludedBrowsers: [String] = [])
    {
        self.defaultDuration = defaultDuration
        self.defaultSites = defaultSites
        self.dohEnabled = dohEnabled
        self.dohRestoreOnUninstall = dohRestoreOnUninstall
        self.dohExcludedBrowsers = dohExcludedBrowsers
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        defaultDuration = try container.decode(Int.self, forKey: .defaultDuration)
        defaultSites = try container.decode([String].self, forKey: .defaultSites)
        dohEnabled = try container.decodeIfPresent(Bool.self, forKey: .dohEnabled) ?? true
        dohRestoreOnUninstall = try container.decodeIfPresent(Bool.self, forKey: .dohRestoreOnUninstall) ?? true
        dohExcludedBrowsers = try container.decodeIfPresent([String].self, forKey: .dohExcludedBrowsers) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case defaultDuration
        case defaultSites
        case dohEnabled
        case dohRestoreOnUninstall
        case dohExcludedBrowsers
    }

    public static let defaultBlockedSites = [
        "youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be",
        "x.com", "www.x.com", "twitter.com", "www.twitter.com", "mobile.twitter.com",
        "reddit.com", "www.reddit.com", "old.reddit.com", "new.reddit.com",
        "linkedin.com", "www.linkedin.com",
    ]
}

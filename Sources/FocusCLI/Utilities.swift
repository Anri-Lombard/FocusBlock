import FocusBlockCore
import Foundation

func initializeCore() throws -> (DatabaseManager, SessionManager, StatsTracker, Configuration) {
    let db = try DatabaseManager()
    let config = try Configuration()
    let blockEngine = BlockEngine()
    let sessionManager = SessionManager(db: db, blockEngine: blockEngine, config: config)
    let statsTracker = StatsTracker(db: db)

    return (db, sessionManager, statsTracker, config)
}

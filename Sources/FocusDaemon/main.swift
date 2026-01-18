import Foundation
import FocusBlockCore

var isRunning = true

func setupSignalHandlers() {
    signal(SIGTERM) { _ in
        print("Received SIGTERM, shutting down...")
        isRunning = false
    }

    signal(SIGINT) { _ in
        print("Received SIGINT, shutting down...")
        isRunning = false
    }
}

func initializeCore() throws -> (
    db: DatabaseManager,
    sessionManager: SessionManager,
    blockEngine: BlockEngine,
    config: Configuration,
    notificationManager: NotificationManager,
    browserMonitor: BrowserMonitor,
    integrityChecker: HostsIntegrityChecker
) {
    let db = try DatabaseManager()
    let blockEngine = BlockEngine()
    let config = try Configuration()
    let notificationManager = NotificationManager()
    let sessionManager = SessionManager(db: db, blockEngine: blockEngine, config: config)
    let browserMonitor = BrowserMonitor(notificationManager: notificationManager)
    let integrityChecker = HostsIntegrityChecker(blockEngine: blockEngine, notificationManager: notificationManager)

    return (db, sessionManager, blockEngine, config, notificationManager, browserMonitor, integrityChecker)
}

func runMonitoringLoop(
    sessionManager: SessionManager,
    browserMonitor: BrowserMonitor,
    integrityChecker: HostsIntegrityChecker,
    notificationManager: NotificationManager
) throws {
    guard let session = try sessionManager.getActiveSession() else {
        return
    }

    let blockedSites = try sessionManager.getBlockedSites(for: session.id)

    if !integrityChecker.isIntact() {
        try integrityChecker.reapply(sites: blockedSites)
    }
}

do {
    setupSignalHandlers()

    let core = try initializeCore()

    let dohDisabler = try DohDisabler()
    let result = try dohDisabler.disableDoH()

    if !result.success.isEmpty {
        print("DoH disabled for: \(result.success.joined(separator: ", "))")
    }
    if !result.skipped.isEmpty {
        print("Skipped (not installed): \(result.skipped.joined(separator: ", "))")
    }
    if !result.failed.isEmpty {
        print("Failed to disable DoH for: \(result.failed.map { $0.0 }.joined(separator: ", "))")
    }

    print("FocusBlock daemon started successfully")
    print("Monitoring for active sessions...")

    while isRunning {
        do {
            try runMonitoringLoop(
                sessionManager: core.sessionManager,
                browserMonitor: core.browserMonitor,
                integrityChecker: core.integrityChecker,
                notificationManager: core.notificationManager
            )
        } catch {
            print("Error in monitoring loop: \(error)")
        }

        sleep(30)
    }

    print("FocusBlock daemon shut down")
} catch {
    print("Fatal error initializing daemon: \(error)")
    exit(1)
}

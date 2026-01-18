import FocusBlockCore
import Foundation

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
    integrityChecker: HostsIntegrityChecker,
    softBlockMonitor: SoftBlockMonitor)
{
    let db = try DatabaseManager()
    let blockEngine = BlockEngine()
    let config = try Configuration()
    let notificationManager = NotificationManager()
    let sessionManager = SessionManager(db: db, blockEngine: blockEngine, config: config)
    let browserMonitor = BrowserMonitor(notificationManager: notificationManager)
    let integrityChecker = HostsIntegrityChecker(blockEngine: blockEngine, notificationManager: notificationManager)
    let softBlockMonitor = SoftBlockMonitor(config: config)

    return (db, sessionManager, blockEngine, config, notificationManager, browserMonitor, integrityChecker, softBlockMonitor)
}

func runIntegrityCheck(
    sessionManager: SessionManager,
    integrityChecker: HostsIntegrityChecker) throws
{
    guard let session = try sessionManager.getActiveSession() else {
        return
    }

    let blockedSites = try sessionManager.getBlockedSites(for: session.id)

    if !integrityChecker.isIntact() {
        try integrityChecker.reapply(sites: blockedSites)
    }
}

func runSoftBlockCheck(
    sessionManager: SessionManager,
    softBlockMonitor: SoftBlockMonitor) throws
{
    guard try sessionManager.getActiveSession() != nil else {
        return
    }

    softBlockMonitor.checkBrowsers()
}

do {
    setupSignalHandlers()

    let core = try initializeCore()

    let dohDisabler = try DohDisabler()
    let result = try dohDisabler.disableDoH(restartBrowsers: false)

    if !result.success.isEmpty {
        print("DoH disabled for: \(result.success.joined(separator: ", "))")
    }
    if !result.skipped.isEmpty {
        print("Skipped (not installed): \(result.skipped.joined(separator: ", "))")
    }
    if !result.failed.isEmpty {
        print("Failed to disable DoH for: \(result.failed.map(\.0).joined(separator: ", "))")
    }

    print("FocusBlock daemon started successfully")
    print("Monitoring for active sessions...")

    var loopCounter = 0
    let integrityCheckInterval = 15
    var integrityCheckDisabled = false

    while isRunning {
        do {
            try runSoftBlockCheck(
                sessionManager: core.sessionManager,
                softBlockMonitor: core.softBlockMonitor)
        } catch {
            print("Error in soft block check: \(error)")
        }

        loopCounter += 1
        if loopCounter >= integrityCheckInterval {
            loopCounter = 0
            if !integrityCheckDisabled {
                do {
                    try runIntegrityCheck(
                        sessionManager: core.sessionManager,
                        integrityChecker: core.integrityChecker)
                } catch {
                    integrityCheckDisabled = true
                    print("Integrity checking disabled (no sudo access in daemon context)")
                }
            }
        }

        sleep(2)
    }

    print("FocusBlock daemon shut down")
} catch {
    print("Fatal error initializing daemon: \(error)")
    exit(1)
}

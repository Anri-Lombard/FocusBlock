import Foundation

public class HostsIntegrityChecker {
    private let blockEngine: BlockEngine
    private let notificationManager: NotificationManager

    public init(blockEngine: BlockEngine, notificationManager: NotificationManager) {
        self.blockEngine = blockEngine
        self.notificationManager = notificationManager
    }

    public func isIntact() -> Bool {
        do {
            return try blockEngine.isBlocking()
        } catch {
            return false
        }
    }

    public func reapply(sites: [String]) throws {
        try blockEngine.enableBlocking(for: sites)
        notificationManager.hostsFileTampered()
    }
}

import ArgumentParser
import Foundation
import FocusBlockCore

struct UnblockCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "unblock",
        abstract: "Force remove all blocks (emergency cleanup)"
    )

    func run() throws {
        let (_, _, _, _) = try initializeCore()
        let blockEngine = BlockEngine()

        print("🔓 Force removing all blocks...")
        print("This will remove all FocusBlock entries from /etc/hosts")
        try blockEngine.forceCleanup()
        print("✅ All blocks removed")
        print("DNS cache flushed")
        print("\nYou can now access all previously blocked sites.")
    }
}

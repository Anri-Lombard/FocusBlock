import ArgumentParser
import FocusBlockCore
import Foundation

struct UnblockCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "unblock",
        abstract: "Remove all site blocks (emergency use)")

    func run() throws {
        let blockEngine = BlockEngine()

        if try !blockEngine.isBlocking() {
            print("✅ No sites are currently blocked.")
            return
        }

        print("🔓 Removing all site blocks...")
        try blockEngine.disableBlocking()
        print("✅ All sites unblocked!")
    }
}

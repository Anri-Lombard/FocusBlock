import ArgumentParser
import FocusBlockCore
import Foundation

struct ConfigCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Manage FocusBlock configuration",
        subcommands: [GetConfig.self, SetConfig.self, ResetConfig.self])
}

struct GetConfig: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: "View current configuration")

    @Argument(help: "Configuration key (optional)")
    var key: String?

    func run() throws {
        let (_, _, _, config) = try initializeCore()

        if let key {
            if let value = config.get(key: key) {
                print("\(key): \(value)")
            } else {
                print("❌ Unknown configuration key: \(key)")
                throw ExitCode(1)
            }
        } else {
            print("⚙️  FocusBlock Configuration")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("default_duration: \(config.defaultDuration) minutes")
            print("default_sites:")
            for site in config.defaultSites {
                print("  • \(site)")
            }
            print("soft_sites:")
            if config.softBlockSites.isEmpty {
                print("  (none)")
            } else {
                for site in config.softBlockSites {
                    print("  • \(site)")
                }
            }
            print("soft_grace_period: \(config.softBlockGracePeriod) seconds")
        }
    }
}

struct SetConfig: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "set",
        abstract: "Set a configuration value")

    @Argument(help: "Configuration key")
    var key: String

    @Argument(help: "Configuration value")
    var value: String

    func run() throws {
        let (_, _, _, config) = try initializeCore()

        try config.set(key: key, value: value)
        print("✅ Configuration updated: \(key) = \(value)")
    }
}

struct ResetConfig: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "reset",
        abstract: "Reset configuration to defaults")

    func run() throws {
        let (_, _, _, config) = try initializeCore()

        try config.reset()
        print("✅ Configuration reset to defaults")
        print("Default duration: 90 minutes")
        print("Default sites: YouTube, X, Reddit, LinkedIn")
    }
}

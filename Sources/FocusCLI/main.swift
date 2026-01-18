import ArgumentParser
import FocusBlockCore
import Foundation

struct FocusCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "focus",
        abstract: "A hard-blocking focus session manager for macOS",
        version: "1.0.0",
        subcommands: [
            StartCommand.self,
            StopCommand.self,
            StatusCommand.self,
            StatsCommand.self,
            HistoryCommand.self,
            ConfigCommand.self,
            UnblockCommand.self,
            DaemonCommand.self,
        ])
}

FocusCLI.main()

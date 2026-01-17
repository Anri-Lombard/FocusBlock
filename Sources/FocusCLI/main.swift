import ArgumentParser
import Foundation
import FocusBlockCore

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
            StreakCommand.self,
            HistoryCommand.self,
            ConfigCommand.self
        ]
    )
}

FocusCLI.main()

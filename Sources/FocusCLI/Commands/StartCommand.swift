import ArgumentParser
import Foundation
import FocusBlockCore

struct StartCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "start",
        abstract: "Start a focus session"
    )

    @Argument(help: "Session duration in minutes (default: configured value)")
    var duration: Int?

    @Option(name: .long, help: "Comma-separated list of sites to block")
    var sites: String?

    func run() throws {
        let (_, sessionManager, _, config) = try initializeCore()

        let sitesToBlock: [String]? = sites?.split(separator: ",").map {
            String($0).trimmingCharacters(in: .whitespaces)
        }

        let durationToUse = duration ?? config.defaultDuration

        print("🔒 Starting focus session...")
        print("Duration: \(durationToUse) minutes (\(formatDuration(durationToUse)))")

        let session = try sessionManager.startSession(
            durationMinutes: durationToUse,
            sites: sitesToBlock
        )

        let blockedSites = try sessionManager.getBlockedSites(for: session.id)
        print("Blocking \(blockedSites.count) sites:")
        for site in blockedSites.prefix(5) {
            print("  • \(site)")
        }
        if blockedSites.count > 5 {
            print("  ... and \(blockedSites.count - 5) more")
        }

        let endDate = Date(timeIntervalSince1970: TimeInterval(session.endTime))
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        print("\n✅ Session started! Ends at \(formatter.string(from: endDate))")
        print("Stay focused! 💪")
    }

    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }
}

import Foundation

public class BlockEngine {
    private let hostsPath = "/etc/hosts"
    private let blockMarkerStart = "# FOCUSBLOCK_START"
    private let blockMarkerEnd = "# FOCUSBLOCK_END"

    public init() {}

    public func enableBlocking(for sites: [String]) throws {
        let entries = generateHostsEntries(for: sites)
        try modifyHostsFile(adding: entries)
        try flushDNSCache()
    }

    public func disableBlocking() throws {
        try modifyHostsFile(adding: nil)
        try flushDNSCache()
    }

    public func isBlocking() throws -> Bool {
        let contents = try String(contentsOfFile: hostsPath, encoding: .utf8)
        return contents.contains(blockMarkerStart)
    }

    private func generateHostsEntries(for sites: [String]) -> String {
        var entries = [blockMarkerStart]

        for site in sites {
            entries.append("127.0.0.1 \(site)")
            entries.append("::1 \(site)")
        }

        entries.append(blockMarkerEnd)
        return entries.joined(separator: "\n")
    }

    private func modifyHostsFile(adding entries: String?) throws {
        let contents = try String(contentsOfFile: hostsPath, encoding: .utf8)
        let lines = contents.components(separatedBy: .newlines)

        var newLines: [String] = []
        var inBlockSection = false

        for line in lines {
            if line == blockMarkerStart {
                inBlockSection = true
                continue
            }
            if line == blockMarkerEnd {
                inBlockSection = false
                continue
            }
            if !inBlockSection {
                newLines.append(line)
            }
        }

        if let entries = entries {
            newLines.append("")
            newLines.append(entries)
        }

        let newContents = newLines.joined(separator: "\n")

        let tempFile = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("hosts.tmp")
        try newContents.write(to: tempFile, atomically: true, encoding: .utf8)

        let sudoProcess = Process()
        sudoProcess.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        sudoProcess.arguments = ["cp", tempFile.path, hostsPath]

        try sudoProcess.run()
        sudoProcess.waitUntilExit()

        if sudoProcess.terminationStatus != 0 {
            throw BlockEngineError.sudoFailed
        }

        try FileManager.default.removeItem(at: tempFile)
    }

    private func flushDNSCache() throws {
        let flushProcess = Process()
        flushProcess.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        flushProcess.arguments = ["dscacheutil", "-flushcache"]

        try flushProcess.run()
        flushProcess.waitUntilExit()

        let killProcess = Process()
        killProcess.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        killProcess.arguments = ["killall", "-HUP", "mDNSResponder"]

        try killProcess.run()
        killProcess.waitUntilExit()
    }
}

public enum BlockEngineError: Error, LocalizedError {
    case sudoFailed
    case hostsFileNotFound
    case insufficientPermissions

    public var errorDescription: String? {
        switch self {
        case .sudoFailed:
            return "Failed to modify hosts file. sudo may have been cancelled or failed."
        case .hostsFileNotFound:
            return "Hosts file not found at /etc/hosts"
        case .insufficientPermissions:
            return "Insufficient permissions to modify hosts file"
        }
    }
}

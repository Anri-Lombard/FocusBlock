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

    public func forceCleanup() throws {
        let commonSites = [
            "youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be",
            "x.com", "www.x.com", "twitter.com", "www.twitter.com", "mobile.twitter.com",
            "reddit.com", "www.reddit.com", "old.reddit.com", "new.reddit.com",
            "linkedin.com", "www.linkedin.com",
        ]

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
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                var shouldKeep = true

                for site in commonSites {
                    if trimmed.hasSuffix(site), trimmed.hasPrefix("127.0.0.1") || trimmed.hasPrefix("::1") {
                        shouldKeep = false
                        break
                    }
                }

                if shouldKeep {
                    newLines.append(line)
                }
            }
        }

        let newContents = newLines.joined(separator: "\n")

        let tempFile = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("hosts.tmp")
        try newContents.write(to: tempFile, atomically: true, encoding: .utf8)

        try runSudoCommand(["/bin/cp", tempFile.path, hostsPath])

        try FileManager.default.removeItem(at: tempFile)
        try flushDNSCache()
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

        if let entries {
            newLines.append("")
            newLines.append(entries)
        }

        let newContents = newLines.joined(separator: "\n")

        let tempFile = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("hosts.tmp")
        try newContents.write(to: tempFile, atomically: true, encoding: .utf8)

        try runSudoCommand(["/bin/cp", tempFile.path, hostsPath])

        try FileManager.default.removeItem(at: tempFile)
    }

    private func runSudoCommand(_ arguments: [String]) throws {
        // Check if sudo credentials are already cached
        let checkProcess = Process()
        checkProcess.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        checkProcess.arguments = ["-n", "true"]
        checkProcess.standardOutput = FileHandle.nullDevice
        checkProcess.standardError = FileHandle.nullDevice
        try? checkProcess.run()
        checkProcess.waitUntilExit()

        let needsPassword = checkProcess.terminationStatus != 0

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")

        if needsPassword {
            // Read password securely with echo disabled using getpass()
            guard let passBytes = getpass("Password: ") else {
                throw BlockEngineError.sudoFailed
            }
            let password = String(cString: passBytes)

            process.arguments = ["-S"] + arguments

            let inputPipe = Pipe()
            process.standardInput = inputPipe
            process.standardOutput = FileHandle.standardOutput
            process.standardError = FileHandle.nullDevice // Hide "Password:" prompt from sudo

            try process.run()

            inputPipe.fileHandleForWriting.write((password + "\n").data(using: .utf8)!)
            inputPipe.fileHandleForWriting.closeFile()

            process.waitUntilExit()
        } else {
            process.arguments = arguments
            process.standardOutput = FileHandle.standardOutput
            process.standardError = FileHandle.standardError
            try process.run()
            process.waitUntilExit()
        }

        if process.terminationStatus != 0 {
            throw BlockEngineError.sudoFailed
        }
    }

    private func flushDNSCache() throws {
        try runSudoCommand(["dscacheutil", "-flushcache"])
        try runSudoCommand(["killall", "-HUP", "mDNSResponder"])
    }
}

public enum BlockEngineError: Error, LocalizedError {
    case sudoFailed
    case hostsFileNotFound
    case insufficientPermissions

    public var errorDescription: String? {
        switch self {
        case .sudoFailed:
            "Failed to modify hosts file. sudo may have been cancelled or failed."
        case .hostsFileNotFound:
            "Hosts file not found at /etc/hosts"
        case .insufficientPermissions:
            "Insufficient permissions to modify hosts file"
        }
    }
}

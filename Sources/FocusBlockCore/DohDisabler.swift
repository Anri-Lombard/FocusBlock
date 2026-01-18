import Foundation
import AppKit

public enum DohError: Error, LocalizedError {
    case commandFailed(String)
    case fileAccessError(String)
    case stateLoadError(String)

    public var errorDescription: String? {
        switch self {
        case .commandFailed(let msg): return "Command failed: \(msg)"
        case .fileAccessError(let msg): return "File access error: \(msg)"
        case .stateLoadError(let msg): return "State load error: \(msg)"
        }
    }
}

public struct DohResult {
    public let success: [String]
    public let skipped: [String]
    public let failed: [(String, Error)]

    public init(success: [String] = [], skipped: [String] = [], failed: [(String, Error)] = []) {
        self.success = success
        self.skipped = skipped
        self.failed = failed
    }
}

public struct BrowserStatus {
    public let name: String
    public let bundleId: String
    public let dohDisabled: Bool
    public let installed: Bool

    public init(name: String, bundleId: String, dohDisabled: Bool, installed: Bool) {
        self.name = name
        self.bundleId = bundleId
        self.dohDisabled = dohDisabled
        self.installed = installed
    }
}

public struct DohStatus {
    public let browsers: [BrowserStatus]

    public init(browsers: [BrowserStatus]) {
        self.browsers = browsers
    }
}

struct FirefoxProfile {
    let path: String
    let name: String
}

struct DohState: Codable {
    var chromiumSettings: [String: Bool]
    var firefoxProfiles: [String]
    var timestamp: Int64

    init(chromiumSettings: [String: Bool] = [:], firefoxProfiles: [String] = [], timestamp: Int64 = Int64(Date().timeIntervalSince1970)) {
        self.chromiumSettings = chromiumSettings
        self.firefoxProfiles = firefoxProfiles
        self.timestamp = timestamp
    }
}

public class DohDisabler {
    private let stateFilePath: String
    private let chromiumBrowsers: [(name: String, bundleId: String, key: String)]

    public init() throws {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config")
            .appendingPathComponent("focusblock")

        try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)

        self.stateFilePath = configDir.appendingPathComponent("doh-state.json").path

        self.chromiumBrowsers = [
            (name: "Arc", bundleId: "company.thebrowser.Browser", key: "BuiltInDnsClientEnabled"),
            (name: "Chrome", bundleId: "com.google.Chrome", key: "BuiltInDnsClientEnabled"),
            (name: "Brave", bundleId: "com.brave.Browser", key: "BuiltInDnsClientEnabled")
        ]
    }

    public func disableDoH() throws -> DohResult {
        var success: [String] = []
        var skipped: [String] = []
        var failed: [(String, Error)] = []
        var state = loadState() ?? DohState()
        var browsersToRestart: [String] = []

        for browser in chromiumBrowsers {
            if !isBrowserInstalled(bundleId: browser.bundleId) {
                skipped.append(browser.name)
                continue
            }

            let wasRunning = isBrowserRunning(bundleId: browser.bundleId)

            do {
                let hadDoH = try hasDoHEnabled(bundleId: browser.bundleId, key: browser.key)
                state.chromiumSettings[browser.bundleId] = hadDoH
                try disableChromium(browser)
                success.append(browser.name)

                if wasRunning {
                    browsersToRestart.append(browser.name)
                }
            } catch {
                failed.append((browser.name, error))
            }
        }

        do {
            let profiles = try findFirefoxProfiles()
            if profiles.isEmpty {
                skipped.append("Firefox")
            } else {
                let wasRunning = isBrowserRunning(bundleId: "org.mozilla.firefox")
                try disableFirefox(profiles: profiles)
                state.firefoxProfiles = profiles.map { $0.path }
                success.append("Firefox (\(profiles.count) profile\(profiles.count == 1 ? "" : "s"))")

                if wasRunning {
                    browsersToRestart.append("Firefox")
                }
            }
        } catch {
            if !isFirefoxInstalled() {
                skipped.append("Firefox")
            } else {
                failed.append(("Firefox", error))
            }
        }

        try saveState(state)

        if !browsersToRestart.isEmpty {
            restartBrowsers(browsersToRestart)
        }

        return DohResult(success: success, skipped: skipped, failed: failed)
    }

    public func enableDoH() throws -> DohResult {
        var success: [String] = []
        var skipped: [String] = []
        var failed: [(String, Error)] = []

        guard let state = loadState() else {
            throw DohError.stateLoadError("No saved state found. DoH may not have been disabled by FocusBlock.")
        }

        for browser in chromiumBrowsers {
            if !isBrowserInstalled(bundleId: browser.bundleId) {
                skipped.append(browser.name)
                continue
            }

            do {
                if let hadDoH = state.chromiumSettings[browser.bundleId], hadDoH {
                    try enableChromium(browser)
                    success.append(browser.name)
                } else {
                    try deleteChromiumSetting(browser)
                    success.append(browser.name)
                }
            } catch {
                failed.append((browser.name, error))
            }
        }

        if !state.firefoxProfiles.isEmpty {
            do {
                try enableFirefox(profilePaths: state.firefoxProfiles)
                success.append("Firefox (\(state.firefoxProfiles.count) profile\(state.firefoxProfiles.count == 1 ? "" : "s"))")
            } catch {
                failed.append(("Firefox", error))
            }
        }

        try? FileManager.default.removeItem(atPath: stateFilePath)

        return DohResult(success: success, skipped: skipped, failed: failed)
    }

    public func verifyDoHStatus() -> DohStatus {
        var browsers: [BrowserStatus] = []

        for browser in chromiumBrowsers {
            let installed = isBrowserInstalled(bundleId: browser.bundleId)
            let disabled = installed ? (try? !hasDoHEnabled(bundleId: browser.bundleId, key: browser.key)) ?? false : false
            browsers.append(BrowserStatus(name: browser.name, bundleId: browser.bundleId, dohDisabled: disabled, installed: installed))
        }

        let firefoxInstalled = isFirefoxInstalled()
        if firefoxInstalled {
            let profiles = (try? findFirefoxProfiles()) ?? []
            let disabled = profiles.allSatisfy { (try? isFirefoxDoHDisabled(profile: $0)) ?? false }
            browsers.append(BrowserStatus(name: "Firefox", bundleId: "org.mozilla.firefox", dohDisabled: disabled, installed: true))
        } else {
            browsers.append(BrowserStatus(name: "Firefox", bundleId: "org.mozilla.firefox", dohDisabled: false, installed: false))
        }

        return DohStatus(browsers: browsers)
    }

    private func disableChromium(_ browser: (name: String, bundleId: String, key: String)) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["write", browser.bundleId, browser.key, "-bool", "false"]

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw DohError.commandFailed("Failed to disable DoH for \(browser.name)")
        }
    }

    private func enableChromium(_ browser: (name: String, bundleId: String, key: String)) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["write", browser.bundleId, browser.key, "-bool", "true"]

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw DohError.commandFailed("Failed to enable DoH for \(browser.name)")
        }
    }

    private func deleteChromiumSetting(_ browser: (name: String, bundleId: String, key: String)) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["delete", browser.bundleId, browser.key]

        try process.run()
        process.waitUntilExit()
    }

    private func hasDoHEnabled(bundleId: String, key: String) throws -> Bool {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["read", bundleId, key]
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            return true
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return output == "1"
    }

    private func findFirefoxProfiles() throws -> [FirefoxProfile] {
        let profilesDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Firefox/Profiles")

        guard FileManager.default.fileExists(atPath: profilesDir.path) else {
            return []
        }

        let contents = try FileManager.default.contentsOfDirectory(at: profilesDir, includingPropertiesForKeys: nil)

        return contents.filter { $0.hasDirectoryPath }.map {
            FirefoxProfile(path: $0.path, name: $0.lastPathComponent)
        }
    }

    private func disableFirefox(profiles: [FirefoxProfile]) throws {
        for profile in profiles {
            let userJsPath = URL(fileURLWithPath: profile.path).appendingPathComponent("user.js")
            let dohPref = "user_pref(\"network.trr.mode\", 5);\n"

            if FileManager.default.fileExists(atPath: userJsPath.path) {
                let existingContent = try String(contentsOf: userJsPath, encoding: .utf8)
                if !existingContent.contains("network.trr.mode") {
                    try (existingContent + dohPref).write(to: userJsPath, atomically: true, encoding: .utf8)
                }
            } else {
                try dohPref.write(to: userJsPath, atomically: true, encoding: .utf8)
            }
        }
    }

    private func enableFirefox(profilePaths: [String]) throws {
        for path in profilePaths {
            let userJsPath = URL(fileURLWithPath: path).appendingPathComponent("user.js")

            guard FileManager.default.fileExists(atPath: userJsPath.path) else { continue }

            let content = try String(contentsOf: userJsPath, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            let filtered = lines.filter { !$0.contains("network.trr.mode") }

            if filtered.isEmpty || filtered.allSatisfy({ $0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                try? FileManager.default.removeItem(at: userJsPath)
            } else {
                try filtered.joined(separator: "\n").write(to: userJsPath, atomically: true, encoding: .utf8)
            }
        }
    }

    private func isFirefoxDoHDisabled(profile: FirefoxProfile) throws -> Bool {
        let userJsPath = URL(fileURLWithPath: profile.path).appendingPathComponent("user.js")

        guard FileManager.default.fileExists(atPath: userJsPath.path) else {
            return false
        }

        let content = try String(contentsOf: userJsPath, encoding: .utf8)
        return content.contains("network.trr.mode") && content.contains("5")
    }

    private func isBrowserInstalled(bundleId: String) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil
    }

    private func isFirefoxInstalled() -> Bool {
        isBrowserInstalled(bundleId: "org.mozilla.firefox")
    }

    private func isBrowserRunning(bundleId: String) -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { $0.bundleIdentifier == bundleId }
    }

    private func restartBrowsers(_ browserNames: [String]) {
        print("\n⚠️  Restarting browsers to apply DoH changes...")
        for name in browserNames {
            print("   Restarting \(name)...")
        }

        let runningApps = NSWorkspace.shared.runningApplications
        let browserBundleIds = chromiumBrowsers.map { $0.bundleId } + ["org.mozilla.firefox"]

        for app in runningApps {
            guard let bundleId = app.bundleIdentifier else { continue }
            guard browserBundleIds.contains(bundleId) else { continue }

            app.terminate()
            Thread.sleep(forTimeInterval: 0.5)

            if !app.isTerminated {
                app.forceTerminate()
            }
        }

        print("   Browsers restarted. DoH settings are now active.")
    }

    private func saveState(_ state: DohState) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(state)
        try data.write(to: URL(fileURLWithPath: stateFilePath))
    }

    private func loadState() -> DohState? {
        guard FileManager.default.fileExists(atPath: stateFilePath) else {
            return nil
        }

        guard let data = try? Data(contentsOf: URL(fileURLWithPath: stateFilePath)) else {
            return nil
        }

        return try? JSONDecoder().decode(DohState.self, from: data)
    }
}

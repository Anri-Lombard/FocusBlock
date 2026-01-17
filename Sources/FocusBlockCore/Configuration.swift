import Foundation

public class Configuration {
    private let configURL: URL
    private var config: Config

    public init() throws {
        let fileManager = FileManager.default
        let appSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let focusBlockDir = appSupportURL.appendingPathComponent("FocusBlock", isDirectory: true)
        try fileManager.createDirectory(at: focusBlockDir, withIntermediateDirectories: true)

        configURL = focusBlockDir.appendingPathComponent("config.json")

        if fileManager.fileExists(atPath: configURL.path) {
            let data = try Data(contentsOf: configURL)
            config = try JSONDecoder().decode(Config.self, from: data)
        } else {
            config = Config()
            try save()
        }
    }

    public var defaultDuration: Int {
        get { config.defaultDuration }
        set {
            config.defaultDuration = newValue
            try? save()
        }
    }

    public var defaultSites: [String] {
        get { config.defaultSites }
        set {
            config.defaultSites = newValue
            try? save()
        }
    }

    public func get(key: String) -> String? {
        switch key {
        case "default_duration":
            return "\(config.defaultDuration)"
        case "default_sites":
            return config.defaultSites.joined(separator: ",")
        default:
            return nil
        }
    }

    public func set(key: String, value: String) throws {
        switch key {
        case "default_duration":
            guard let duration = Int(value), duration > 0 else {
                throw ConfigurationError.invalidValue("Duration must be a positive integer")
            }
            config.defaultDuration = duration
        case "default_sites":
            config.defaultSites = value.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        default:
            throw ConfigurationError.unknownKey(key)
        }
        try save()
    }

    public func reset() throws {
        config = Config()
        try save()
    }

    private func save() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: configURL)
    }
}

public enum ConfigurationError: Error, LocalizedError {
    case invalidValue(String)
    case unknownKey(String)

    public var errorDescription: String? {
        switch self {
        case .invalidValue(let message):
            return message
        case .unknownKey(let key):
            return "Unknown configuration key: \(key)"
        }
    }
}

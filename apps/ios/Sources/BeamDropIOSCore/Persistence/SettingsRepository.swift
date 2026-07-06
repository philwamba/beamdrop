import Foundation

public struct BeamDropSettings: Codable, Equatable, Sendable {
    public var deviceName: String
    public var autoAcceptTrustedDevices: Bool
    public var preferredTheme: String

    public init(deviceName: String = "iPhone", autoAcceptTrustedDevices: Bool = false, preferredTheme: String = "system") {
        self.deviceName = deviceName
        self.autoAcceptTrustedDevices = autoAcceptTrustedDevices
        self.preferredTheme = preferredTheme
    }
}

public final class SettingsRepository {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() throws -> BeamDropSettings {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return BeamDropSettings() }
        return try decoder.decode(BeamDropSettings.self, from: Data(contentsOf: fileURL))
    }

    public func save(_ settings: BeamDropSettings) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(settings).write(to: fileURL, options: [.atomic])
    }
}

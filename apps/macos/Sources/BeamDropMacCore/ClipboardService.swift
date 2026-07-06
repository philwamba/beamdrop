import AppKit
import Foundation

public struct ClipboardSettings: Codable, Equatable, Sendable {
    public var sharingEnabled: Bool
    public var pauseUntilRestart: Bool

    public init(sharingEnabled: Bool = false, pauseUntilRestart: Bool = false) {
        self.sharingEnabled = sharingEnabled
        self.pauseUntilRestart = pauseUntilRestart
    }
}

public enum ClipboardPolicy {
    public static func canSend(text: String, settings: ClipboardSettings) -> Result<Void, BeamDropError> {
        guard settings.sharingEnabled, !settings.pauseUntilRestart else {
            return .failure(.clipboardBlocked("Clipboard sharing is paused or disabled."))
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(.clipboardBlocked("Clipboard is empty."))
        }
        guard !looksSensitive(trimmed) else {
            return .failure(.clipboardBlocked("Clipboard looks sensitive. Use explicit text send if this is intentional."))
        }
        return .success(())
    }

    public static func looksSensitive(_ text: String) -> Bool {
        let patterns = [
            #"(?i)\b(password|passcode|otp|2fa|secret|token|api[_ -]?key)\b"#,
            #"\b\d{3}-\d{2}-\d{4}\b"#,
            #"\b(?:\d[ -]*?){13,19}\b"#,
            #"-----BEGIN [A-Z ]*PRIVATE KEY-----"#
        ]
        return patterns.contains { text.range(of: $0, options: .regularExpression) != nil }
    }
}

public final class ClipboardService {
    public init() {}

    public func readText() -> String? {
        NSPasteboard.general.string(forType: .string)
    }

    public func writeText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

public final class ClipboardSettingsStore {
    private let key = "BeamDropClipboardSettings"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> ClipboardSettings {
        guard let data = defaults.data(forKey: key),
              let settings = try? BeamDropJSON.decoder.decode(ClipboardSettings.self, from: data) else {
            return ClipboardSettings()
        }
        return settings
    }

    public func save(_ settings: ClipboardSettings) {
        defaults.set(try? BeamDropJSON.encoder.encode(settings), forKey: key)
    }
}

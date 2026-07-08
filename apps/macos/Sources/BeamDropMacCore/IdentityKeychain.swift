import CryptoKit
import Foundation
import Security

public struct DeviceIdentity: Codable, Equatable, Sendable {
    public let deviceId: String
    public let deviceName: String
    public let platform: BeamDropPlatform
    public let publicKey: String
    public let fingerprint: String

    public init(deviceId: String, deviceName: String, platform: BeamDropPlatform = .macos, publicKey: String, fingerprint: String) {
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.platform = platform
        self.publicKey = publicKey
        self.fingerprint = fingerprint
    }
}

public protocol SecretStore {
    func read(service: String, account: String) throws -> Data?
    func write(_ data: Data, service: String, account: String) throws
    func delete(service: String, account: String) throws
}

public final class KeychainSecretStore: SecretStore {
    public init() {}

    public func read(service: String, account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.status(status) }
        return item as? Data
    }

    public func write(_ data: Data, service: String, account: String) throws {
        try delete(service: service, account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.status(status) }
    }

    public func delete(service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError.status(status) }
    }
}

public enum KeychainError: Error, LocalizedError, Equatable {
    case status(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .status(let status):
            return "Keychain operation failed with status \(status)."
        }
    }
}

public final class InMemorySecretStore: SecretStore {
    private var values: [String: Data] = [:]
    private let lock = NSLock()

    public init() {}

    public func read(service: String, account: String) throws -> Data? {
        lock.withLock { values[key(service, account)] }
    }

    public func write(_ data: Data, service: String, account: String) throws {
        lock.withLock { values[key(service, account)] = data }
    }

    public func delete(service: String, account: String) throws {
        _ = lock.withLock { values.removeValue(forKey: key(service, account)) }
    }

    private func key(_ service: String, _ account: String) -> String {
        "\(service)::\(account)"
    }
}

public final class DeviceIdentityService {
    private let secretStore: SecretStore
    private let serviceName = "com.beamdrop.mac.identity"
    private let accountName = "device-identity"

    public init(secretStore: SecretStore = KeychainSecretStore()) {
        self.secretStore = secretStore
    }

    public func getOrCreateIdentity(deviceName: String = Host.current().localizedName ?? "Mac") throws -> DeviceIdentity {
        try getOrCreateStoredIdentity(deviceName: deviceName).identity
    }

    public func getOrCreateSessionPrivateKey(deviceName: String = Host.current().localizedName ?? "Mac") throws -> Data {
        try getOrCreateStoredIdentity(deviceName: deviceName).privateKeyRawRepresentation
    }

    private func getOrCreateStoredIdentity(deviceName: String) throws -> StoredIdentity {
        if let data = try secretStore.read(service: serviceName, account: accountName),
           let stored = try? BeamDropJSON.decoder.decode(StoredIdentity.self, from: data),
           (try? X25519PublicKeyCodec.rawKey(spkiBase64: stored.identity.publicKey)) != nil {
            return stored
        }

        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        let publicKey = try X25519PublicKeyCodec.spkiBase64(rawKey: privateKey.publicKey.rawRepresentation)
        let fingerprint = PeerFingerprint.fingerprint(publicKey: publicKey)
        let identity = DeviceIdentity(
            deviceId: "macos-\(UUID().uuidString.lowercased())",
            deviceName: deviceName,
            publicKey: publicKey,
            fingerprint: fingerprint
        )
        let stored = StoredIdentity(identity: identity, privateKeyRawRepresentation: privateKey.rawRepresentation)
        let data = try BeamDropJSON.encoder.encode(stored)
        try secretStore.write(data, service: serviceName, account: accountName)
        return stored
    }
}

private struct StoredIdentity: Codable {
    let identity: DeviceIdentity
    let privateKeyRawRepresentation: Data
}

public enum PeerFingerprint {
    public static func fingerprint(publicKey: String) -> String {
        let hash = SHA256.hash(data: Data(publicKey.utf8))
        let hex = hash.hexString
        return stride(from: 0, to: min(hex.count, 32), by: 4)
            .map {
                let start = hex.index(hex.startIndex, offsetBy: $0)
                let end = hex.index(start, offsetBy: min(4, hex.distance(from: start, to: hex.endIndex)))
                return String(hex[start..<end])
            }
            .joined(separator: "-")
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}

import CryptoKit
import Foundation

public final class DeviceIdentityService {
    private let keychain: KeychainStoring
    private let deviceIdKey = "beamdrop.deviceId"
    private let sessionPrivateKeyKey = "beamdrop.privateKey.x25519.v1"

    public init(keychain: KeychainStoring) {
        self.keychain = keychain
    }

    public func getOrCreate(deviceName: String) throws -> DeviceIdentity {
        let deviceId: String
        if let existing = try keychain.load(key: deviceIdKey), let decoded = String(data: existing, encoding: .utf8) {
            deviceId = decoded
        } else {
            deviceId = "bd-ios-\(UUID().uuidString.lowercased())"
            try keychain.save(key: deviceIdKey, data: Data(deviceId.utf8))
        }

        let privateKey = try loadOrCreateSessionPrivateKey()

        return DeviceIdentity(
            deviceId: deviceId,
            deviceName: deviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "iPhone" : deviceName,
            platform: .ios,
            publicKey: try X25519KeyCodec.base64SPKI(fromRawKey: privateKey.publicKey.rawRepresentation)
        )
    }

    /// Raw 32-byte X25519 static secret used to derive per-transfer session keys.
    public func sessionSecretKey() throws -> Data {
        try loadOrCreateSessionPrivateKey().rawRepresentation
    }

    private func loadOrCreateSessionPrivateKey() throws -> Curve25519.KeyAgreement.PrivateKey {
        if let raw = try keychain.load(key: sessionPrivateKeyKey) {
            return try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: raw)
        }
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        try keychain.save(key: sessionPrivateKeyKey, data: privateKey.rawRepresentation)
        return privateKey
    }
}

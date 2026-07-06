import CryptoKit
import Foundation

public final class DeviceIdentityService {
    private let keychain: KeychainStoring
    private let deviceIdKey = "beamdrop.deviceId"
    private let privateKeyKey = "beamdrop.privateKey.p256.v1"

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

        let privateKey: P256.Signing.PrivateKey
        if let raw = try keychain.load(key: privateKeyKey) {
            privateKey = try P256.Signing.PrivateKey(rawRepresentation: raw)
        } else {
            privateKey = P256.Signing.PrivateKey()
            try keychain.save(key: privateKeyKey, data: privateKey.rawRepresentation)
        }

        return DeviceIdentity(
            deviceId: deviceId,
            deviceName: deviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "iPhone" : deviceName,
            platform: .ios,
            publicKey: privateKey.publicKey.rawRepresentation.base64EncodedString()
        )
    }
}

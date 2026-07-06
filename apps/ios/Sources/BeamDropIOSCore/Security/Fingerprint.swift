import CryptoKit
import Foundation

public enum Fingerprint {
    public static func publicKeyFingerprint(_ publicKey: String) -> String {
        let digest = SHA256.hash(data: Data(publicKey.utf8))
        return digest.prefix(8).map { String(format: "%02X", $0) }.joined(separator: ":")
    }

    public static func sha256Hex(data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public static func sha256Hex(fileURL: URL) throws -> String {
        let data = try Data(contentsOf: fileURL)
        return sha256Hex(data: data)
    }
}

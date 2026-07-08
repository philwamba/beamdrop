import CryptoKit
import Foundation

public struct SessionCrypto: Sendable {
    public static let sealedOverheadBytes = 28

    public let ephemeralPublicKey: Data
    let sessionKey: SymmetricKey
    private let senderDeviceId: String
    private let receiverDeviceId: String
    private let transferId: String

    private init(sessionKey: SymmetricKey, ephemeralPublicKey: Data, senderDeviceId: String, receiverDeviceId: String, transferId: String) {
        self.sessionKey = sessionKey
        self.ephemeralPublicKey = ephemeralPublicKey
        self.senderDeviceId = senderDeviceId
        self.receiverDeviceId = receiverDeviceId
        self.transferId = transferId
    }

    public static func initiate(
        senderStaticSecret: Data,
        receiverStaticPublic: Data,
        senderDeviceId: String,
        receiverDeviceId: String,
        transferId: String,
        ephemeralSecret: Data? = nil
    ) throws -> SessionCrypto {
        let ephemeralKey = try ephemeralSecret.map(privateKey(from:)) ?? Curve25519.KeyAgreement.PrivateKey()
        let senderKey = try privateKey(from: senderStaticSecret)
        let receiverPublic = try publicKey(from: receiverStaticPublic)
        let dh1 = try sharedSecret(ephemeralKey, receiverPublic)
        let dh2 = try sharedSecret(senderKey, receiverPublic)
        let ephemeralPublic = ephemeralKey.publicKey.rawRepresentation
        let sessionKey = deriveSessionKey(
            dh1: dh1,
            dh2: dh2,
            senderDeviceId: senderDeviceId,
            receiverDeviceId: receiverDeviceId,
            transferId: transferId,
            ephemeralPublic: ephemeralPublic,
            senderStaticPublic: senderKey.publicKey.rawRepresentation,
            receiverStaticPublic: receiverPublic.rawRepresentation
        )
        return SessionCrypto(
            sessionKey: sessionKey,
            ephemeralPublicKey: ephemeralPublic,
            senderDeviceId: senderDeviceId,
            receiverDeviceId: receiverDeviceId,
            transferId: transferId
        )
    }

    public static func accept(
        receiverStaticSecret: Data,
        senderStaticPublic: Data,
        ephemeralPublic: Data,
        senderDeviceId: String,
        receiverDeviceId: String,
        transferId: String
    ) throws -> SessionCrypto {
        let receiverKey = try privateKey(from: receiverStaticSecret)
        let senderPublic = try publicKey(from: senderStaticPublic)
        let ephemeralKey = try publicKey(from: ephemeralPublic)
        let dh1 = try sharedSecret(receiverKey, ephemeralKey)
        let dh2 = try sharedSecret(receiverKey, senderPublic)
        let sessionKey = deriveSessionKey(
            dh1: dh1,
            dh2: dh2,
            senderDeviceId: senderDeviceId,
            receiverDeviceId: receiverDeviceId,
            transferId: transferId,
            ephemeralPublic: ephemeralKey.rawRepresentation,
            senderStaticPublic: senderPublic.rawRepresentation,
            receiverStaticPublic: receiverKey.publicKey.rawRepresentation
        )
        return SessionCrypto(
            sessionKey: sessionKey,
            ephemeralPublicKey: ephemeralKey.rawRepresentation,
            senderDeviceId: senderDeviceId,
            receiverDeviceId: receiverDeviceId,
            transferId: transferId
        )
    }

    public func sealChunk(_ plaintext: Data, index: Int64) throws -> Data {
        do {
            let nonce = try ChaChaPoly.Nonce(data: Self.nonce(index: index))
            let box = try ChaChaPoly.seal(plaintext, using: sessionKey, nonce: nonce, authenticating: additionalData(index: index))
            return box.combined
        } catch {
            throw BeamDropError.encryptionFailure("Chunk \(index) could not be sealed.")
        }
    }

    public func openChunk(_ sealed: Data, index: Int64) throws -> Data {
        do {
            let box = try ChaChaPoly.SealedBox(combined: sealed)
            return try ChaChaPoly.open(box, using: sessionKey, authenticating: additionalData(index: index))
        } catch {
            throw BeamDropError.encryptionFailure("Chunk \(index) failed authenticated decryption.")
        }
    }

    private func additionalData(index: Int64) -> Data {
        var aad = Data("beamdrop-chunk-v1".utf8)
        aad.append(0x00)
        aad.append(Data(senderDeviceId.utf8))
        aad.append(0x00)
        aad.append(Data(receiverDeviceId.utf8))
        aad.append(0x00)
        aad.append(Data(transferId.utf8))
        aad.append(0x00)
        aad.append(Self.bigEndianBytes(index))
        return aad
    }

    private static func nonce(index: Int64) -> Data {
        Data([0x01, 0x00, 0x00, 0x00]) + bigEndianBytes(index)
    }

    private static func bigEndianBytes(_ index: Int64) -> Data {
        withUnsafeBytes(of: UInt64(index).bigEndian) { Data($0) }
    }

    private static func deriveSessionKey(
        dh1: Data,
        dh2: Data,
        senderDeviceId: String,
        receiverDeviceId: String,
        transferId: String,
        ephemeralPublic: Data,
        senderStaticPublic: Data,
        receiverStaticPublic: Data
    ) -> SymmetricKey {
        let salt = Data(SHA256.hash(data: Data("BeamDropSession-v1".utf8) + Data(transferId.utf8)))
        var info = Data(senderDeviceId.utf8)
        info.append(0x00)
        info.append(Data(receiverDeviceId.utf8))
        info.append(0x00)
        info.append(ephemeralPublic)
        info.append(senderStaticPublic)
        info.append(receiverStaticPublic)
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: dh1 + dh2),
            salt: salt,
            info: info,
            outputByteCount: 32
        )
    }

    private static func privateKey(from raw: Data) throws -> Curve25519.KeyAgreement.PrivateKey {
        do {
            return try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: raw)
        } catch {
            throw BeamDropError.encryptionFailure("Private key is not a valid 32-byte X25519 secret.")
        }
    }

    private static func publicKey(from raw: Data) throws -> Curve25519.KeyAgreement.PublicKey {
        do {
            return try Curve25519.KeyAgreement.PublicKey(rawRepresentation: raw)
        } catch {
            throw BeamDropError.encryptionFailure("Public key is not a valid 32-byte X25519 key.")
        }
    }

    private static func sharedSecret(_ privateKey: Curve25519.KeyAgreement.PrivateKey, _ publicKey: Curve25519.KeyAgreement.PublicKey) throws -> Data {
        guard let secret = try? privateKey.sharedSecretFromKeyAgreement(with: publicKey) else {
            throw BeamDropError.encryptionFailure("X25519 key agreement failed.")
        }
        let bytes = secret.withUnsafeBytes { Data($0) }
        guard bytes.contains(where: { $0 != 0 }) else {
            throw BeamDropError.encryptionFailure("Peer key produced an all-zero shared secret.")
        }
        return bytes
    }
}

public enum X25519PublicKeyCodec {
    private static let spkiPrefix = Data([0x30, 0x2a, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x6e, 0x03, 0x21, 0x00])

    public static func rawKey(spkiBase64: String) throws -> Data {
        guard
            let der = Data(base64Encoded: spkiBase64),
            der.count == spkiPrefix.count + 32,
            der.prefix(spkiPrefix.count) == spkiPrefix
        else {
            throw BeamDropError.encryptionFailure("Public key is not base64 DER SPKI X25519.")
        }
        return der.suffix(32)
    }

    public static func spkiBase64(rawKey: Data) throws -> String {
        guard rawKey.count == 32 else {
            throw BeamDropError.encryptionFailure("Raw X25519 public key must be 32 bytes.")
        }
        return (spkiPrefix + rawKey).base64EncodedString()
    }
}

extension Data {
    init?(hexEncoded: String) {
        guard hexEncoded.count.isMultiple(of: 2) else { return nil }
        var bytes = [UInt8]()
        bytes.reserveCapacity(hexEncoded.count / 2)
        var iterator = hexEncoded.makeIterator()
        while let high = iterator.next(), let low = iterator.next() {
            guard high.isHexDigit, low.isHexDigit, let byte = UInt8("\(high)\(low)", radix: 16) else { return nil }
            bytes.append(byte)
        }
        self.init(bytes)
    }

    var hexEncodedString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

import CryptoKit
import Foundation

/// Authenticated transfer session encryption (BeamDrop session protocol v1).
///
/// Establishes a per-transfer symmetric key between two paired devices using
/// X25519 key agreement, then encrypts each chunk with ChaCha20-Poly1305.
///
/// Key schedule:
/// - `dh1 = X25519(ephemeralSecret, receiverStaticPublic)` — receiver confidentiality
///   and forward secrecy with respect to the sender's static key.
/// - `dh2 = X25519(senderStaticSecret, receiverStaticPublic)` — sender authentication:
///   only the holder of the paired sender key can derive the session key.
/// - `sessionKey = HKDF-SHA256(salt = SHA256("BeamDropSession-v1" || transferId),
///   ikm = dh1 || dh2, info = ids || ephPub || senderPub || receiverPub)`.
///
/// Every chunk nonce is deterministic (direction byte plus big-endian chunk index),
/// which is safe because the session key is unique per transfer, and the AAD binds
/// the sender, receiver, transfer id, and chunk index so ciphertexts cannot be
/// replayed across chunks, transfers, or device pairs.
public enum TransferSessionError: Error, Equatable, LocalizedError {
    case invalidKeyLength
    case invalidPeerKey
    case invalidContext
    case invalidSealedChunk
    case chunkAuthenticationFailed
    case sealingFailed

    public var errorDescription: String? {
        switch self {
        case .invalidKeyLength: "X25519 keys must be exactly 32 raw bytes."
        case .invalidPeerKey: "Peer public key is invalid or produced a degenerate shared secret."
        case .invalidContext: "Session context requires non-empty sender, receiver, and transfer ids."
        case .invalidSealedChunk: "Sealed chunk is malformed or does not match its chunk index."
        case .chunkAuthenticationFailed: "Chunk failed authenticated decryption."
        case .sealingFailed: "Chunk could not be sealed."
        }
    }
}

/// Binds a session to one direction of one transfer between two paired devices.
public struct TransferSessionContext: Equatable, Sendable {
    public var senderDeviceId: String
    public var receiverDeviceId: String
    public var transferId: String

    public init(senderDeviceId: String, receiverDeviceId: String, transferId: String) {
        self.senderDeviceId = senderDeviceId
        self.receiverDeviceId = receiverDeviceId
        self.transferId = transferId
    }
}

/// A per-transfer AEAD session. Data flows sender → receiver; each chunk index
/// must be sealed at most once.
public struct TransferSession: Sendable {
    public static let keyLength = 32
    public static let nonceLength = 12
    public static let tagLength = 16
    public static let sealedChunkOverhead = nonceLength + tagLength

    private static let saltPrefix = Data("BeamDropSession-v1".utf8)
    private static let chunkAADPrefix = Data("beamdrop-chunk-v1".utf8)
    private static let directionSenderToReceiver: UInt8 = 0x01

    private let key: SymmetricKey
    private let context: TransferSessionContext

    private init(key: SymmetricKey, context: TransferSessionContext) {
        self.key = key
        self.context = context
    }

    /// Sender side: derive a session key toward `receiverPublicKey` (raw 32 bytes)
    /// and produce the ephemeral public key the receiver needs to derive the same key.
    public static func initiate(
        senderSecretKey: Data,
        receiverPublicKey: Data,
        context: TransferSessionContext
    ) throws -> (ephemeralPublicKey: Data, session: TransferSession) {
        try initiate(
            senderSecretKey: senderSecretKey,
            receiverPublicKey: receiverPublicKey,
            context: context,
            ephemeralSecretKey: Curve25519.KeyAgreement.PrivateKey().rawRepresentation
        )
    }

    /// Deterministic variant used for cross-platform conformance vectors. Production
    /// callers must use `initiate(senderSecretKey:receiverPublicKey:context:)` so the
    /// ephemeral key is never reused.
    public static func initiate(
        senderSecretKey: Data,
        receiverPublicKey: Data,
        context: TransferSessionContext,
        ephemeralSecretKey: Data
    ) throws -> (ephemeralPublicKey: Data, session: TransferSession) {
        try validate(context)
        let senderSecret = try privateKey(fromRaw: senderSecretKey)
        let ephemeralSecret = try privateKey(fromRaw: ephemeralSecretKey)
        let receiverPublic = try publicKey(fromRaw: receiverPublicKey)

        let dh1 = try sharedSecret(ephemeralSecret, receiverPublic)
        let dh2 = try sharedSecret(senderSecret, receiverPublic)

        let ephemeralPublic = ephemeralSecret.publicKey.rawRepresentation
        let key = deriveSessionKey(
            context: context,
            dh1: dh1,
            dh2: dh2,
            ephemeralPublicKey: ephemeralPublic,
            senderPublicKey: senderSecret.publicKey.rawRepresentation,
            receiverPublicKey: receiverPublic.rawRepresentation
        )
        return (ephemeralPublic, TransferSession(key: key, context: context))
    }

    /// Receiver side: derive the session key from the sender's ephemeral public key.
    /// `senderPublicKey` must come from the local trusted-peer store, which is what
    /// authenticates the sender — an attacker without the paired sender secret cannot
    /// compute `dh2` and thus cannot produce ciphertexts that authenticate.
    public static func accept(
        receiverSecretKey: Data,
        senderPublicKey: Data,
        ephemeralPublicKey: Data,
        context: TransferSessionContext
    ) throws -> TransferSession {
        try validate(context)
        let receiverSecret = try privateKey(fromRaw: receiverSecretKey)
        let senderPublic = try publicKey(fromRaw: senderPublicKey)
        let ephemeralPublic = try publicKey(fromRaw: ephemeralPublicKey)

        let dh1 = try sharedSecret(receiverSecret, ephemeralPublic)
        let dh2 = try sharedSecret(receiverSecret, senderPublic)

        let key = deriveSessionKey(
            context: context,
            dh1: dh1,
            dh2: dh2,
            ephemeralPublicKey: ephemeralPublic.rawRepresentation,
            senderPublicKey: senderPublic.rawRepresentation,
            receiverPublicKey: receiverSecret.publicKey.rawRepresentation
        )
        return TransferSession(key: key, context: context)
    }

    /// Encrypts one chunk. Output layout: `nonce(12) || ciphertext || tag(16)`.
    public func sealChunk(index: Int64, plaintext: Data) throws -> Data {
        guard index >= 0 else { throw TransferSessionError.invalidSealedChunk }
        do {
            let nonce = try ChaChaPoly.Nonce(data: Self.chunkNonce(index: index))
            let box = try ChaChaPoly.seal(plaintext, using: key, nonce: nonce, authenticating: Self.chunkAAD(context: context, index: index))
            return box.combined
        } catch {
            throw TransferSessionError.sealingFailed
        }
    }

    /// Decrypts and authenticates one chunk sealed by `sealChunk(index:plaintext:)`.
    public func openChunk(index: Int64, sealed: Data) throws -> Data {
        guard index >= 0, sealed.count >= Self.sealedChunkOverhead else { throw TransferSessionError.invalidSealedChunk }
        guard sealed.prefix(Self.nonceLength) == Self.chunkNonce(index: index) else { throw TransferSessionError.invalidSealedChunk }
        do {
            let box = try ChaChaPoly.SealedBox(combined: sealed)
            return try ChaChaPoly.open(box, using: key, authenticating: Self.chunkAAD(context: context, index: index))
        } catch {
            throw TransferSessionError.chunkAuthenticationFailed
        }
    }

    /// Exposes the derived session key for cross-platform conformance tests.
    var sessionKeyData: Data {
        key.withUnsafeBytes { Data($0) }
    }

    private static func validate(_ context: TransferSessionContext) throws {
        guard
            !context.senderDeviceId.trimmingCharacters(in: .whitespaces).isEmpty,
            !context.receiverDeviceId.trimmingCharacters(in: .whitespaces).isEmpty,
            !context.transferId.trimmingCharacters(in: .whitespaces).isEmpty
        else { throw TransferSessionError.invalidContext }
    }

    private static func privateKey(fromRaw raw: Data) throws -> Curve25519.KeyAgreement.PrivateKey {
        guard raw.count == keyLength, let key = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: raw) else {
            throw TransferSessionError.invalidKeyLength
        }
        return key
    }

    private static func publicKey(fromRaw raw: Data) throws -> Curve25519.KeyAgreement.PublicKey {
        guard raw.count == keyLength, let key = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: raw) else {
            throw TransferSessionError.invalidKeyLength
        }
        return key
    }

    /// X25519 with a low-order peer point yields an all-zero shared secret, which
    /// would let an attacker force a predictable key. Reject it outright.
    private static func sharedSecret(_ secret: Curve25519.KeyAgreement.PrivateKey, _ peer: Curve25519.KeyAgreement.PublicKey) throws -> Data {
        guard let shared = try? secret.sharedSecretFromKeyAgreement(with: peer) else {
            throw TransferSessionError.invalidPeerKey
        }
        let bytes = shared.withUnsafeBytes { Data($0) }
        guard bytes.contains(where: { $0 != 0 }) else { throw TransferSessionError.invalidPeerKey }
        return bytes
    }

    private static func deriveSessionKey(
        context: TransferSessionContext,
        dh1: Data,
        dh2: Data,
        ephemeralPublicKey: Data,
        senderPublicKey: Data,
        receiverPublicKey: Data
    ) -> SymmetricKey {
        var saltInput = saltPrefix
        saltInput.append(Data(context.transferId.utf8))
        let salt = Data(SHA256.hash(data: saltInput))

        var ikm = dh1
        ikm.append(dh2)

        var info = Data(context.senderDeviceId.utf8)
        info.append(0)
        info.append(Data(context.receiverDeviceId.utf8))
        info.append(0)
        info.append(ephemeralPublicKey)
        info.append(senderPublicKey)
        info.append(receiverPublicKey)

        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: ikm),
            salt: salt,
            info: info,
            outputByteCount: keyLength
        )
    }

    private static func chunkNonce(index: Int64) -> Data {
        var nonce = Data([directionSenderToReceiver, 0, 0, 0])
        nonce.append(bigEndianBytes(of: index))
        return nonce
    }

    private static func chunkAAD(context: TransferSessionContext, index: Int64) -> Data {
        var aad = chunkAADPrefix
        aad.append(0)
        aad.append(Data(context.senderDeviceId.utf8))
        aad.append(0)
        aad.append(Data(context.receiverDeviceId.utf8))
        aad.append(0)
        aad.append(Data(context.transferId.utf8))
        aad.append(0)
        aad.append(bigEndianBytes(of: index))
        return aad
    }

    private static func bigEndianBytes(of index: Int64) -> Data {
        withUnsafeBytes(of: UInt64(index).bigEndian) { Data($0) }
    }
}

/// Converts between raw 32-byte X25519 keys and the base64 DER SPKI encoding
/// BeamDrop apps exchange during pairing (`MCowBQYDK2VuAyEA...`).
public enum X25519KeyCodec {
    /// DER SubjectPublicKeyInfo header for an X25519 public key (RFC 8410).
    public static let derSPKIHeader = Data([0x30, 0x2A, 0x30, 0x05, 0x06, 0x03, 0x2B, 0x65, 0x6E, 0x03, 0x21, 0x00])

    public static func base64SPKI(fromRawKey raw: Data) throws -> String {
        guard raw.count == TransferSession.keyLength else { throw TransferSessionError.invalidKeyLength }
        var der = derSPKIHeader
        der.append(raw)
        return der.base64EncodedString()
    }

    /// The raw key is the last 32 bytes of the DER SPKI blob.
    public static func rawKey(fromBase64SPKI base64: String) throws -> Data {
        guard
            let der = Data(base64Encoded: base64),
            der.count == derSPKIHeader.count + TransferSession.keyLength,
            der.prefix(derSPKIHeader.count) == derSPKIHeader
        else { throw TransferSessionError.invalidKeyLength }
        return der.suffix(TransferSession.keyLength)
    }

    public static func isBase64SPKI(_ base64: String) -> Bool {
        (try? rawKey(fromBase64SPKI: base64)) != nil
    }
}

/// Hex helpers for wire fields such as the envelope's ephemeral public key.
public enum HexEncoding {
    public static func hex(from data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    public static func data(fromHex hex: String) -> Data? {
        let characters = Array(hex.lowercased())
        guard characters.count.isMultiple(of: 2) else { return nil }
        var bytes = Data(capacity: characters.count / 2)
        for pairStart in stride(from: 0, to: characters.count, by: 2) {
            guard let byte = UInt8(String(characters[pairStart...pairStart + 1]), radix: 16) else { return nil }
            bytes.append(byte)
        }
        return bytes
    }
}

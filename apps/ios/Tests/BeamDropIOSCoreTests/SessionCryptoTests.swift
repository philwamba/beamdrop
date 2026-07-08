import XCTest
@testable import BeamDropIOSCore

final class SessionCryptoTests: XCTestCase {
    // Conformance vectors from protocol/beamdrop-protocol/test-vectors/session-encryption-v1.json.
    private let senderDeviceId = "device-sender-01"
    private let receiverDeviceId = "device-receiver-02"
    private let transferId = "tx-0001"

    private let senderStaticSecretHex = "1111111111111111111111111111111111111111111111111111111111111111"
    private let senderStaticPublicHex = "7b4e909bbe7ffe44c465a220037d608ee35897d31ef972f07f74892cb0f73f13"
    private let receiverStaticSecretHex = "2222222222222222222222222222222222222222222222222222222222222222"
    private let receiverStaticPublicHex = "0faa684ed28867b97f4a6a2dee5df8ce974e76b7018e3f22a1c4cf2678570f20"
    private let ephemeralSecretHex = "4444444444444444444444444444444444444444444444444444444444444444"
    private let ephemeralPublicHex = "ff2ee45601ec1b67310c7790404585ae697331eee1c1f8cf2419731c1fff3e6b"
    private let sessionKeyHex = "fb67bd5e5472aec109bb4ef123ecf106782f76dd6ccef2c7b72db1b0bf8c8ecc"

    private let vectorChunks: [(index: Int64, plaintext: String, sealedHex: String)] = [
        (0, "BeamDrop chunk zero", "010000000000000000000000bbd2cd42ded08e24e8054fe22fd1aa439131de0b8f93e520c9b6fa149fc76716eebfe7"),
        (1, "BeamDrop chunk one", "010000000000000000000001572cefa90bc480e6e52513f8f029e6d6c42f7ca3377656d04ea0e349d9f175534a3c"),
        (2, "", "010000000000000000000002bb027ed44e2d74dad6563267b8acb77f")
    ]

    private var context: TransferSessionContext {
        TransferSessionContext(senderDeviceId: senderDeviceId, receiverDeviceId: receiverDeviceId, transferId: transferId)
    }

    private func hex(_ string: String) -> Data {
        HexEncoding.data(fromHex: string)!
    }

    private func initiateVectorSession() throws -> (ephemeralPublicKey: Data, session: TransferSession) {
        try TransferSession.initiate(
            senderSecretKey: hex(senderStaticSecretHex),
            receiverPublicKey: hex(receiverStaticPublicHex),
            context: context,
            ephemeralSecretKey: hex(ephemeralSecretHex)
        )
    }

    private func acceptVectorSession() throws -> TransferSession {
        try TransferSession.accept(
            receiverSecretKey: hex(receiverStaticSecretHex),
            senderPublicKey: hex(senderStaticPublicHex),
            ephemeralPublicKey: hex(ephemeralPublicHex),
            context: context
        )
    }

    func testConformanceVectorSessionKeyDerivation() throws {
        let (ephemeralPublicKey, session) = try initiateVectorSession()

        XCTAssertEqual(HexEncoding.hex(from: ephemeralPublicKey), ephemeralPublicHex)
        XCTAssertEqual(HexEncoding.hex(from: session.sessionKeyData), sessionKeyHex)
    }

    func testConformanceVectorChunkSealing() throws {
        let (_, session) = try initiateVectorSession()

        for chunk in vectorChunks {
            let sealed = try session.sealChunk(index: chunk.index, plaintext: Data(chunk.plaintext.utf8))
            XCTAssertEqual(HexEncoding.hex(from: sealed), chunk.sealedHex, "chunk \(chunk.index)")
        }
    }

    func testConformanceVectorReceiverOpensChunks() throws {
        let session = try acceptVectorSession()

        XCTAssertEqual(HexEncoding.hex(from: session.sessionKeyData), sessionKeyHex)
        for chunk in vectorChunks {
            let plaintext = try session.openChunk(index: chunk.index, sealed: hex(chunk.sealedHex))
            XCTAssertEqual(String(decoding: plaintext, as: UTF8.self), chunk.plaintext, "chunk \(chunk.index)")
        }
    }

    func testSenderAndReceiverDeriveSameKeyForRandomEphemeral() throws {
        let (ephemeralPublicKey, senderSession) = try TransferSession.initiate(
            senderSecretKey: hex(senderStaticSecretHex),
            receiverPublicKey: hex(receiverStaticPublicHex),
            context: context
        )
        let receiverSession = try TransferSession.accept(
            receiverSecretKey: hex(receiverStaticSecretHex),
            senderPublicKey: hex(senderStaticPublicHex),
            ephemeralPublicKey: ephemeralPublicKey,
            context: context
        )

        XCTAssertEqual(senderSession.sessionKeyData, receiverSession.sessionKeyData)

        let sealed = try senderSession.sealChunk(index: 3, plaintext: Data("chunk payload bytes".utf8))
        XCTAssertEqual(try receiverSession.openChunk(index: 3, sealed: sealed), Data("chunk payload bytes".utf8))
    }

    func testTamperedCiphertextFailsAuthentication() throws {
        let (_, session) = try initiateVectorSession()
        var sealed = try session.sealChunk(index: 0, plaintext: Data("payload".utf8))
        sealed[sealed.count - 1] ^= 0xFF

        XCTAssertThrowsError(try acceptVectorSession().openChunk(index: 0, sealed: sealed)) { error in
            XCTAssertEqual(error as? TransferSessionError, .chunkAuthenticationFailed)
        }
    }

    func testChunkReplayedAtDifferentIndexRejected() throws {
        let (_, session) = try initiateVectorSession()
        let sealed = try session.sealChunk(index: 1, plaintext: Data("payload".utf8))

        XCTAssertThrowsError(try acceptVectorSession().openChunk(index: 2, sealed: sealed)) { error in
            XCTAssertEqual(error as? TransferSessionError, .invalidSealedChunk)
        }
    }

    func testImpostorSenderCannotAuthenticate() throws {
        let impostorSecret = Data(repeating: 0x33, count: 32)
        let (ephemeralPublicKey, impostorSession) = try TransferSession.initiate(
            senderSecretKey: impostorSecret,
            receiverPublicKey: hex(receiverStaticPublicHex),
            context: context
        )

        // The receiver trusts the paired sender's public key, not the impostor's.
        let receiverSession = try TransferSession.accept(
            receiverSecretKey: hex(receiverStaticSecretHex),
            senderPublicKey: hex(senderStaticPublicHex),
            ephemeralPublicKey: ephemeralPublicKey,
            context: context
        )

        let sealed = try impostorSession.sealChunk(index: 0, plaintext: Data("payload".utf8))
        XCTAssertThrowsError(try receiverSession.openChunk(index: 0, sealed: sealed)) { error in
            XCTAssertEqual(error as? TransferSessionError, .chunkAuthenticationFailed)
        }
    }

    func testLowOrderPeerPublicKeyRejected() throws {
        XCTAssertThrowsError(
            try TransferSession.initiate(
                senderSecretKey: hex(senderStaticSecretHex),
                receiverPublicKey: Data(repeating: 0, count: 32),
                context: context
            )
        ) { error in
            XCTAssertEqual(error as? TransferSessionError, .invalidPeerKey)
        }
    }

    func testInvalidKeyLengthRejected() {
        XCTAssertThrowsError(
            try TransferSession.initiate(
                senderSecretKey: Data([1, 2, 3]),
                receiverPublicKey: hex(receiverStaticPublicHex),
                context: context
            )
        ) { error in
            XCTAssertEqual(error as? TransferSessionError, .invalidKeyLength)
        }
    }

    func testEmptyContextRejected() {
        XCTAssertThrowsError(
            try TransferSession.initiate(
                senderSecretKey: hex(senderStaticSecretHex),
                receiverPublicKey: hex(receiverStaticPublicHex),
                context: TransferSessionContext(senderDeviceId: " ", receiverDeviceId: receiverDeviceId, transferId: transferId)
            )
        ) { error in
            XCTAssertEqual(error as? TransferSessionError, .invalidContext)
        }
    }

    func testDifferentTransferIdsProduceDifferentKeys() throws {
        let otherContext = TransferSessionContext(senderDeviceId: senderDeviceId, receiverDeviceId: receiverDeviceId, transferId: "tx-0002")
        let (_, sessionA) = try initiateVectorSession()
        let (_, sessionB) = try TransferSession.initiate(
            senderSecretKey: hex(senderStaticSecretHex),
            receiverPublicKey: hex(receiverStaticPublicHex),
            context: otherContext,
            ephemeralSecretKey: hex(ephemeralSecretHex)
        )

        XCTAssertNotEqual(sessionA.sessionKeyData, sessionB.sessionKeyData)
    }

    func testDerSPKIRoundTripsRawKey() throws {
        let raw = hex(senderStaticPublicHex)
        let spki = try X25519KeyCodec.base64SPKI(fromRawKey: raw)

        XCTAssertTrue(spki.hasPrefix("MCowBQYDK2VuAyEA"))
        XCTAssertEqual(try X25519KeyCodec.rawKey(fromBase64SPKI: spki), raw)
        XCTAssertTrue(X25519KeyCodec.isBase64SPKI(spki))
        XCTAssertFalse(X25519KeyCodec.isBase64SPKI("legacy-opaque-key"))
        XCTAssertFalse(X25519KeyCodec.isBase64SPKI(raw.base64EncodedString()))
    }

    func testDeviceIdentityPublishesSPKIPublicKeyAndStableSessionSecret() throws {
        let keychain = InMemoryKeychainStore()
        let service = DeviceIdentityService(keychain: keychain)

        let identity = try service.getOrCreate(deviceName: "iPhone")
        let secret = try service.sessionSecretKey()

        XCTAssertTrue(X25519KeyCodec.isBase64SPKI(identity.publicKey))
        XCTAssertEqual(secret.count, 32)
        XCTAssertEqual(try service.sessionSecretKey(), secret)

        // The published public key must be the one derived from the session secret.
        let (_, session) = try TransferSession.initiate(
            senderSecretKey: hex(senderStaticSecretHex),
            receiverPublicKey: try X25519KeyCodec.rawKey(fromBase64SPKI: identity.publicKey),
            context: context
        )
        XCTAssertEqual(session.sessionKeyData.count, 32)
    }
}

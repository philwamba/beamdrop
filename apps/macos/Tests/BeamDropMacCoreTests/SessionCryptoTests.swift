import CryptoKit
import XCTest
@testable import BeamDropMacCore

final class SessionCryptoTests: XCTestCase {
    private enum Vector {
        static let senderDeviceId = "device-sender-01"
        static let receiverDeviceId = "device-receiver-02"
        static let transferId = "tx-0001"
        static let senderStaticSecret = Data(hexEncoded: String(repeating: "11", count: 32))!
        static let senderStaticPublic = Data(hexEncoded: "7b4e909bbe7ffe44c465a220037d608ee35897d31ef972f07f74892cb0f73f13")!
        static let receiverStaticSecret = Data(hexEncoded: String(repeating: "22", count: 32))!
        static let receiverStaticPublic = Data(hexEncoded: "0faa684ed28867b97f4a6a2dee5df8ce974e76b7018e3f22a1c4cf2678570f20")!
        static let ephemeralSecret = Data(hexEncoded: String(repeating: "44", count: 32))!
        static let ephemeralPublicHex = "ff2ee45601ec1b67310c7790404585ae697331eee1c1f8cf2419731c1fff3e6b"
        static let sessionKeyHex = "fb67bd5e5472aec109bb4ef123ecf106782f76dd6ccef2c7b72db1b0bf8c8ecc"
        static let chunks: [(index: Int64, plaintext: String, sealedHex: String)] = [
            (0, "BeamDrop chunk zero", "010000000000000000000000bbd2cd42ded08e24e8054fe22fd1aa439131de0b8f93e520c9b6fa149fc76716eebfe7"),
            (1, "BeamDrop chunk one", "010000000000000000000001572cefa90bc480e6e52513f8f029e6d6c42f7ca3377656d04ea0e349d9f175534a3c"),
            (2, "", "010000000000000000000002bb027ed44e2d74dad6563267b8acb77f")
        ]
    }

    private func makeSenderSession() throws -> SessionCrypto {
        try SessionCrypto.initiate(
            senderStaticSecret: Vector.senderStaticSecret,
            receiverStaticPublic: Vector.receiverStaticPublic,
            senderDeviceId: Vector.senderDeviceId,
            receiverDeviceId: Vector.receiverDeviceId,
            transferId: Vector.transferId,
            ephemeralSecret: Vector.ephemeralSecret
        )
    }

    private func makeReceiverSession() throws -> SessionCrypto {
        try SessionCrypto.accept(
            receiverStaticSecret: Vector.receiverStaticSecret,
            senderStaticPublic: Vector.senderStaticPublic,
            ephemeralPublic: Data(hexEncoded: Vector.ephemeralPublicHex)!,
            senderDeviceId: Vector.senderDeviceId,
            receiverDeviceId: Vector.receiverDeviceId,
            transferId: Vector.transferId
        )
    }

    private func sessionKeyHex(_ session: SessionCrypto) -> String {
        session.sessionKey.withUnsafeBytes { Data($0) }.hexEncodedString
    }

    func testSessionKeyDerivationMatchesConformanceVector() throws {
        let sender = try makeSenderSession()
        XCTAssertEqual(sender.ephemeralPublicKey.hexEncodedString, Vector.ephemeralPublicHex)
        XCTAssertEqual(sessionKeyHex(sender), Vector.sessionKeyHex)

        let receiver = try makeReceiverSession()
        XCTAssertEqual(sessionKeyHex(receiver), Vector.sessionKeyHex)
    }

    func testSealChunkMatchesConformanceVector() throws {
        let sender = try makeSenderSession()
        for chunk in Vector.chunks {
            let sealed = try sender.sealChunk(Data(chunk.plaintext.utf8), index: chunk.index)
            XCTAssertEqual(sealed.hexEncodedString, chunk.sealedHex, "chunk \(chunk.index)")
        }
    }

    func testOpenChunkMatchesConformanceVector() throws {
        let receiver = try makeReceiverSession()
        for chunk in Vector.chunks {
            let plaintext = try receiver.openChunk(Data(hexEncoded: chunk.sealedHex)!, index: chunk.index)
            XCTAssertEqual(String(decoding: plaintext, as: UTF8.self), chunk.plaintext, "chunk \(chunk.index)")
        }
    }

    func testTamperedOrReindexedChunkFailsAuthentication() throws {
        let receiver = try makeReceiverSession()
        var tampered = Data(hexEncoded: Vector.chunks[0].sealedHex)!
        tampered[tampered.count - 1] ^= 0x01
        XCTAssertThrowsError(try receiver.openChunk(tampered, index: 0))
        XCTAssertThrowsError(try receiver.openChunk(Data(hexEncoded: Vector.chunks[0].sealedHex)!, index: 1))
    }

    func testInitiateAndAcceptAgreeWithFreshEphemeralKey() throws {
        let sender = try SessionCrypto.initiate(
            senderStaticSecret: Vector.senderStaticSecret,
            receiverStaticPublic: Vector.receiverStaticPublic,
            senderDeviceId: Vector.senderDeviceId,
            receiverDeviceId: Vector.receiverDeviceId,
            transferId: "tx-roundtrip"
        )
        let receiver = try SessionCrypto.accept(
            receiverStaticSecret: Vector.receiverStaticSecret,
            senderStaticPublic: Vector.senderStaticPublic,
            ephemeralPublic: sender.ephemeralPublicKey,
            senderDeviceId: Vector.senderDeviceId,
            receiverDeviceId: Vector.receiverDeviceId,
            transferId: "tx-roundtrip"
        )
        let payload = Data("round trip payload".utf8)
        let opened = try receiver.openChunk(try sender.sealChunk(payload, index: 7), index: 7)
        XCTAssertEqual(opened, payload)
    }

    func testAllZeroPeerPublicKeyRejected() {
        XCTAssertThrowsError(try SessionCrypto.initiate(
            senderStaticSecret: Vector.senderStaticSecret,
            receiverStaticPublic: Data(count: 32),
            senderDeviceId: Vector.senderDeviceId,
            receiverDeviceId: Vector.receiverDeviceId,
            transferId: Vector.transferId,
            ephemeralSecret: Vector.ephemeralSecret
        ))
        XCTAssertThrowsError(try SessionCrypto.accept(
            receiverStaticSecret: Vector.receiverStaticSecret,
            senderStaticPublic: Vector.senderStaticPublic,
            ephemeralPublic: Data(count: 32),
            senderDeviceId: Vector.senderDeviceId,
            receiverDeviceId: Vector.receiverDeviceId,
            transferId: Vector.transferId
        ))
    }

    func testX25519PublicKeyCodecRoundTrip() throws {
        let spki = "MCowBQYDK2VuAyEAtqzFJY2dveH2WrN9q9NqbcMTFq0QnV8DScjQ7kSy3xY="
        let raw = try X25519PublicKeyCodec.rawKey(spkiBase64: spki)
        XCTAssertEqual(raw.count, 32)
        XCTAssertEqual(try X25519PublicKeyCodec.spkiBase64(rawKey: raw), spki)

        let receiverSPKI = try X25519PublicKeyCodec.spkiBase64(rawKey: Vector.receiverStaticPublic)
        XCTAssertTrue(receiverSPKI.hasPrefix("MCowBQYDK2VuAyEA"))
        XCTAssertEqual(try X25519PublicKeyCodec.rawKey(spkiBase64: receiverSPKI), Vector.receiverStaticPublic)

        XCTAssertThrowsError(try X25519PublicKeyCodec.rawKey(spkiBase64: "bm90LWEta2V5"))
        XCTAssertThrowsError(try X25519PublicKeyCodec.spkiBase64(rawKey: Data(count: 31)))
    }
}

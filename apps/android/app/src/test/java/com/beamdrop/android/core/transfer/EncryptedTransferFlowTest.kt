package com.beamdrop.android.core.transfer

import com.beamdrop.android.core.crypto.SessionCrypto
import com.beamdrop.android.core.crypto.SessionTransferEncryption
import com.beamdrop.android.core.pairing.DevicePlatform
import com.beamdrop.android.core.pairing.EndpointHint
import com.beamdrop.android.core.pairing.TrustState
import com.beamdrop.android.core.pairing.TrustedPeer
import com.beamdrop.android.core.storage.InMemoryTrustedPeerStore
import com.beamdrop.android.core.storage.TrustedPeerRepository
import org.json.JSONObject
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.io.OutputStream
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset

class EncryptedTransferFlowTest {

    @Test
    fun encryptedSendIncludesCamelCaseEncryptionBlockInEnvelope() {
        val transport = CapturingTransport()
        val sender = senderManager(transport)

        val record = sender.sendText(receiverTransferPeer(), "top secret note")

        assertEquals(TransferStatus.Completed, record.status)
        val envelope = JSONObject(transport.envelopeJson!!)
        val encryption = envelope.getJSONObject("encryption")
        assertEquals(SESSION_ENCRYPTION_SCHEME_V1, encryption.getString("scheme"))
        assertTrue(encryption.getString("ephemeralPublicKey").matches(Regex("^[a-f0-9]{64}$")))
    }

    @Test
    fun encryptedPayloadDoesNotContainPlaintextOnTheWire() {
        val transport = CapturingTransport()
        val sender = senderManager(transport)
        val plaintext = "clipboard payload that must not appear in cleartext"

        sender.sendClipboardText(receiverTransferPeer(), plaintext)

        val wireBytes = transport.payload.toByteArray()
        assertEquals(
            plaintext.length + Int.SIZE_BYTES + SEALED_CHUNK_OVERHEAD_BYTES,
            wireBytes.size,
        )
        assertFalse(String(wireBytes, Charsets.ISO_8859_1).contains(plaintext))
    }

    @Test
    fun encryptedFileTransferRoundTripsBetweenSenderAndReceiver() {
        val payload = "BeamDrop encrypted end-to-end payload".toByteArray(Charsets.UTF_8)
        val (record, targetFactory) = roundTrip(payload)

        assertEquals(TransferStatus.Completed, record.status)
        assertTrue(targetFactory.lastTarget!!.committed)
        assertArrayEquals(payload, targetFactory.lastTarget!!.bytes())
    }

    @Test
    fun encryptedEmptyPayloadRoundTrips() {
        val (record, targetFactory) = roundTrip(ByteArray(0))

        assertEquals(TransferStatus.Completed, record.status)
        assertTrue(targetFactory.lastTarget!!.committed)
        assertEquals(0, targetFactory.lastTarget!!.bytes().size)
    }

    @Test
    fun sealedChunkStreamsRoundTripMultiChunkPayloads() {
        val senderSession = SessionCrypto.initiate(
            senderStaticSecretKey = SENDER_SECRET_KEY,
            receiverStaticPublicKey = SessionCrypto.publicKeyForSecretKey(RECEIVER_SECRET_KEY),
            senderDeviceId = SENDER_DEVICE_ID,
            receiverDeviceId = RECEIVER_DEVICE_ID,
            transferId = "tx-multichunk",
        )
        val receiverSession = SessionCrypto.accept(
            receiverStaticSecretKey = RECEIVER_SECRET_KEY,
            senderStaticPublicKey = SessionCrypto.publicKeyForSecretKey(SENDER_SECRET_KEY),
            ephemeralPublicKey = senderSession.ephemeralPublicKey,
            senderDeviceId = SENDER_DEVICE_ID,
            receiverDeviceId = RECEIVER_DEVICE_ID,
            transferId = "tx-multichunk",
        )
        val payload = ByteArray(1_000) { (it % 251).toByte() }
        val chunkSizeBytes = 64

        val wire = ByteArrayOutputStream()
        SealedChunkOutputStream(wire, senderSession, chunkSizeBytes).use { it.write(payload) }
        val expectedChunks = ChunkCalculator.totalChunks(payload.size.toLong(), chunkSizeBytes.toLong()).toInt()
        assertEquals(
            payload.size + expectedChunks * (Int.SIZE_BYTES + SEALED_CHUNK_OVERHEAD_BYTES),
            wire.size(),
        )

        val opened = SealedChunkInputStream(ByteArrayInputStream(wire.toByteArray()), receiverSession, chunkSizeBytes)
            .readBytes()
        assertArrayEquals(payload, opened)
    }

    @Test
    fun tamperedCiphertextFailsTheTransfer() {
        val payload = "authenticated payload".toByteArray(Charsets.UTF_8)
        val transport = CapturingTransport()
        senderManager(transport).sendFile(
            peer = receiverTransferPeer(),
            fileName = "secret.bin",
            mimeType = "application/octet-stream",
            source = ByteSource(payload),
        )
        val wire = transport.payload.toByteArray()
        wire[Int.SIZE_BYTES + 12 + 2] = (wire[Int.SIZE_BYTES + 12 + 2].toInt() xor 0x01).toByte()

        val targetFactory = InMemoryReceiveTargetFactory()
        val record = receiverManager(targetFactory).receiveFile(
            request = incomingRequest(transport),
            input = ByteArrayInputStream(wire),
        )

        assertEquals(TransferStatus.Failed, record.status)
        assertTrue(record.errorMessage!!.contains("failed authentication"))
        assertFalse(targetFactory.lastTarget!!.committed)
    }

    @Test
    fun encryptedTransferWithoutConfiguredSessionEncryptionFails() {
        val payload = "payload".toByteArray(Charsets.UTF_8)
        val transport = CapturingTransport()
        senderManager(transport).sendFile(
            peer = receiverTransferPeer(),
            fileName = "secret.bin",
            mimeType = "application/octet-stream",
            source = ByteSource(payload),
        )

        val record = receiverManager(InMemoryReceiveTargetFactory(), encryptionPolicy = null).receiveFile(
            request = incomingRequest(transport),
            input = ByteArrayInputStream(transport.payload.toByteArray()),
        )

        assertEquals(TransferStatus.Failed, record.status)
        assertTrue(record.errorMessage!!.contains("session encryption is not configured"))
    }

    @Test
    fun legacyPlaintextEnvelopeIsStillReceivedAndMarkedLegacy() {
        val payload = "legacy plaintext payload".toByteArray(Charsets.UTF_8)
        val legacyLog = mutableListOf<String>()
        val targetFactory = InMemoryReceiveTargetFactory()
        val receiver = receiverManager(targetFactory, logger = legacyLog::add)

        val record = receiver.receiveFile(
            request = IncomingTransferRequest(
                metadata = TransferMetadata(
                    transferId = "tx-legacy",
                    type = AndroidTransferType.FILE,
                    senderDeviceId = SENDER_DEVICE_ID,
                    senderPublicKey = SENDER_PUBLIC_KEY,
                    receiverDeviceId = RECEIVER_DEVICE_ID,
                    fileName = "legacy.txt",
                    mimeType = "text/plain",
                    sizeBytes = payload.size.toLong(),
                    sha256 = Sha256Verifier.hashHex(ByteArrayInputStream(payload)),
                    createdAtEpochMillis = fixedClock.millis(),
                ),
                sender = senderTransferPeer(),
            ),
            input = ByteArrayInputStream(payload),
        )

        assertEquals(TransferStatus.Completed, record.status)
        assertArrayEquals(payload, targetFactory.lastTarget!!.bytes())
        assertTrue(legacyLog.single().contains("Legacy plaintext transfer"))
    }

    @Test
    fun senderFallsBackToLegacyPlaintextForNonX25519PeerKey() {
        val transport = CapturingTransport()
        val sender = senderManager(transport, peerPublicKey = "legacy-opaque-key")
        val plaintext = "visible legacy payload"

        val record = sender.sendText(receiverTransferPeer(publicKey = "legacy-opaque-key"), plaintext)

        assertEquals(TransferStatus.Completed, record.status)
        assertNull(JSONObject(transport.envelopeJson!!).optJSONObject("encryption"))
        assertArrayEquals(plaintext.toByteArray(Charsets.UTF_8), transport.payload.toByteArray())
    }

    @Test
    fun envelopeCodecRoundTripsEncryptionBlock() {
        val metadata = TransferMetadata(
            transferId = "tx-enc",
            type = AndroidTransferType.FILE,
            senderDeviceId = SENDER_DEVICE_ID,
            senderPublicKey = SENDER_PUBLIC_KEY,
            receiverDeviceId = RECEIVER_DEVICE_ID,
            fileName = "demo.txt",
            mimeType = "text/plain",
            sizeBytes = 8,
            sha256 = "f".repeat(64),
            createdAtEpochMillis = fixedClock.millis(),
            encryption = TransferEncryption(SESSION_ENCRYPTION_SCHEME_V1, "ab".repeat(32)),
        )

        val decoded = TransferEnvelopeCodec.decode(TransferEnvelopeCodec.encode(metadata))

        assertEquals(metadata.encryption, decoded.encryption)
    }

    @Test
    fun envelopeCodecRejectsUnknownEncryptionScheme() {
        val raw = encodedEnvelopeWithEncryption(scheme = "BEAMDROP_SESSION_V2", ephemeralPublicKey = "ab".repeat(32))

        assertThrows(IllegalArgumentException::class.java) {
            TransferEnvelopeCodec.decode(raw)
        }
    }

    @Test
    fun envelopeCodecRejectsMalformedEphemeralPublicKey() {
        val raw = encodedEnvelopeWithEncryption(scheme = SESSION_ENCRYPTION_SCHEME_V1, ephemeralPublicKey = "zz".repeat(32))

        assertThrows(IllegalArgumentException::class.java) {
            TransferEnvelopeCodec.decode(raw)
        }
    }

    @Test
    fun envelopeCodecDecodesLegacyEnvelopeWithoutEncryptionBlock() {
        val metadata = TransferMetadata(
            transferId = "tx-legacy",
            type = AndroidTransferType.FILE,
            senderDeviceId = SENDER_DEVICE_ID,
            senderPublicKey = SENDER_PUBLIC_KEY,
            receiverDeviceId = RECEIVER_DEVICE_ID,
            fileName = "demo.txt",
            mimeType = "text/plain",
            sizeBytes = 8,
            sha256 = "f".repeat(64),
            createdAtEpochMillis = fixedClock.millis(),
        )

        val decoded = TransferEnvelopeCodec.decode(TransferEnvelopeCodec.encode(metadata))

        assertNull(decoded.encryption)
    }

    private fun roundTrip(payload: ByteArray): Pair<TransferHistoryRecord, InMemoryReceiveTargetFactory> {
        val transport = CapturingTransport()
        val sent = senderManager(transport).sendFile(
            peer = receiverTransferPeer(),
            fileName = "secret.bin",
            mimeType = "application/octet-stream",
            source = ByteSource(payload),
        )
        assertEquals(TransferStatus.Completed, sent.status)
        assertNotNull(JSONObject(transport.envelopeJson!!).optJSONObject("encryption"))

        val targetFactory = InMemoryReceiveTargetFactory()
        val record = receiverManager(targetFactory).receiveFile(
            request = incomingRequest(transport),
            input = ByteArrayInputStream(transport.payload.toByteArray()),
        )
        return record to targetFactory
    }

    /** Builds the incoming request the way TcpIncomingTransferServer does from the wire envelope. */
    private fun incomingRequest(transport: CapturingTransport): IncomingTransferRequest {
        val metadata = TransferEnvelopeCodec.decode(transport.envelopeJson!!)
        return IncomingTransferRequest(
            metadata = metadata,
            sender = senderTransferPeer(publicKey = metadata.senderPublicKey),
        )
    }

    private fun senderManager(
        transport: TransferTransport,
        peerPublicKey: String = RECEIVER_PUBLIC_KEY,
    ): TransferManager = TransferManager(
        trustPolicy = PeerTrustPolicy(trustedRepository(RECEIVER_DEVICE_ID, peerPublicKey)),
        transport = transport,
        receiveTargetFactory = InMemoryReceiveTargetFactory(),
        historyStore = InMemoryTransferHistoryStore(),
        approvalPrompt = RejectingReceiveApprovalPrompt,
        localDeviceId = SENDER_DEVICE_ID,
        localPublicKey = SENDER_PUBLIC_KEY,
        encryptionPolicy = SessionTransferEncryption(SENDER_SECRET_KEY),
        clock = fixedClock,
    )

    private fun receiverManager(
        targetFactory: InMemoryReceiveTargetFactory,
        encryptionPolicy: TransferEncryptionPolicy? = SessionTransferEncryption(RECEIVER_SECRET_KEY),
        logger: (String) -> Unit = {},
    ): TransferManager = TransferManager(
        trustPolicy = PeerTrustPolicy(trustedRepository(SENDER_DEVICE_ID, SENDER_PUBLIC_KEY)),
        transport = CapturingTransport(),
        receiveTargetFactory = targetFactory,
        historyStore = InMemoryTransferHistoryStore(),
        approvalPrompt = object : ReceiveApprovalPrompt {
            override fun decide(request: IncomingTransferRequest): ReceiveDecision = ReceiveDecision.Accept
        },
        localDeviceId = RECEIVER_DEVICE_ID,
        localPublicKey = RECEIVER_PUBLIC_KEY,
        encryptionPolicy = encryptionPolicy,
        logger = logger,
        clock = fixedClock,
    )

    private fun trustedRepository(deviceId: String, publicKey: String): TrustedPeerRepository =
        TrustedPeerRepository(
            InMemoryTrustedPeerStore(
                listOf(
                    TrustedPeer(
                        deviceId = deviceId,
                        displayName = "Peer $deviceId",
                        platform = DevicePlatform.MacOS,
                        publicKey = publicKey,
                        fingerprint = "7C9A 2E41 8F03",
                        trustState = TrustState.Trusted,
                        endpoint = EndpointHint(host = "192.168.1.42", port = 49320),
                        trustedAtEpochMillis = fixedClock.millis(),
                        revokedAtEpochMillis = null,
                        lastSeenEpochMillis = fixedClock.millis(),
                    ),
                ),
            ),
            fixedClock,
        )

    private fun receiverTransferPeer(publicKey: String = RECEIVER_PUBLIC_KEY): TransferPeer = TransferPeer(
        deviceId = RECEIVER_DEVICE_ID,
        displayName = "Receiver",
        platform = DevicePlatform.MacOS,
        publicKey = publicKey,
        endpointHost = "192.168.1.42",
        endpointPort = 49320,
    )

    private fun senderTransferPeer(publicKey: String = SENDER_PUBLIC_KEY): TransferPeer = TransferPeer(
        deviceId = SENDER_DEVICE_ID,
        displayName = "Sender",
        platform = DevicePlatform.Android,
        publicKey = publicKey,
        autoAcceptTransfers = true,
    )

    private fun encodedEnvelopeWithEncryption(scheme: String, ephemeralPublicKey: String): String {
        val metadata = TransferMetadata(
            transferId = "tx-enc",
            type = AndroidTransferType.FILE,
            senderDeviceId = SENDER_DEVICE_ID,
            senderPublicKey = SENDER_PUBLIC_KEY,
            receiverDeviceId = RECEIVER_DEVICE_ID,
            fileName = "demo.txt",
            mimeType = "text/plain",
            sizeBytes = 8,
            sha256 = "f".repeat(64),
            createdAtEpochMillis = fixedClock.millis(),
        )
        return JSONObject(TransferEnvelopeCodec.encode(metadata))
            .put(
                "encryption",
                JSONObject()
                    .put("scheme", scheme)
                    .put("ephemeralPublicKey", ephemeralPublicKey),
            )
            .toString()
    }

    private class ByteSource(private val bytes: ByteArray) : TransferByteSource {
        override val sizeBytes: Long = bytes.size.toLong()
        override fun openStream(): InputStream = ByteArrayInputStream(bytes)
    }

    private class CapturingTransport : TransferTransport {
        var envelopeJson: String? = null
        val payload = ByteArrayOutputStream()

        override fun openSendStream(peer: TransferPeer, metadata: TransferMetadata): OutputStream {
            envelopeJson = TransferEnvelopeCodec.encode(metadata)
            return payload
        }
    }

    private class InMemoryReceiveTargetFactory : ReceiveTargetFactory {
        var lastTarget: InMemoryReceiveTarget? = null

        override fun create(metadata: TransferMetadata): ReceiveTarget =
            InMemoryReceiveTarget().also { lastTarget = it }
    }

    private class InMemoryReceiveTarget : ReceiveTarget {
        private val output = ByteArrayOutputStream()
        var committed = false

        fun bytes(): ByteArray = output.toByteArray()

        override fun openOutputStream(): OutputStream = output
        override fun openInputStreamForVerification(): InputStream = ByteArrayInputStream(output.toByteArray())
        override fun commitVerified() {
            committed = true
        }

        override fun discard() {
            committed = false
        }
    }

    private companion object {
        const val SENDER_DEVICE_ID = "bd-android-sender"
        const val RECEIVER_DEVICE_ID = "bd-macos-receiver"

        val SENDER_SECRET_KEY = ByteArray(32) { 0x07 }
        val RECEIVER_SECRET_KEY = ByteArray(32) { 0x2A }

        val SENDER_PUBLIC_KEY: String =
            SessionCrypto.spkiBase64FromRawKey(SessionCrypto.publicKeyForSecretKey(SENDER_SECRET_KEY))
        val RECEIVER_PUBLIC_KEY: String =
            SessionCrypto.spkiBase64FromRawKey(SessionCrypto.publicKeyForSecretKey(RECEIVER_SECRET_KEY))

        val fixedClock: Clock = Clock.fixed(Instant.parse("2026-07-06T14:20:00Z"), ZoneOffset.UTC)
    }
}

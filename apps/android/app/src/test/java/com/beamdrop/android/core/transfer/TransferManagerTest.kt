package com.beamdrop.android.core.transfer

import com.beamdrop.android.core.pairing.DevicePlatform
import com.beamdrop.android.core.pairing.TrustState
import com.beamdrop.android.core.pairing.TrustedPeer
import com.beamdrop.android.core.storage.InMemoryTrustedPeerStore
import com.beamdrop.android.core.storage.TrustedPeerRepository
import org.junit.Assert.assertEquals
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

class TransferManagerTest {
    @Test
    fun chunkCalculationForSmallFilesUsesSingleChunk() {
        val plan = ChunkCalculator.plan(fileSizeBytes = 1024)

        assertEquals(1, plan.totalChunks)
        assertEquals(0, plan.chunks.single().offset)
        assertEquals(1024, plan.chunks.single().sizeBytes)
    }

    @Test
    fun chunkCalculationForLargeFilesUsesFourMbChunks() {
        val plan = ChunkCalculator.plan(fileSizeBytes = (DEFAULT_CHUNK_SIZE_BYTES * 2) + 10)

        assertEquals(3, plan.totalChunks)
        assertEquals(DEFAULT_CHUNK_SIZE_BYTES, plan.chunks[0].sizeBytes)
        assertEquals(DEFAULT_CHUNK_SIZE_BYTES, plan.chunks[1].sizeBytes)
        assertEquals(10, plan.chunks[2].sizeBytes)
    }

    @Test
    fun finalHashVerificationPassesForMatchingPayload() {
        val payload = "BeamDrop".toByteArray()
        val expected = Sha256Verifier.hashHex(ByteArrayInputStream(payload))

        assertTrue(Sha256Verifier.verify(ByteArrayInputStream(payload), expected))
    }

    @Test
    fun transferEnvelopeUsesSharedAndroidWindowsWireShape() {
        val metadata = metadata(
            type = AndroidTransferType.FILE,
            fileName = "demo.txt",
            sizeBytes = 8,
            sha256 = "f".repeat(64),
        ).copy(
            senderDeviceId = "bd-android-sender",
            senderPublicKey = "android-public-key",
            receiverDeviceId = "bd-windows-receiver",
        )

        val decoded = TransferEnvelopeCodec.decode(TransferEnvelopeCodec.encode(metadata))

        assertEquals("bd-android-sender", decoded.senderDeviceId)
        assertEquals("android-public-key", decoded.senderPublicKey)
        assertEquals("bd-windows-receiver", decoded.receiverDeviceId)
        assertEquals(AndroidTransferType.FILE, decoded.type)
        assertEquals(DEFAULT_CHUNK_SIZE_BYTES, decoded.chunkSizeBytes)
    }

    @Test
    fun tamperedTransferEnvelopeIsRejected() {
        val metadata = metadata(
            type = AndroidTransferType.FILE,
            fileName = "demo.txt",
            sizeBytes = 8,
            sha256 = "f".repeat(64),
        )
        val tampered = TransferEnvelopeCodec.encode(metadata).replace("\"totalChunks\":1", "\"totalChunks\":99")

        assertThrows(IllegalArgumentException::class.java) {
            TransferEnvelopeCodec.decode(tampered)
        }
    }

    @Test
    fun transferEnvelopeWithoutFinalHashIsRejected() {
        val raw = """
            {
              "protocolVersion": "1.0",
              "transferId": "tx-missing-hash",
              "transferType": "TEXT",
              "senderDeviceId": "bd-android-sender",
              "senderPublicKey": "public-key",
              "receiverDeviceId": "bd-windows-receiver",
              "createdAt": "2026-07-06T14:27:18Z",
              "payloadMetadata": {
                "fileName": "Text",
                "mimeType": "text/plain",
                "sizeBytes": 5,
                "chunkSize": 4194304,
                "totalChunks": 1
              }
            }
        """.trimIndent()

        assertThrows(IllegalArgumentException::class.java) {
            TransferEnvelopeCodec.decode(raw)
        }
    }

    @Test
    fun progressCalculationReturnsPercent() {
        assertEquals(42, ProgressCalculator.percent(bytesTransferred = 42, totalBytes = 100))
        assertEquals(100, ProgressCalculator.percent(bytesTransferred = 125, totalBytes = 100))
    }

    @Test
    fun trustedPeerTextSendCompletesAndPersistsHistory() {
        val manager = testManager(trustedPeer(TrustState.Trusted))

        val record = manager.sendText(trustedTransferPeer(), "hello")

        assertEquals(TransferStatus.Completed, record.status)
        assertEquals(TransferDirection.Sent, record.direction)
        assertEquals(AndroidTransferType.TEXT, record.type)
    }

    @Test
    fun receiveFileVerifiesHashBeforeMarkingComplete() {
        val payload = "received file".toByteArray()
        val sha256 = Sha256Verifier.hashHex(ByteArrayInputStream(payload))
        val manager = testManager(trustedPeer(TrustState.Trusted))

        val record = manager.receiveFile(
            request = IncomingTransferRequest(
                metadata = metadata(
                    type = AndroidTransferType.FILE,
                    fileName = "notes.txt",
                    sizeBytes = payload.size.toLong(),
                    sha256 = sha256,
                ),
                sender = trustedTransferPeer(autoAccept = true),
            ),
            input = ByteArrayInputStream(payload),
        )

        assertEquals(TransferStatus.Completed, record.status)
        assertEquals(TransferDirection.Received, record.direction)
    }

    @Test
    fun corruptedReceiveIsNotMarkedComplete() {
        val manager = testManager(trustedPeer(TrustState.Trusted))

        val record = manager.receiveFile(
            request = IncomingTransferRequest(
                metadata = metadata(
                    type = AndroidTransferType.FILE,
                    fileName = "notes.txt",
                    sizeBytes = 11,
                    sha256 = "0000000000000000000000000000000000000000000000000000000000000000",
                ),
                sender = trustedTransferPeer(autoAccept = true),
            ),
            input = ByteArrayInputStream("hello world".toByteArray()),
        )

        assertEquals(TransferStatus.Corrupted, record.status)
    }

    @Test
    fun receiveWithoutHashVerificationCannotComplete() {
        val manager = testManager(trustedPeer(TrustState.Trusted))

        val record = manager.receiveFile(
            request = IncomingTransferRequest(
                metadata = metadata(
                    type = AndroidTransferType.FILE,
                    fileName = "notes.txt",
                    sizeBytes = 11,
                    sha256 = null,
                ),
                sender = trustedTransferPeer(autoAccept = true),
            ),
            input = ByteArrayInputStream("hello world".toByteArray()),
        )

        assertEquals(TransferStatus.Corrupted, record.status)
    }

    @Test
    fun unknownPeerIsRejected() {
        val manager = testManager()

        val record = manager.sendText(trustedTransferPeer(), "hello")

        assertEquals(TransferStatus.Rejected, record.status)
        assertTrue(record.errorMessage!!.contains("Unknown peer rejected"))
    }

    @Test
    fun revokedPeerIsRejected() {
        val manager = testManager(trustedPeer(TrustState.Revoked))

        val record = manager.sendText(trustedTransferPeer(), "hello")

        assertEquals(TransferStatus.Rejected, record.status)
        assertTrue(record.errorMessage!!.contains("Revoked peer rejected"))
    }

    @Test
    fun rejectedReceiveRequestPersistsRejectedStatus() {
        val manager = testManager(trustedPeer(TrustState.Trusted), approvalPrompt = RejectingReceiveApprovalPrompt)

        val record = manager.receiveText(
            request = IncomingTransferRequest(
                metadata = metadata(type = AndroidTransferType.TEXT, fileName = "Text", sizeBytes = 5),
                sender = trustedTransferPeer(autoAccept = false),
            ),
            payload = "hello",
        )

        assertEquals(TransferStatus.Rejected, record.status)
    }

    private fun testManager(
        peer: TrustedPeer? = null,
        approvalPrompt: ReceiveApprovalPrompt = object : ReceiveApprovalPrompt {
            override fun decide(request: IncomingTransferRequest): ReceiveDecision = ReceiveDecision.Accept
        },
    ): TransferManager {
        val peers = if (peer == null) emptyList() else listOf(peer)
        val trustedRepository = TrustedPeerRepository(InMemoryTrustedPeerStore(peers), fixedClock)
        return TransferManager(
            trustPolicy = PeerTrustPolicy(trustedRepository),
            transport = RecordingTransport(),
            receiveTargetFactory = InMemoryReceiveTargetFactory(),
            historyStore = InMemoryTransferHistoryStore(),
            approvalPrompt = approvalPrompt,
            clock = fixedClock,
        )
    }

    private fun trustedPeer(state: TrustState): TrustedPeer = TrustedPeer(
        deviceId = PEER_ID,
        displayName = "Will's MacBook Pro",
        platform = DevicePlatform.MacOS,
        publicKey = PEER_PUBLIC_KEY,
        fingerprint = "7C9A 2E41 8F03",
        trustState = state,
        endpoint = com.beamdrop.android.core.pairing.EndpointHint(host = "192.168.1.42", port = 49320),
        trustedAtEpochMillis = fixedClock.millis(),
        revokedAtEpochMillis = if (state == TrustState.Revoked) fixedClock.millis() else null,
        lastSeenEpochMillis = fixedClock.millis(),
    )

    private fun trustedTransferPeer(autoAccept: Boolean = false): TransferPeer = TransferPeer(
        deviceId = PEER_ID,
        displayName = "Will's MacBook Pro",
        platform = DevicePlatform.MacOS,
        publicKey = PEER_PUBLIC_KEY,
        endpointHost = "192.168.1.42",
        endpointPort = 49320,
        autoAcceptTransfers = autoAccept,
    )

    private fun metadata(
        type: AndroidTransferType,
        fileName: String,
        sizeBytes: Long,
        sha256: String? = null,
    ) = TransferMetadata(
        transferId = "tx-test",
        type = type,
        fileName = fileName,
        mimeType = "text/plain",
        sizeBytes = sizeBytes,
        sha256 = sha256,
        createdAtEpochMillis = fixedClock.millis(),
    )

    private class RecordingTransport : TransferTransport {
        override fun openSendStream(peer: TransferPeer, metadata: TransferMetadata): OutputStream =
            ByteArrayOutputStream()
    }

    private class InMemoryReceiveTargetFactory : ReceiveTargetFactory {
        override fun create(metadata: TransferMetadata): ReceiveTarget = InMemoryReceiveTarget()
    }

    private class InMemoryReceiveTarget : ReceiveTarget {
        private val output = ByteArrayOutputStream()
        var committed = false

        override fun openOutputStream(): OutputStream = output
        override fun openInputStreamForVerification(): InputStream = ByteArrayInputStream(output.toByteArray())
        override fun commitVerified() {
            committed = true
        }

        override fun discard() {
            output.reset()
            committed = false
        }
    }

    private companion object {
        const val PEER_ID = "bd-macos-01J2M8Q8RXE4KZ9G7V1N0Q4F2A"
        const val PEER_PUBLIC_KEY = "public-key"
        val fixedClock: Clock = Clock.fixed(Instant.parse("2026-07-06T14:20:00Z"), ZoneOffset.UTC)
    }
}

package com.beamdrop.android.core.transfer

import java.io.ByteArrayInputStream
import java.io.InputStream
import java.time.Clock
import java.util.UUID
import kotlin.math.max

class TransferManager(
    private val trustPolicy: PeerTrustPolicy,
    private val transport: TransferTransport,
    private val receiveTargetFactory: ReceiveTargetFactory,
    private val historyStore: TransferHistoryStore,
    private val approvalPrompt: ReceiveApprovalPrompt,
    private val localDeviceId: String = "android-local-device",
    private val localPublicKey: String = "",
    private val encryptionPolicy: TransferEncryptionPolicy? = null,
    private val logger: (String) -> Unit = {},
    private val clock: Clock = Clock.systemUTC(),
) {
    @Volatile
    private var cancelledTransferId: String? = null

    fun sendText(peer: TransferPeer, text: String): TransferHistoryRecord =
        sendBytes(
            peer = peer,
            type = AndroidTransferType.TEXT,
            fileName = "Text",
            mimeType = "text/plain",
            bytes = text.toByteArray(Charsets.UTF_8),
        )

    fun sendUrl(peer: TransferPeer, url: String): TransferHistoryRecord =
        sendBytes(
            peer = peer,
            type = AndroidTransferType.URL,
            fileName = "Link",
            mimeType = "text/uri-list",
            bytes = url.toByteArray(Charsets.UTF_8),
        )

    fun sendClipboardText(peer: TransferPeer, clipboardText: String): TransferHistoryRecord =
        sendBytes(
            peer = peer,
            type = AndroidTransferType.CLIPBOARD_TEXT,
            fileName = "Clipboard text",
            mimeType = "text/plain",
            bytes = clipboardText.toByteArray(Charsets.UTF_8),
        )

    fun sendFile(
        peer: TransferPeer,
        fileName: String,
        mimeType: String,
        source: TransferByteSource,
        onProgress: (TransferProgress) -> Unit = {},
    ): TransferHistoryRecord {
        val metadata = TransferMetadata(
            transferId = newTransferId(),
            type = AndroidTransferType.FILE,
            senderDeviceId = localDeviceId,
            senderPublicKey = localPublicKey,
            receiverDeviceId = peer.deviceId,
            fileName = fileName,
            mimeType = mimeType,
            sizeBytes = source.sizeBytes,
            createdAtEpochMillis = clock.millis(),
            sha256 = Sha256Verifier.hashHex(source.openStream()),
        )
        return sendStream(peer, metadata, source, onProgress)
    }

    fun receiveText(
        request: IncomingTransferRequest,
        payload: String,
    ): TransferHistoryRecord =
        receiveStream(request, ByteArrayInputStream(payload.toByteArray(Charsets.UTF_8)))

    fun receiveFile(
        request: IncomingTransferRequest,
        input: InputStream,
    ): TransferHistoryRecord =
        receiveStream(request, input)

    fun cancelTransfer(transferId: String) {
        cancelledTransferId = transferId
    }

    private fun sendBytes(
        peer: TransferPeer,
        type: AndroidTransferType,
        fileName: String,
        mimeType: String,
        bytes: ByteArray,
    ): TransferHistoryRecord {
        val metadata = TransferMetadata(
            transferId = newTransferId(),
            type = type,
            senderDeviceId = localDeviceId,
            senderPublicKey = localPublicKey,
            receiverDeviceId = peer.deviceId,
            fileName = fileName,
            mimeType = mimeType,
            sizeBytes = bytes.size.toLong(),
            createdAtEpochMillis = clock.millis(),
            sha256 = Sha256Verifier.hashHex(ByteArrayInputStream(bytes)),
        )
        return sendStream(peer, metadata, ByteArrayTransferSource(bytes), onProgress = {})
    }

    private fun sendStream(
        peer: TransferPeer,
        metadata: TransferMetadata,
        source: TransferByteSource,
        onProgress: (TransferProgress) -> Unit,
    ): TransferHistoryRecord {
        val trust = trustPolicy.requireTrusted(peer)
        if (trust is TransferTrustResult.Rejected) {
            return persistFailure(metadata, peer, TransferDirection.Sent, trust.error, TransferStatus.Rejected)
        }
        if (peer.endpointHost.isNullOrBlank() || peer.endpointPort == null) {
            return persistFailure(metadata, peer, TransferDirection.Sent, TransferError.MissingEndpoint(peer.deviceId), TransferStatus.Failed)
        }

        val startedAt = clock.millis()
        return runCatching {
            val session = encryptionPolicy?.outgoingSession(metadata, peer.publicKey)
            if (session == null) {
                logger("Legacy plaintext transfer ${metadata.transferId} to ${peer.deviceId}: session encryption unavailable.")
            }
            val sendMetadata = if (session == null) metadata else metadata.copy(encryption = session.encryption)
            source.openStream().use { input ->
                val rawOutput = transport.openSendStream(peer, sendMetadata)
                val payloadOutput = if (session == null) {
                    rawOutput
                } else {
                    SealedChunkOutputStream(rawOutput, session.cipher, metadata.chunkSizeBytes.toInt())
                }
                ProgressOutputStream(payloadOutput) { sent ->
                    onProgress(progress(metadata, peer, TransferDirection.Sent, TransferStatus.Transferring, sent, startedAt))
                }.use { output ->
                    copyChunked(metadata.transferId, input, output, metadata.chunkSizeBytes)
                }
            }
            persistComplete(metadata, peer, TransferDirection.Sent)
        }.getOrElse { error ->
            val status = if (error is TransferError.TransferCancelled) TransferStatus.Cancelled else TransferStatus.Failed
            persistFailure(metadata, peer, TransferDirection.Sent, error, status)
        }
    }

    private fun receiveStream(
        request: IncomingTransferRequest,
        input: InputStream,
    ): TransferHistoryRecord {
        val metadata = request.metadata
        val sender = request.sender
        val trust = trustPolicy.requireTrusted(sender)
        if (trust is TransferTrustResult.Rejected) {
            return persistFailure(metadata, sender, TransferDirection.Received, trust.error, TransferStatus.Rejected)
        }
        if (!sender.autoAcceptTransfers && approvalPrompt.decide(request) == ReceiveDecision.Reject) {
            return persistFailure(metadata, sender, TransferDirection.Received, TransferError.ReceiverRejected(metadata.transferId), TransferStatus.Rejected)
        }

        val target = receiveTargetFactory.create(metadata)
        return runCatching {
            val payloadInput = openPayloadInput(metadata, sender, input)
            target.openOutputStream().use { output ->
                val received = copyChunked(metadata.transferId, payloadInput, output, metadata.chunkSizeBytes)
                if (received != metadata.sizeBytes) throw TransferError.IncompleteTransfer(metadata.transferId)
            }
            val expectedHash = metadata.sha256 ?: throw TransferError.HashMismatch(metadata.transferId)
            val verified = target.openInputStreamForVerification().use { Sha256Verifier.verify(it, expectedHash) }
            if (!verified) throw TransferError.HashMismatch(metadata.transferId)
            target.commitVerified()
            persistComplete(metadata, sender, TransferDirection.Received)
        }.getOrElse { error ->
            target.discard()
            val status = when (error) {
                is TransferError.HashMismatch -> TransferStatus.Corrupted
                is TransferError.IncompleteTransfer -> TransferStatus.Incomplete
                is TransferError.TransferCancelled -> TransferStatus.Cancelled
                else -> TransferStatus.Failed
            }
            persistFailure(metadata, sender, TransferDirection.Received, error, status)
        }
    }

    private fun openPayloadInput(
        metadata: TransferMetadata,
        sender: TransferPeer,
        input: InputStream,
    ): InputStream {
        val encryption = metadata.encryption
        if (encryption == null) {
            logger("Legacy plaintext transfer ${metadata.transferId} from ${sender.deviceId}: no encryption block in envelope.")
            return input
        }
        val policy = encryptionPolicy
            ?: throw TransferError.TransportFailed("Encrypted transfer ${metadata.transferId} received but session encryption is not configured.")
        // The trust gate above guarantees sender.publicKey equals the trusted peer's stored key.
        val cipher = policy.incomingSession(metadata, sender.publicKey)
        return SealedChunkInputStream(input, cipher, metadata.chunkSizeBytes.toInt())
    }

    private fun copyChunked(
        transferId: String,
        input: InputStream,
        output: java.io.OutputStream,
        chunkSizeBytes: Long,
    ): Long {
        require(chunkSizeBytes in 1..Int.MAX_VALUE) { "chunkSizeBytes must fit an Android byte buffer" }
        val buffer = ByteArray(chunkSizeBytes.toInt())
        var total = 0L
        while (true) {
            if (cancelledTransferId == transferId) throw TransferError.TransferCancelled(transferId)
            val read = input.read(buffer)
            if (read == -1) break
            if (read > 0) {
                output.write(buffer, 0, read)
                total += read
            }
        }
        return total
    }

    private fun progress(
        metadata: TransferMetadata,
        peer: TransferPeer,
        direction: TransferDirection,
        status: TransferStatus,
        bytesTransferred: Long,
        startedAtEpochMillis: Long,
    ): TransferProgress {
        val elapsedSeconds = max(1L, (clock.millis() - startedAtEpochMillis) / 1000L)
        return TransferProgress(
            metadata = metadata,
            peer = peer,
            direction = direction,
            status = status,
            bytesTransferred = bytesTransferred,
            speedBytesPerSecond = bytesTransferred / elapsedSeconds,
        )
    }

    private fun persistComplete(
        metadata: TransferMetadata,
        peer: TransferPeer,
        direction: TransferDirection,
    ): TransferHistoryRecord {
        val record = historyRecord(metadata, peer, direction, TransferStatus.Completed, completedAt = clock.millis())
        historyStore.upsert(record)
        return record
    }

    private fun persistFailure(
        metadata: TransferMetadata,
        peer: TransferPeer,
        direction: TransferDirection,
        error: Throwable,
        status: TransferStatus,
    ): TransferHistoryRecord {
        val record = historyRecord(metadata, peer, direction, status, completedAt = clock.millis())
        historyStore.upsert(record)
        val failed = record.copy(errorMessage = error.message ?: "Transfer failed")
        historyStore.upsert(failed)
        return failed
    }

    private fun historyRecord(
        metadata: TransferMetadata,
        peer: TransferPeer,
        direction: TransferDirection,
        status: TransferStatus,
        completedAt: Long?,
        errorMessage: String? = null,
    ) = TransferHistoryRecord(
        transferId = metadata.transferId,
        direction = direction,
        peerDeviceId = peer.deviceId,
        peerDisplayName = peer.displayName,
        type = metadata.type,
        fileName = metadata.fileName,
        sizeBytes = metadata.sizeBytes,
        status = status,
        createdAtEpochMillis = metadata.createdAtEpochMillis,
        completedAtEpochMillis = completedAt,
        sha256 = metadata.sha256,
        errorMessage = errorMessage,
    )

    private fun newTransferId(): String = "tx-${UUID.randomUUID()}"
}

private class ByteArrayTransferSource(
    private val bytes: ByteArray,
) : TransferByteSource {
    override val sizeBytes: Long = bytes.size.toLong()
    override fun openStream(): InputStream = ByteArrayInputStream(bytes)
}

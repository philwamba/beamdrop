package com.beamdrop.android.core.transfer

import com.beamdrop.android.core.pairing.DevicePlatform

const val DEFAULT_CHUNK_SIZE_BYTES: Long = 4L * 1024L * 1024L
const val DEFAULT_TRANSFER_PORT: Int = 49320

enum class AndroidTransferType {
    TEXT,
    URL,
    FILE,
    CLIPBOARD_TEXT,
}

enum class TransferDirection {
    Sent,
    Received,
}

enum class TransferStatus {
    Queued,
    WaitingForApproval,
    Transferring,
    Verifying,
    Completed,
    Failed,
    Cancelled,
    Rejected,
    Corrupted,
    Incomplete,
}

data class TransferPeer(
    val deviceId: String,
    val displayName: String,
    val platform: DevicePlatform,
    val publicKey: String,
    val endpointHost: String? = null,
    val endpointPort: Int? = null,
    val autoAcceptTransfers: Boolean = false,
)

data class TransferMetadata(
    val transferId: String,
    val type: AndroidTransferType,
    val senderDeviceId: String = "",
    val senderPublicKey: String = "",
    val receiverDeviceId: String = "",
    val fileName: String,
    val mimeType: String,
    val sizeBytes: Long,
    val chunkSizeBytes: Long = DEFAULT_CHUNK_SIZE_BYTES,
    val totalChunks: Long = ChunkCalculator.totalChunks(sizeBytes, chunkSizeBytes),
    val sha256: String? = null,
    val createdAtEpochMillis: Long,
)

data class TransferProgress(
    val metadata: TransferMetadata,
    val peer: TransferPeer,
    val direction: TransferDirection,
    val status: TransferStatus,
    val bytesTransferred: Long,
    val speedBytesPerSecond: Long,
    val errorMessage: String? = null,
) {
    val percent: Int
        get() = ProgressCalculator.percent(bytesTransferred, metadata.sizeBytes)
}

data class TransferHistoryRecord(
    val transferId: String,
    val direction: TransferDirection,
    val peerDeviceId: String,
    val peerDisplayName: String,
    val type: AndroidTransferType,
    val fileName: String,
    val sizeBytes: Long,
    val status: TransferStatus,
    val createdAtEpochMillis: Long,
    val completedAtEpochMillis: Long?,
    val sha256: String?,
    val errorMessage: String? = null,
)

data class IncomingTransferRequest(
    val metadata: TransferMetadata,
    val sender: TransferPeer,
)

sealed class ReceiveDecision {
    data object Accept : ReceiveDecision()
    data object Reject : ReceiveDecision()
}

interface ReceiveApprovalPrompt {
    fun decide(request: IncomingTransferRequest): ReceiveDecision
}

object RejectingReceiveApprovalPrompt : ReceiveApprovalPrompt {
    override fun decide(request: IncomingTransferRequest): ReceiveDecision = ReceiveDecision.Reject
}

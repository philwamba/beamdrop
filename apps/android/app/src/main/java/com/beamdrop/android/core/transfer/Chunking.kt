package com.beamdrop.android.core.transfer

data class ChunkMetadata(
    val index: Long,
    val offset: Long,
    val sizeBytes: Long,
)

data class ChunkPlan(
    val fileSizeBytes: Long,
    val chunkSizeBytes: Long,
    val chunks: List<ChunkMetadata>,
) {
    val totalChunks: Long = chunks.size.toLong()
}

object ChunkCalculator {
    fun totalChunks(fileSizeBytes: Long, chunkSizeBytes: Long = DEFAULT_CHUNK_SIZE_BYTES): Long {
        require(fileSizeBytes >= 0) { "fileSizeBytes must be non-negative" }
        require(chunkSizeBytes > 0) { "chunkSizeBytes must be positive" }
        if (fileSizeBytes == 0L) return 1
        return ((fileSizeBytes - 1) / chunkSizeBytes) + 1
    }

    fun plan(fileSizeBytes: Long, chunkSizeBytes: Long = DEFAULT_CHUNK_SIZE_BYTES): ChunkPlan {
        val totalChunks = totalChunks(fileSizeBytes, chunkSizeBytes)
        val chunks = (0 until totalChunks).map { index ->
            val offset = index * chunkSizeBytes
            val remaining = (fileSizeBytes - offset).coerceAtLeast(0)
            ChunkMetadata(
                index = index,
                offset = offset,
                sizeBytes = if (fileSizeBytes == 0L) 0 else remaining.coerceAtMost(chunkSizeBytes),
            )
        }
        return ChunkPlan(fileSizeBytes, chunkSizeBytes, chunks)
    }
}

data class ResumePlan(
    val transferId: String,
    val totalChunks: Long,
    val completedChunks: Set<Long>,
    val missingChunks: List<Long>,
)

object ResumePlanner {
    fun plan(transferId: String, totalChunks: Long, completedChunks: Set<Long>): ResumePlan {
        require(transferId.isNotBlank()) { "transferId must not be blank" }
        require(totalChunks > 0) { "totalChunks must be positive" }
        completedChunks.forEach { index ->
            require(index in 0 until totalChunks) { "completed chunk $index is out of range" }
        }
        return ResumePlan(
            transferId = transferId,
            totalChunks = totalChunks,
            completedChunks = completedChunks,
            missingChunks = (0 until totalChunks).filterNot { it in completedChunks },
        )
    }
}

object ProgressCalculator {
    fun percent(bytesTransferred: Long, totalBytes: Long): Int {
        require(bytesTransferred >= 0) { "bytesTransferred must be non-negative" }
        require(totalBytes >= 0) { "totalBytes must be non-negative" }
        if (totalBytes == 0L) return 100
        return ((bytesTransferred.coerceAtMost(totalBytes) * 100) / totalBytes).toInt()
    }
}


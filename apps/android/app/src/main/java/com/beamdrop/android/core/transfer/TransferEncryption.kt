package com.beamdrop.android.core.transfer

import java.io.InputStream
import java.io.OutputStream
import java.nio.ByteBuffer

const val SESSION_ENCRYPTION_SCHEME_V1 = "BEAMDROP_SESSION_V1"

/** nonce(12) + Poly1305 tag(16) added around each plaintext chunk. */
const val SEALED_CHUNK_OVERHEAD_BYTES = 12 + 16

/** Optional `encryption` block carried in the transfer envelope. */
data class TransferEncryption(
    val scheme: String,
    val ephemeralPublicKey: String,
)

/** Seals and opens individual payload chunks of one transfer session. */
interface TransferSessionCipher {
    fun sealChunk(chunkIndex: Long, plaintext: ByteArray): ByteArray
    fun openChunk(chunkIndex: Long, sealed: ByteArray): ByteArray
}

data class OutgoingTransferSession(
    val encryption: TransferEncryption,
    val cipher: TransferSessionCipher,
)

/** Negotiates per-transfer session ciphers from the local static key and a peer public key. */
interface TransferEncryptionPolicy {
    /** Returns null when the peer cannot use session encryption (legacy plaintext transfer). */
    fun outgoingSession(metadata: TransferMetadata, receiverPublicKey: String): OutgoingTransferSession?

    /** Derives the receive-side session; [senderPublicKey] must be the trusted peer's stored key. */
    fun incomingSession(metadata: TransferMetadata, senderPublicKey: String): TransferSessionCipher
}

/**
 * Writes the payload as sealed chunk frames: bigEndian32(sealedLength) || sealed bytes,
 * where sealed = nonce(12) || ciphertext || tag(16). Chunks are sealed at the envelope
 * chunk size; closing the stream seals any buffered remainder (or a single empty chunk
 * for zero-byte payloads, matching ChunkCalculator.totalChunks).
 */
class SealedChunkOutputStream(
    private val delegate: OutputStream,
    private val cipher: TransferSessionCipher,
    chunkSizeBytes: Int,
) : OutputStream() {
    private val buffer = ByteArray(chunkSizeBytes)
    private var buffered = 0
    private var chunkIndex = 0L
    private var closed = false

    override fun write(b: Int) {
        write(byteArrayOf(b.toByte()), 0, 1)
    }

    override fun write(b: ByteArray, off: Int, len: Int) {
        check(!closed) { "Sealed chunk stream is closed." }
        var offset = off
        var remaining = len
        while (remaining > 0) {
            val toCopy = minOf(remaining, buffer.size - buffered)
            System.arraycopy(b, offset, buffer, buffered, toCopy)
            buffered += toCopy
            offset += toCopy
            remaining -= toCopy
            if (buffered == buffer.size) sealBufferedChunk()
        }
    }

    override fun flush() = delegate.flush()

    override fun close() {
        if (closed) return
        closed = true
        if (buffered > 0 || chunkIndex == 0L) sealBufferedChunk()
        delegate.flush()
        delegate.close()
    }

    private fun sealBufferedChunk() {
        val sealed = cipher.sealChunk(chunkIndex, buffer.copyOf(buffered))
        delegate.write(ByteBuffer.allocate(Int.SIZE_BYTES).putInt(sealed.size).array())
        delegate.write(sealed)
        chunkIndex++
        buffered = 0
    }
}

/**
 * Reads sealed chunk frames produced by [SealedChunkOutputStream] and serves the opened
 * plaintext. Any authentication failure surfaces as an exception and fails the transfer.
 */
class SealedChunkInputStream(
    private val delegate: InputStream,
    private val cipher: TransferSessionCipher,
    chunkSizeBytes: Int,
) : InputStream() {
    private val maxSealedBytes = chunkSizeBytes + SEALED_CHUNK_OVERHEAD_BYTES
    private var plaintext = ByteArray(0)
    private var position = 0
    private var chunkIndex = 0L
    private var exhausted = false

    override fun read(): Int {
        val single = ByteArray(1)
        return if (read(single, 0, 1) == -1) -1 else single[0].toInt() and 0xFF
    }

    override fun read(b: ByteArray, off: Int, len: Int): Int {
        if (len == 0) return 0
        while (position >= plaintext.size) {
            if (!openNextChunk()) return -1
        }
        val available = minOf(len, plaintext.size - position)
        System.arraycopy(plaintext, position, b, off, available)
        position += available
        return available
    }

    override fun close() = delegate.close()

    private fun openNextChunk(): Boolean {
        if (exhausted) return false
        val first = delegate.read()
        if (first == -1) {
            exhausted = true
            return false
        }
        val header = ByteArray(Int.SIZE_BYTES)
        header[0] = first.toByte()
        readFully(header, 1, header.size - 1)
        val sealedSize = ByteBuffer.wrap(header).int
        if (sealedSize < SEALED_CHUNK_OVERHEAD_BYTES || sealedSize > maxSealedBytes) {
            throw TransferError.TransportFailed("Sealed chunk $chunkIndex has an invalid frame size: $sealedSize")
        }
        val sealed = ByteArray(sealedSize)
        readFully(sealed, 0, sealedSize)
        plaintext = cipher.openChunk(chunkIndex, sealed)
        chunkIndex++
        position = 0
        return true
    }

    private fun readFully(target: ByteArray, offset: Int, length: Int) {
        var read = 0
        while (read < length) {
            val count = delegate.read(target, offset + read, length - read)
            if (count == -1) {
                throw TransferError.TransportFailed("Connection closed inside sealed chunk $chunkIndex.")
            }
            read += count
        }
    }
}

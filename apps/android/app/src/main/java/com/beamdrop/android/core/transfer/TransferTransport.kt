package com.beamdrop.android.core.transfer

import java.io.InputStream
import java.io.OutputStream

interface TransferByteSource {
    val sizeBytes: Long
    fun openStream(): InputStream
}

interface ReceiveTarget {
    fun openOutputStream(): OutputStream
    fun openInputStreamForVerification(): InputStream
    fun commitVerified()
    fun discard()
}

interface ReceiveTargetFactory {
    fun create(metadata: TransferMetadata): ReceiveTarget
}

interface TransferTransport {
    fun openSendStream(peer: TransferPeer, metadata: TransferMetadata): OutputStream
}

class ProgressOutputStream(
    private val delegate: OutputStream,
    private val onBytesWritten: (Long) -> Unit,
) : OutputStream() {
    private var written = 0L

    override fun write(b: Int) {
        delegate.write(b)
        written++
        onBytesWritten(written)
    }

    override fun write(b: ByteArray, off: Int, len: Int) {
        delegate.write(b, off, len)
        written += len
        onBytesWritten(written)
    }

    override fun flush() = delegate.flush()
    override fun close() = delegate.close()
}

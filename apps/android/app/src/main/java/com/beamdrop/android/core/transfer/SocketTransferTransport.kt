package com.beamdrop.android.core.transfer

import java.io.FilterOutputStream
import java.io.OutputStream
import java.net.InetSocketAddress
import java.net.Socket

class SocketTransferTransport(
    private val connectTimeoutMillis: Int = 10_000,
) : TransferTransport {
    override fun openSendStream(peer: TransferPeer, metadata: TransferMetadata): OutputStream {
        val socket = openSocket(peer)
        val output = socket.getOutputStream()
        output.write(TransferEnvelopeCodec.encode(metadata).toByteArray(Charsets.UTF_8))
        output.write('\n'.code)
        output.flush()
        return object : FilterOutputStream(output) {
            override fun close() {
                runCatching { super.close() }
                socket.close()
            }
        }
    }

    private fun openSocket(peer: TransferPeer): Socket {
        val host = peer.endpointHost ?: throw TransferError.MissingEndpoint(peer.deviceId)
        val port = peer.endpointPort ?: throw TransferError.MissingEndpoint(peer.deviceId)
        return Socket().apply {
            connect(InetSocketAddress(host, port), connectTimeoutMillis)
        }
    }

}

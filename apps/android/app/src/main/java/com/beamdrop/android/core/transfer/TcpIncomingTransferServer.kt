package com.beamdrop.android.core.transfer

import com.beamdrop.android.core.storage.TrustedPeerRepository
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.net.ServerSocket

class TcpIncomingTransferServer(
    private val transferManager: TransferManager,
    private val trustedPeerRepository: TrustedPeerRepository,
    private val port: Int,
) {
    @Volatile
    private var serverSocket: ServerSocket? = null

    fun runOnce() {
        ServerSocket(port).use { server ->
            serverSocket = server
            val socket = server.accept()
            socket.use {
                val input = it.getInputStream().buffered()
                val envelopeJson = input.readEnvelopeLine()
                val metadata = TransferEnvelopeCodec.decode(envelopeJson)
                val trustedPeer = trustedPeerRepository.getPeer(metadata.senderDeviceId)
                val sender = TransferPeer(
                    deviceId = metadata.senderDeviceId,
                    displayName = trustedPeer?.displayName ?: metadata.senderDeviceId,
                    platform = trustedPeer?.platform ?: com.beamdrop.android.core.pairing.DevicePlatform.Unknown,
                    publicKey = metadata.senderPublicKey,
                    autoAcceptTransfers = trustedPeer?.let { peer -> peer.trustState == com.beamdrop.android.core.pairing.TrustState.Trusted } == true,
                )
                val request = IncomingTransferRequest(metadata, sender)
                val isTextPayload = metadata.type == AndroidTransferType.TEXT || metadata.type == AndroidTransferType.URL || metadata.type == AndroidTransferType.CLIPBOARD_TEXT
                if (isTextPayload && metadata.encryption == null) {
                    val bytes = ByteArrayOutputStream()
                    input.copyTo(bytes)
                    transferManager.receiveText(request, bytes.toString(Charsets.UTF_8.name()))
                } else {
                    transferManager.receiveFile(request, input)
                }
            }
        }
    }

    fun stop() {
        serverSocket?.close()
        serverSocket = null
    }

    private fun java.io.InputStream.readEnvelopeLine(): String {
        val bytes = ByteArrayOutputStream()
        while (true) {
            val next = read()
            if (next == -1) throw IllegalStateException("Connection closed before transfer envelope.")
            if (next == '\n'.code) break
            bytes.write(next)
            if (bytes.size() > 64 * 1024) throw IllegalStateException("Transfer envelope is too large.")
        }
        return bytes.toString(Charsets.UTF_8.name())
    }
}

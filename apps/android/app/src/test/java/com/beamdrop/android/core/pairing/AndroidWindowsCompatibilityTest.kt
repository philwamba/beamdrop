package com.beamdrop.android.core.pairing

import com.beamdrop.android.core.transfer.AndroidTransferType
import com.beamdrop.android.core.transfer.DEFAULT_CHUNK_SIZE_BYTES
import com.beamdrop.android.core.transfer.TransferEnvelopeCodec
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test

class AndroidWindowsCompatibilityTest {
    @Test
    fun androidDecodesWindowsPairingQrPayload() {
        val raw = """
            {
              "type": "beamdrop_pairing",
              "protocolVersion": "1.0",
              "serviceName": "_beamdrop._tcp",
              "pairingSessionId": "pair-windows",
              "deviceId": "bd-windows-01",
              "deviceName": "Windows Workstation",
              "platform": "windows",
              "publicKey": "windows-public-key",
              "fingerprint": "AA BB CC DD EE FF",
              "endpoint": {
                "host": "192.0.2.44",
                "port": 49320,
                "route": "local"
              },
              "expiresAtEpochMillis": 1783350000000
            }
        """.trimIndent()

        val payload = PairingCodec.decode(raw)

        assertNotNull(payload)
        assertEquals("bd-windows-01", payload!!.deviceId)
        assertEquals("Windows Workstation", payload.displayName)
        assertEquals(DevicePlatform.Windows, payload.platform)
        assertEquals("windows-public-key", payload.publicKey)
        assertEquals("_beamdrop._tcp", payload.serviceName)
        assertEquals(49320, payload.endpoint!!.port)
    }

    @Test
    fun androidDecodesWindowsTransferEnvelope() {
        val raw = """
            {
              "protocolVersion": "1.0",
              "transferId": "tx-windows",
              "transferType": "FILE",
              "senderDeviceId": "bd-windows-01",
              "senderPublicKey": "windows-public-key",
              "receiverDeviceId": "bd-android-01",
              "createdAt": "2026-07-06T14:27:18Z",
              "payloadMetadata": {
                "fileName": "demo.txt",
                "mimeType": "text/plain",
                "sizeBytes": 11,
                "chunkSize": 4194304,
                "totalChunks": 1,
                "sha256": "64ec88ca00b268e5ba1a35678a1b5316d212f4f366b2477232534a8aeca37f3c"
              }
            }
        """.trimIndent()

        val metadata = TransferEnvelopeCodec.decode(raw)

        assertEquals("tx-windows", metadata.transferId)
        assertEquals(AndroidTransferType.FILE, metadata.type)
        assertEquals("bd-windows-01", metadata.senderDeviceId)
        assertEquals("windows-public-key", metadata.senderPublicKey)
        assertEquals("bd-android-01", metadata.receiverDeviceId)
        assertEquals(DEFAULT_CHUNK_SIZE_BYTES, metadata.chunkSizeBytes)
        assertEquals(1L, metadata.totalChunks)
    }
}

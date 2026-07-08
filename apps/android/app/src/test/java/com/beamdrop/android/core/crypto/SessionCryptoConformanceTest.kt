package com.beamdrop.android.core.crypto

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Conformance vectors from protocol/beamdrop-protocol/test-vectors/session-encryption-v1.json.
 * These values are fixed by the cross-platform protocol and must never change.
 */
class SessionCryptoConformanceTest {

    @Test
    fun staticPublicKeysDeriveFromStaticSecrets() {
        assertEquals(SENDER_STATIC_PUBLIC, hex(SessionCrypto.publicKeyForSecretKey(unhex(SENDER_STATIC_SECRET))))
        assertEquals(RECEIVER_STATIC_PUBLIC, hex(SessionCrypto.publicKeyForSecretKey(unhex(RECEIVER_STATIC_SECRET))))
        assertEquals(EPHEMERAL_PUBLIC, hex(SessionCrypto.publicKeyForSecretKey(unhex(EPHEMERAL_SECRET))))
    }

    @Test
    fun initiateDerivesConformantSessionKey() {
        val session = initiatorSession()

        assertEquals(EPHEMERAL_PUBLIC, hex(session.ephemeralPublicKey))
        assertEquals(SESSION_KEY, hex(session.sessionKey))
    }

    @Test
    fun acceptDerivesConformantSessionKey() {
        val session = acceptorSession()

        assertEquals(SESSION_KEY, hex(session.sessionKey))
    }

    @Test
    fun sealedChunksMatchConformanceVectors() {
        val session = initiatorSession()

        CHUNK_VECTORS.forEach { (index, plaintext, sealedHex) ->
            assertEquals(
                "chunk $index",
                sealedHex,
                hex(session.sealChunk(index, plaintext.toByteArray(Charsets.UTF_8))),
            )
        }
    }

    @Test
    fun receiverOpensSealedConformanceChunks() {
        val session = acceptorSession()

        CHUNK_VECTORS.forEach { (index, plaintext, sealedHex) ->
            assertArrayEquals(
                plaintext.toByteArray(Charsets.UTF_8),
                session.openChunk(index, unhex(sealedHex)),
            )
        }
    }

    @Test
    fun tamperedSealedChunkFailsAuthentication() {
        val session = acceptorSession()
        val sealed = unhex(CHUNK_VECTORS.first().third)
        sealed[sealed.size - 1] = (sealed[sealed.size - 1].toInt() xor 0x01).toByte()

        assertThrows(SessionCryptoException::class.java) {
            session.openChunk(0, sealed)
        }
    }

    @Test
    fun chunkOpenedUnderWrongIndexFailsAuthentication() {
        val session = acceptorSession()

        assertThrows(SessionCryptoException::class.java) {
            session.openChunk(1, unhex(CHUNK_VECTORS.first().third))
        }
    }

    @Test
    fun allZeroSharedSecretIsRejected() {
        assertThrows(SessionCryptoException::class.java) {
            SessionCrypto.accept(
                receiverStaticSecretKey = unhex(RECEIVER_STATIC_SECRET),
                senderStaticPublicKey = unhex(SENDER_STATIC_PUBLIC),
                ephemeralPublicKey = ByteArray(32),
                senderDeviceId = SENDER_DEVICE_ID,
                receiverDeviceId = RECEIVER_DEVICE_ID,
                transferId = TRANSFER_ID,
            )
        }
    }

    @Test
    fun spkiHelpersRoundTripRawKeys() {
        val raw = unhex(SENDER_STATIC_PUBLIC)
        val spki = SessionCrypto.spkiBase64FromRawKey(raw)

        assertTrue(spki.startsWith("MCowBQYDK2VuAyEA"))
        assertTrue(SessionCrypto.isX25519SpkiPublicKey(spki))
        assertArrayEquals(raw, SessionCrypto.rawKeyFromSpkiBase64(spki))
    }

    @Test
    fun nonX25519PublicKeysAreRejectedByHelpers() {
        assertFalse(SessionCrypto.isX25519SpkiPublicKey("not-a-key"))
        assertFalse(SessionCrypto.isX25519SpkiPublicKey(""))
        assertThrows(SessionCryptoException::class.java) {
            SessionCrypto.rawKeyFromSpkiBase64("bm90IGEga2V5")
        }
    }

    private fun initiatorSession(): SessionCrypto =
        SessionCrypto.initiate(
            senderStaticSecretKey = unhex(SENDER_STATIC_SECRET),
            receiverStaticPublicKey = unhex(RECEIVER_STATIC_PUBLIC),
            senderDeviceId = SENDER_DEVICE_ID,
            receiverDeviceId = RECEIVER_DEVICE_ID,
            transferId = TRANSFER_ID,
            ephemeralSecretKey = unhex(EPHEMERAL_SECRET),
        )

    private fun acceptorSession(): SessionCrypto =
        SessionCrypto.accept(
            receiverStaticSecretKey = unhex(RECEIVER_STATIC_SECRET),
            senderStaticPublicKey = unhex(SENDER_STATIC_PUBLIC),
            ephemeralPublicKey = unhex(EPHEMERAL_PUBLIC),
            senderDeviceId = SENDER_DEVICE_ID,
            receiverDeviceId = RECEIVER_DEVICE_ID,
            transferId = TRANSFER_ID,
        )

    private fun hex(bytes: ByteArray): String = SessionCrypto.hexEncode(bytes)

    private fun unhex(hex: String): ByteArray = SessionCrypto.hexDecode(hex)

    private companion object {
        const val SENDER_DEVICE_ID = "device-sender-01"
        const val RECEIVER_DEVICE_ID = "device-receiver-02"
        const val TRANSFER_ID = "tx-0001"

        const val SENDER_STATIC_SECRET = "1111111111111111111111111111111111111111111111111111111111111111"
        const val SENDER_STATIC_PUBLIC = "7b4e909bbe7ffe44c465a220037d608ee35897d31ef972f07f74892cb0f73f13"
        const val RECEIVER_STATIC_SECRET = "2222222222222222222222222222222222222222222222222222222222222222"
        const val RECEIVER_STATIC_PUBLIC = "0faa684ed28867b97f4a6a2dee5df8ce974e76b7018e3f22a1c4cf2678570f20"
        const val EPHEMERAL_SECRET = "4444444444444444444444444444444444444444444444444444444444444444"
        const val EPHEMERAL_PUBLIC = "ff2ee45601ec1b67310c7790404585ae697331eee1c1f8cf2419731c1fff3e6b"

        const val SESSION_KEY = "fb67bd5e5472aec109bb4ef123ecf106782f76dd6ccef2c7b72db1b0bf8c8ecc"

        val CHUNK_VECTORS = listOf(
            Triple(
                0L,
                "BeamDrop chunk zero",
                "010000000000000000000000bbd2cd42ded08e24e8054fe22fd1aa439131de0b8f93e520c9b6fa149fc76716eebfe7",
            ),
            Triple(
                1L,
                "BeamDrop chunk one",
                "010000000000000000000001572cefa90bc480e6e52513f8f029e6d6c42f7ca3377656d04ea0e349d9f175534a3c",
            ),
            Triple(
                2L,
                "",
                "010000000000000000000002bb027ed44e2d74dad6563267b8acb77f",
            ),
        )
    }
}

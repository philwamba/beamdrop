package com.beamdrop.android.core.crypto

import com.beamdrop.android.core.transfer.TransferSessionCipher
import org.bouncycastle.crypto.InvalidCipherTextException
import org.bouncycastle.crypto.agreement.X25519Agreement
import org.bouncycastle.crypto.digests.SHA256Digest
import org.bouncycastle.crypto.generators.HKDFBytesGenerator
import org.bouncycastle.crypto.modes.ChaCha20Poly1305
import org.bouncycastle.crypto.params.HKDFParameters
import org.bouncycastle.crypto.params.KeyParameter
import org.bouncycastle.crypto.params.ParametersWithIV
import org.bouncycastle.crypto.params.X25519PrivateKeyParameters
import org.bouncycastle.crypto.params.X25519PublicKeyParameters
import java.nio.ByteBuffer
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.Base64

class SessionCryptoException(message: String, cause: Throwable? = null) : RuntimeException(message, cause)

/**
 * BeamDrop session encryption v1 (`BEAMDROP_SESSION_V1`).
 *
 * A per-transfer session key is derived from an authenticated X25519 exchange:
 * - sender: dh1 = X25519(ephemeralSecret, receiverStaticPublic); dh2 = X25519(senderStaticSecret, receiverStaticPublic)
 * - receiver: dh1 = X25519(receiverStaticSecret, ephemeralPublic); dh2 = X25519(receiverStaticSecret, senderStaticPublic)
 * - salt = SHA256("BeamDropSession-v1" || transferId)
 * - info = senderDeviceId || 0x00 || receiverDeviceId || 0x00 || ephemeralPublic || senderStaticPublic || receiverStaticPublic
 * - sessionKey = HKDF-SHA256(salt, dh1 || dh2, info, 32 bytes)
 *
 * Chunks are sealed with ChaCha20-Poly1305 (RFC 8439) as nonce(12) || ciphertext || tag(16),
 * where nonce = [0x01, 0, 0, 0] || bigEndian64(chunkIndex).
 *
 * Uses the BouncyCastle lightweight API (org.bouncycastle.crypto.*) so the explicit
 * bcprov artifact is used instead of the outdated provider that ships with Android.
 */
class SessionCrypto private constructor(
    internal val sessionKey: ByteArray,
    private val senderDeviceId: String,
    private val receiverDeviceId: String,
    private val transferId: String,
    val ephemeralPublicKey: ByteArray,
) : TransferSessionCipher {

    override fun sealChunk(chunkIndex: Long, plaintext: ByteArray): ByteArray {
        val nonce = chunkNonce(chunkIndex)
        val cipher = ChaCha20Poly1305()
        cipher.init(true, ParametersWithIV(KeyParameter(sessionKey), nonce))
        val aad = chunkAad(chunkIndex)
        cipher.processAADBytes(aad, 0, aad.size)
        val sealed = ByteArray(NONCE_SIZE_BYTES + cipher.getOutputSize(plaintext.size))
        System.arraycopy(nonce, 0, sealed, 0, NONCE_SIZE_BYTES)
        val written = cipher.processBytes(plaintext, 0, plaintext.size, sealed, NONCE_SIZE_BYTES)
        cipher.doFinal(sealed, NONCE_SIZE_BYTES + written)
        return sealed
    }

    override fun openChunk(chunkIndex: Long, sealed: ByteArray): ByteArray {
        if (sealed.size < NONCE_SIZE_BYTES + TAG_SIZE_BYTES) {
            throw SessionCryptoException("Sealed chunk $chunkIndex is truncated.")
        }
        val nonce = sealed.copyOfRange(0, NONCE_SIZE_BYTES)
        if (!MessageDigest.isEqual(nonce, chunkNonce(chunkIndex))) {
            throw SessionCryptoException("Sealed chunk $chunkIndex carries an unexpected nonce.")
        }
        val cipher = ChaCha20Poly1305()
        cipher.init(false, ParametersWithIV(KeyParameter(sessionKey), nonce))
        val aad = chunkAad(chunkIndex)
        cipher.processAADBytes(aad, 0, aad.size)
        val plaintext = ByteArray(cipher.getOutputSize(sealed.size - NONCE_SIZE_BYTES))
        try {
            val written = cipher.processBytes(sealed, NONCE_SIZE_BYTES, sealed.size - NONCE_SIZE_BYTES, plaintext, 0)
            cipher.doFinal(plaintext, written)
        } catch (error: InvalidCipherTextException) {
            throw SessionCryptoException("Sealed chunk $chunkIndex failed authentication.", error)
        }
        return plaintext
    }

    private fun chunkNonce(chunkIndex: Long): ByteArray =
        ByteBuffer.allocate(NONCE_SIZE_BYTES)
            .put(0x01)
            .put(0x00)
            .put(0x00)
            .put(0x00)
            .putLong(chunkIndex)
            .array()

    private fun chunkAad(chunkIndex: Long): ByteArray {
        val sender = senderDeviceId.toByteArray(Charsets.UTF_8)
        val receiver = receiverDeviceId.toByteArray(Charsets.UTF_8)
        val transfer = transferId.toByteArray(Charsets.UTF_8)
        return ByteBuffer.allocate(CHUNK_AAD_LABEL.size + sender.size + receiver.size + transfer.size + 4 + Long.SIZE_BYTES)
            .put(CHUNK_AAD_LABEL).put(0x00)
            .put(sender).put(0x00)
            .put(receiver).put(0x00)
            .put(transfer).put(0x00)
            .putLong(chunkIndex)
            .array()
    }

    companion object {
        const val KEY_SIZE_BYTES = 32
        const val NONCE_SIZE_BYTES = 12
        const val TAG_SIZE_BYTES = 16

        private val SESSION_LABEL = "BeamDropSession-v1".toByteArray(Charsets.UTF_8)
        private val CHUNK_AAD_LABEL = "beamdrop-chunk-v1".toByteArray(Charsets.UTF_8)

        /** DER SubjectPublicKeyInfo header for an X25519 public key (RFC 8410). */
        private val X25519_SPKI_PREFIX = byteArrayOf(
            0x30, 0x2a, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x6e, 0x03, 0x21, 0x00,
        )

        fun initiate(
            senderStaticSecretKey: ByteArray,
            receiverStaticPublicKey: ByteArray,
            senderDeviceId: String,
            receiverDeviceId: String,
            transferId: String,
            ephemeralSecretKey: ByteArray = generateSecretKey(),
        ): SessionCrypto {
            val ephemeralPublicKey = publicKeyForSecretKey(ephemeralSecretKey)
            val senderStaticPublicKey = publicKeyForSecretKey(senderStaticSecretKey)
            val dh1 = x25519(ephemeralSecretKey, receiverStaticPublicKey)
            val dh2 = x25519(senderStaticSecretKey, receiverStaticPublicKey)
            return derive(
                dh1 = dh1,
                dh2 = dh2,
                ephemeralPublicKey = ephemeralPublicKey,
                senderStaticPublicKey = senderStaticPublicKey,
                receiverStaticPublicKey = receiverStaticPublicKey,
                senderDeviceId = senderDeviceId,
                receiverDeviceId = receiverDeviceId,
                transferId = transferId,
            )
        }

        fun accept(
            receiverStaticSecretKey: ByteArray,
            senderStaticPublicKey: ByteArray,
            ephemeralPublicKey: ByteArray,
            senderDeviceId: String,
            receiverDeviceId: String,
            transferId: String,
        ): SessionCrypto {
            val receiverStaticPublicKey = publicKeyForSecretKey(receiverStaticSecretKey)
            val dh1 = x25519(receiverStaticSecretKey, ephemeralPublicKey)
            val dh2 = x25519(receiverStaticSecretKey, senderStaticPublicKey)
            return derive(
                dh1 = dh1,
                dh2 = dh2,
                ephemeralPublicKey = ephemeralPublicKey,
                senderStaticPublicKey = senderStaticPublicKey,
                receiverStaticPublicKey = receiverStaticPublicKey,
                senderDeviceId = senderDeviceId,
                receiverDeviceId = receiverDeviceId,
                transferId = transferId,
            )
        }

        fun generateSecretKey(): ByteArray = X25519PrivateKeyParameters(SecureRandom()).encoded

        fun publicKeyForSecretKey(secretKey: ByteArray): ByteArray {
            require(secretKey.size == KEY_SIZE_BYTES) { "X25519 secret key must be $KEY_SIZE_BYTES bytes." }
            return X25519PrivateKeyParameters(secretKey, 0).generatePublicKey().encoded
        }

        /** Encodes a raw 32-byte X25519 public key as base64 DER SubjectPublicKeyInfo. */
        fun spkiBase64FromRawKey(rawPublicKey: ByteArray): String {
            require(rawPublicKey.size == KEY_SIZE_BYTES) { "X25519 public key must be $KEY_SIZE_BYTES bytes." }
            return Base64.getEncoder().encodeToString(X25519_SPKI_PREFIX + rawPublicKey)
        }

        /** Extracts the raw 32-byte X25519 public key (the last 32 bytes) from a base64 DER SPKI blob. */
        fun rawKeyFromSpkiBase64(publicKey: String): ByteArray {
            val decoded = try {
                Base64.getDecoder().decode(publicKey)
            } catch (error: IllegalArgumentException) {
                throw SessionCryptoException("Public key is not valid base64.", error)
            }
            if (!isX25519Spki(decoded)) {
                throw SessionCryptoException("Public key is not a DER SPKI X25519 key.")
            }
            return decoded.copyOfRange(decoded.size - KEY_SIZE_BYTES, decoded.size)
        }

        fun isX25519SpkiPublicKey(publicKey: String): Boolean {
            val decoded = runCatching { Base64.getDecoder().decode(publicKey) }.getOrNull() ?: return false
            return isX25519Spki(decoded)
        }

        internal fun hexEncode(bytes: ByteArray): String = bytes.joinToString("") { "%02x".format(it) }

        internal fun hexDecode(hex: String): ByteArray {
            require(hex.length % 2 == 0 && hex.matches(Regex("^[0-9a-fA-F]*$"))) { "Invalid hex string." }
            return ByteArray(hex.length / 2) { index ->
                hex.substring(index * 2, index * 2 + 2).toInt(16).toByte()
            }
        }

        private fun isX25519Spki(decoded: ByteArray): Boolean =
            decoded.size == X25519_SPKI_PREFIX.size + KEY_SIZE_BYTES &&
                decoded.copyOfRange(0, X25519_SPKI_PREFIX.size).contentEquals(X25519_SPKI_PREFIX)

        private fun derive(
            dh1: ByteArray,
            dh2: ByteArray,
            ephemeralPublicKey: ByteArray,
            senderStaticPublicKey: ByteArray,
            receiverStaticPublicKey: ByteArray,
            senderDeviceId: String,
            receiverDeviceId: String,
            transferId: String,
        ): SessionCrypto {
            val salt = MessageDigest.getInstance("SHA-256").apply {
                update(SESSION_LABEL)
                update(transferId.toByteArray(Charsets.UTF_8))
            }.digest()
            val ikm = dh1 + dh2
            val info = sessionInfo(
                senderDeviceId = senderDeviceId,
                receiverDeviceId = receiverDeviceId,
                ephemeralPublicKey = ephemeralPublicKey,
                senderStaticPublicKey = senderStaticPublicKey,
                receiverStaticPublicKey = receiverStaticPublicKey,
            )
            val hkdf = HKDFBytesGenerator(SHA256Digest())
            hkdf.init(HKDFParameters(ikm, salt, info))
            val sessionKey = ByteArray(KEY_SIZE_BYTES)
            hkdf.generateBytes(sessionKey, 0, sessionKey.size)
            return SessionCrypto(
                sessionKey = sessionKey,
                senderDeviceId = senderDeviceId,
                receiverDeviceId = receiverDeviceId,
                transferId = transferId,
                ephemeralPublicKey = ephemeralPublicKey,
            )
        }

        private fun sessionInfo(
            senderDeviceId: String,
            receiverDeviceId: String,
            ephemeralPublicKey: ByteArray,
            senderStaticPublicKey: ByteArray,
            receiverStaticPublicKey: ByteArray,
        ): ByteArray {
            val sender = senderDeviceId.toByteArray(Charsets.UTF_8)
            val receiver = receiverDeviceId.toByteArray(Charsets.UTF_8)
            return ByteBuffer.allocate(sender.size + receiver.size + 2 + KEY_SIZE_BYTES * 3)
                .put(sender).put(0x00)
                .put(receiver).put(0x00)
                .put(ephemeralPublicKey)
                .put(senderStaticPublicKey)
                .put(receiverStaticPublicKey)
                .array()
        }

        private fun x25519(secretKey: ByteArray, publicKey: ByteArray): ByteArray {
            require(secretKey.size == KEY_SIZE_BYTES) { "X25519 secret key must be $KEY_SIZE_BYTES bytes." }
            if (publicKey.size != KEY_SIZE_BYTES) {
                throw SessionCryptoException("X25519 public key must be $KEY_SIZE_BYTES bytes.")
            }
            val agreement = X25519Agreement()
            agreement.init(X25519PrivateKeyParameters(secretKey, 0))
            val shared = ByteArray(agreement.agreementSize)
            try {
                agreement.calculateAgreement(X25519PublicKeyParameters(publicKey, 0), shared, 0)
            } catch (error: IllegalStateException) {
                throw SessionCryptoException("X25519 agreement produced a weak shared secret.", error)
            }
            if (shared.all { it == 0.toByte() }) {
                throw SessionCryptoException("X25519 agreement produced an all-zero shared secret.")
            }
            return shared
        }
    }
}

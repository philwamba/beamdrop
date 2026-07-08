package com.beamdrop.android.core.crypto

import com.beamdrop.android.core.transfer.OutgoingTransferSession
import com.beamdrop.android.core.transfer.SESSION_ENCRYPTION_SCHEME_V1
import com.beamdrop.android.core.transfer.TransferEncryption
import com.beamdrop.android.core.transfer.TransferEncryptionPolicy
import com.beamdrop.android.core.transfer.TransferMetadata
import com.beamdrop.android.core.transfer.TransferSessionCipher

/**
 * Derives BEAMDROP_SESSION_V1 transfer sessions from the local static X25519 secret key.
 * Peers whose stored public key is not an X25519 SPKI key fall back to legacy plaintext.
 */
class SessionTransferEncryption(
    private val localStaticSecretKey: ByteArray,
) : TransferEncryptionPolicy {

    override fun outgoingSession(metadata: TransferMetadata, receiverPublicKey: String): OutgoingTransferSession? {
        if (!SessionCrypto.isX25519SpkiPublicKey(receiverPublicKey)) return null
        val session = SessionCrypto.initiate(
            senderStaticSecretKey = localStaticSecretKey,
            receiverStaticPublicKey = SessionCrypto.rawKeyFromSpkiBase64(receiverPublicKey),
            senderDeviceId = metadata.senderDeviceId,
            receiverDeviceId = metadata.receiverDeviceId,
            transferId = metadata.transferId,
        )
        return OutgoingTransferSession(
            encryption = TransferEncryption(
                scheme = SESSION_ENCRYPTION_SCHEME_V1,
                ephemeralPublicKey = SessionCrypto.hexEncode(session.ephemeralPublicKey),
            ),
            cipher = session,
        )
    }

    override fun incomingSession(metadata: TransferMetadata, senderPublicKey: String): TransferSessionCipher {
        val encryption = metadata.encryption
            ?: throw SessionCryptoException("Transfer ${metadata.transferId} has no encryption block.")
        if (encryption.scheme != SESSION_ENCRYPTION_SCHEME_V1) {
            throw SessionCryptoException("Unsupported transfer encryption scheme: ${encryption.scheme}")
        }
        if (!SessionCrypto.isX25519SpkiPublicKey(senderPublicKey)) {
            throw SessionCryptoException("Trusted peer public key for ${metadata.senderDeviceId} is not an X25519 key.")
        }
        return SessionCrypto.accept(
            receiverStaticSecretKey = localStaticSecretKey,
            senderStaticPublicKey = SessionCrypto.rawKeyFromSpkiBase64(senderPublicKey),
            ephemeralPublicKey = SessionCrypto.hexDecode(encryption.ephemeralPublicKey),
            senderDeviceId = metadata.senderDeviceId,
            receiverDeviceId = metadata.receiverDeviceId,
            transferId = metadata.transferId,
        )
    }
}

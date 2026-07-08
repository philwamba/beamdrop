package com.beamdrop.android.core.identity

import android.content.Context
import com.beamdrop.android.core.crypto.SessionCrypto
import com.beamdrop.android.core.pairing.BEAMDROP_PROTOCOL_VERSION
import com.beamdrop.android.core.pairing.DeviceIdentity
import com.beamdrop.android.core.pairing.DevicePlatform
import java.util.Base64
import java.util.UUID

/**
 * Stores the stable device id and the static X25519 identity key pair used for
 * BEAMDROP_SESSION_V1 transfer encryption. The public key is shared with peers
 * during pairing as base64 DER SPKI; the secret key stays in app-private storage
 * because AndroidKeyStore cannot perform X25519 key agreement on all supported
 * API levels (agreement support starts at API 33).
 */
class DeviceIdentityRepository(
    context: Context,
    private val deviceNameRepository: DeviceNameRepository,
) {
    private val preferences = context.getSharedPreferences("device_identity", Context.MODE_PRIVATE)

    fun getOrCreateIdentity(): DeviceIdentity {
        val deviceId = preferences.getString(KEY_DEVICE_ID, null) ?: generateDeviceId()
        val publicKey = SessionCrypto.spkiBase64FromRawKey(
            SessionCrypto.publicKeyForSecretKey(getOrCreateSessionSecretKey()),
        )
        return DeviceIdentity(
            deviceId = deviceId,
            displayName = deviceNameRepository.getDeviceName(),
            platform = DevicePlatform.Android,
            publicKey = publicKey,
            protocolVersion = BEAMDROP_PROTOCOL_VERSION,
        )
    }

    fun getOrCreateSessionSecretKey(): ByteArray {
        val stored = preferences.getString(KEY_SESSION_SECRET_KEY, null)
        if (stored != null) return Base64.getDecoder().decode(stored)
        val secretKey = SessionCrypto.generateSecretKey()
        preferences.edit()
            .putString(KEY_SESSION_SECRET_KEY, Base64.getEncoder().encodeToString(secretKey))
            .apply()
        return secretKey
    }

    private fun generateDeviceId(): String {
        val deviceId = UUID.randomUUID().toString()
        preferences.edit().putString(KEY_DEVICE_ID, deviceId).apply()
        return deviceId
    }

    private companion object {
        const val KEY_DEVICE_ID = "device_id"
        const val KEY_SESSION_SECRET_KEY = "session_secret_key_v1"
    }
}

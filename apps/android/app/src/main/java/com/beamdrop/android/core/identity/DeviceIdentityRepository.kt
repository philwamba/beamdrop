package com.beamdrop.android.core.identity

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import com.beamdrop.android.core.pairing.BEAMDROP_PROTOCOL_VERSION
import com.beamdrop.android.core.pairing.DeviceIdentity
import com.beamdrop.android.core.pairing.DevicePlatform
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.SecureRandom
import java.security.spec.ECGenParameterSpec
import java.util.UUID

class DeviceIdentityRepository(
    context: Context,
    private val deviceNameRepository: DeviceNameRepository,
) {
    private val preferences = context.getSharedPreferences("device_identity", Context.MODE_PRIVATE)

    fun getOrCreateIdentity(): DeviceIdentity {
        val deviceId = preferences.getString(KEY_DEVICE_ID, null) ?: generateDeviceId()
        val keyPair = getOrCreateKeyPair()
        return DeviceIdentity(
            deviceId = deviceId,
            displayName = deviceNameRepository.getDeviceName(),
            platform = DevicePlatform.Android,
            publicKey = Base64.encodeToString(keyPair.public.encoded, Base64.NO_WRAP),
            protocolVersion = BEAMDROP_PROTOCOL_VERSION,
        )
    }

    private fun generateDeviceId(): String {
        val idBytes = ByteArray(16)
        SecureRandom().nextBytes(idBytes)
        val deviceId = UUID.nameUUIDFromBytes(idBytes).toString()
        preferences.edit().putString(KEY_DEVICE_ID, deviceId).apply()
        return deviceId
    }

    private fun getOrCreateKeyPair(): KeyPair {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        val privateKey = keyStore.getKey(KEY_ALIAS, null)
        val certificate = keyStore.getCertificate(KEY_ALIAS)
        if (privateKey != null && certificate != null) {
            return KeyPair(certificate.publicKey, privateKey as java.security.PrivateKey)
        }

        val generator = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, ANDROID_KEYSTORE)
        val spec = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY,
        )
            .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
            .setDigests(KeyProperties.DIGEST_SHA256, KeyProperties.DIGEST_SHA512)
            .setUserAuthenticationRequired(false)
            .build()
        generator.initialize(spec)
        return generator.generateKeyPair()
    }

    private companion object {
        const val ANDROID_KEYSTORE = "AndroidKeyStore"
        const val KEY_ALIAS = "beamdrop_device_identity_v1"
        const val KEY_DEVICE_ID = "device_id"
    }
}

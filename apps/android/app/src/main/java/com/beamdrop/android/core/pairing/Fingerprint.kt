package com.beamdrop.android.core.pairing

import java.security.MessageDigest
import java.util.Locale

object Fingerprint {
    fun fromPublicKey(publicKey: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(publicKey.toByteArray(Charsets.UTF_8))
        return digest
            .take(8)
            .joinToString(":") { "%02X".format(Locale.US, it) }
    }
}

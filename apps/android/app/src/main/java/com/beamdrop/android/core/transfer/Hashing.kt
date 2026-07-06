package com.beamdrop.android.core.transfer

import java.io.InputStream
import java.security.MessageDigest

object Sha256Verifier {
    fun hashHex(input: InputStream, bufferSize: Int = 256 * 1024): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val buffer = ByteArray(bufferSize)
        while (true) {
            val read = input.read(buffer)
            if (read == -1) break
            if (read > 0) digest.update(buffer, 0, read)
        }
        return digest.digest().joinToString(separator = "") { "%02x".format(it) }
    }

    fun verify(input: InputStream, expectedSha256: String): Boolean =
        hashHex(input).equals(expectedSha256, ignoreCase = true)
}


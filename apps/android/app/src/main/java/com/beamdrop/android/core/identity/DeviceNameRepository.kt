package com.beamdrop.android.core.identity

import android.content.Context
import android.os.Build

class DeviceNameRepository(context: Context) {
    private val preferences = context.getSharedPreferences("device_identity", Context.MODE_PRIVATE)

    fun getDeviceName(): String =
        preferences.getString(KEY_DEVICE_NAME, null) ?: defaultDeviceName()

    fun setDeviceName(name: String): String {
        val sanitized = sanitize(name)
        preferences.edit().putString(KEY_DEVICE_NAME, sanitized).apply()
        return sanitized
    }

    private fun defaultDeviceName(): String {
        val model = Build.MODEL?.takeIf { it.isNotBlank() } ?: "Android"
        return sanitize("$model BeamDrop")
    }

    private fun sanitize(value: String): String =
        value.trim()
            .replace(Regex("\\s+"), " ")
            .take(48)
            .ifBlank { "Android BeamDrop" }

    private companion object {
        const val KEY_DEVICE_NAME = "device_name"
    }
}

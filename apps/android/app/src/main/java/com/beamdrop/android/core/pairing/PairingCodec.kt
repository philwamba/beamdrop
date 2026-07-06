package com.beamdrop.android.core.pairing

import org.json.JSONObject

object PairingCodec {
    fun encode(payload: PairingQrPayload): String {
        val json = JSONObject()
            .put("type", "beamdrop_pairing")
            .put("protocolVersion", BEAMDROP_PROTOCOL_VERSION_NAME)
            .put("pairingSessionId", payload.pairingSessionId)
            .put("deviceId", payload.deviceId)
            .put("deviceName", payload.displayName)
            .put("platform", payload.platform.wireName)
            .put("publicKey", payload.publicKey)
            .put("serviceName", payload.serviceName)
            .put("expiresAtEpochMillis", payload.expiresAtEpochMillis)

        payload.endpoint?.let { endpoint ->
            json.put(
                "endpoint",
                JSONObject()
                    .put("host", endpoint.host)
                    .put("port", endpoint.port)
                    .put("route", endpoint.route),
            )
        }

        return json.toString()
    }

    fun decode(raw: String): PairingQrPayload? = runCatching {
        val json = JSONObject(raw)
        if (json.optString("type") != "beamdrop_pairing") return null

        val endpointJson = json.optJSONObject("endpoint")
        PairingQrPayload(
            pairingSessionId = json.stringValue("pairingSessionId", "pairing_session_id"),
            deviceId = json.stringValue("deviceId", "device_id"),
            displayName = json.stringValue("deviceName", "display_name"),
            platform = DevicePlatform.fromWireName(json.getString("platform")),
            publicKey = json.stringValue("publicKey", "public_key"),
            serviceName = json.stringValue("serviceName", "service_name"),
            endpoint = endpointJson?.let {
                EndpointHint(
                    host = it.optString("host").takeUnless(String::isBlank),
                    port = if (it.has("port") && !it.isNull("port")) it.getInt("port") else null,
                    route = it.optString("route", "local"),
                )
            },
            protocolVersion = json.protocolVersionValue(),
            expiresAtEpochMillis = json.longValue("expiresAtEpochMillis", "expires_at_epoch_millis"),
        )
    }.getOrNull()

    private fun JSONObject.stringValue(camelName: String, legacyName: String): String =
        if (has(camelName)) getString(camelName) else getString(legacyName)

    private fun JSONObject.longValue(camelName: String, legacyName: String): Long =
        if (has(camelName)) getLong(camelName) else getLong(legacyName)

    private fun JSONObject.protocolVersionValue(): Int {
        val raw = when {
            has("protocolVersion") -> get("protocolVersion")
            has("protocol_version") -> get("protocol_version")
            else -> return -1
        }
        return when (raw) {
            is Number -> raw.toInt()
            is String -> if (raw == BEAMDROP_PROTOCOL_VERSION_NAME) BEAMDROP_PROTOCOL_VERSION else raw.toIntOrNull() ?: -1
            else -> -1
        }
    }
}

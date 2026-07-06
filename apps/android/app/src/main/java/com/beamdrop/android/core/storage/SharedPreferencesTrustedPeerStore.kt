package com.beamdrop.android.core.storage

import android.content.Context
import com.beamdrop.android.core.pairing.DevicePlatform
import com.beamdrop.android.core.pairing.EndpointHint
import com.beamdrop.android.core.pairing.TrustState
import com.beamdrop.android.core.pairing.TrustedPeer
import org.json.JSONArray
import org.json.JSONObject

class SharedPreferencesTrustedPeerStore(context: Context) : TrustedPeerStore {
    private val preferences = context.getSharedPreferences("trusted_peers", Context.MODE_PRIVATE)

    override fun list(): List<TrustedPeer> {
        val raw = preferences.getString(KEY_PEERS, "[]") ?: "[]"
        return runCatching {
            val array = JSONArray(raw)
            buildList {
                for (index in 0 until array.length()) {
                    add(array.getJSONObject(index).toPeer())
                }
            }
        }.getOrDefault(emptyList())
    }

    override fun get(deviceId: String): TrustedPeer? = list().firstOrNull { it.deviceId == deviceId }

    override fun upsert(peer: TrustedPeer) {
        val peers = list().filterNot { it.deviceId == peer.deviceId } + peer
        val array = JSONArray()
        peers.forEach { array.put(it.toJson()) }
        preferences.edit().putString(KEY_PEERS, array.toString()).apply()
    }

    private fun JSONObject.toPeer(): TrustedPeer = TrustedPeer(
        deviceId = getString("device_id"),
        displayName = getString("display_name"),
        platform = DevicePlatform.fromWireName(getString("platform")),
        publicKey = getString("public_key"),
        fingerprint = getString("fingerprint"),
        trustState = TrustState.valueOf(getString("trust_state")),
        endpoint = optJSONObject("endpoint")?.let {
            EndpointHint(
                host = it.optString("host").takeUnless(String::isBlank),
                port = if (it.has("port") && !it.isNull("port")) it.getInt("port") else null,
                route = it.optString("route", "local"),
            )
        },
        trustedAtEpochMillis = optLongOrNull("trusted_at_epoch_millis"),
        revokedAtEpochMillis = optLongOrNull("revoked_at_epoch_millis"),
        lastSeenEpochMillis = optLongOrNull("last_seen_epoch_millis"),
    )

    private fun TrustedPeer.toJson(): JSONObject = JSONObject()
        .put("device_id", deviceId)
        .put("display_name", displayName)
        .put("platform", platform.wireName)
        .put("public_key", publicKey)
        .put("fingerprint", fingerprint)
        .put("trust_state", trustState.name)
        .put(
            "endpoint",
            endpoint?.let {
                JSONObject()
                    .put("host", it.host)
                    .put("port", it.port)
                    .put("route", it.route)
            },
        )
        .put("trusted_at_epoch_millis", trustedAtEpochMillis)
        .put("revoked_at_epoch_millis", revokedAtEpochMillis)
        .put("last_seen_epoch_millis", lastSeenEpochMillis)

    private fun JSONObject.optLongOrNull(name: String): Long? =
        if (has(name) && !isNull(name)) optLong(name) else null

    private companion object {
        const val KEY_PEERS = "peers"
    }
}

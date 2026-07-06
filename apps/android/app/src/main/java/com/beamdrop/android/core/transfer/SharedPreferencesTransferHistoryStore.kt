package com.beamdrop.android.core.transfer

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

class SharedPreferencesTransferHistoryStore(context: Context) : TransferHistoryStore {
    private val preferences = context.getSharedPreferences("transfer_history", Context.MODE_PRIVATE)

    override fun list(): List<TransferHistoryRecord> {
        val raw = preferences.getString(KEY_RECORDS, "[]") ?: "[]"
        return runCatching {
            val array = JSONArray(raw)
            buildList {
                for (index in 0 until array.length()) {
                    add(array.getJSONObject(index).toRecord())
                }
            }.sortedByDescending { it.createdAtEpochMillis }
        }.getOrDefault(emptyList())
    }

    override fun upsert(record: TransferHistoryRecord) {
        val records = list().filterNot { it.transferId == record.transferId } + record
        val array = JSONArray()
        records.sortedByDescending { it.createdAtEpochMillis }.forEach { array.put(it.toJson()) }
        preferences.edit().putString(KEY_RECORDS, array.toString()).apply()
    }

    private fun JSONObject.toRecord(): TransferHistoryRecord = TransferHistoryRecord(
        transferId = getString("transfer_id"),
        direction = TransferDirection.valueOf(getString("direction")),
        peerDeviceId = getString("peer_device_id"),
        peerDisplayName = getString("peer_display_name"),
        type = AndroidTransferType.valueOf(getString("type")),
        fileName = getString("file_name"),
        sizeBytes = getLong("size_bytes"),
        status = TransferStatus.valueOf(getString("status")),
        createdAtEpochMillis = getLong("created_at_epoch_millis"),
        completedAtEpochMillis = optLongOrNull("completed_at_epoch_millis"),
        sha256 = optStringOrNull("sha256"),
        errorMessage = optStringOrNull("error_message"),
    )

    private fun TransferHistoryRecord.toJson(): JSONObject = JSONObject()
        .put("transfer_id", transferId)
        .put("direction", direction.name)
        .put("peer_device_id", peerDeviceId)
        .put("peer_display_name", peerDisplayName)
        .put("type", type.name)
        .put("file_name", fileName)
        .put("size_bytes", sizeBytes)
        .put("status", status.name)
        .put("created_at_epoch_millis", createdAtEpochMillis)
        .put("completed_at_epoch_millis", completedAtEpochMillis)
        .put("sha256", sha256)
        .put("error_message", errorMessage)

    private fun JSONObject.optLongOrNull(name: String): Long? =
        if (has(name) && !isNull(name)) optLong(name) else null

    private fun JSONObject.optStringOrNull(name: String): String? =
        if (has(name) && !isNull(name)) optString(name) else null

    private companion object {
        const val KEY_RECORDS = "records"
    }
}

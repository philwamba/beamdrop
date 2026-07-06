package com.beamdrop.android.core.transfer

import org.json.JSONObject
import java.time.Instant

object TransferEnvelopeCodec {
    fun encode(metadata: TransferMetadata): String {
        val payloadMetadata = JSONObject()
            .put("fileName", metadata.fileName)
            .put("mimeType", metadata.mimeType)
            .put("sizeBytes", metadata.sizeBytes)
            .put("chunkSize", metadata.chunkSizeBytes)
            .put("totalChunks", metadata.totalChunks)
            .put("sha256", metadata.sha256)

        return JSONObject()
            .put("protocolVersion", "1.0")
            .put("transferId", metadata.transferId)
            .put("transferType", metadata.type.name)
            .put("senderDeviceId", metadata.senderDeviceId)
            .put("senderPublicKey", metadata.senderPublicKey)
            .put("receiverDeviceId", metadata.receiverDeviceId)
            .put("createdAt", Instant.ofEpochMilli(metadata.createdAtEpochMillis).toString())
            .put("payloadMetadata", payloadMetadata)
            .toString()
    }

    fun decode(rawJson: String): TransferMetadata {
        val json = JSONObject(rawJson)
        require(json.getString("protocolVersion") == "1.0") { "Unsupported BeamDrop protocol version." }
        val payload = json.getJSONObject("payloadMetadata")
        val sizeBytes = payload.getLong("sizeBytes")
        val chunkSize = payload.optLong("chunkSize", DEFAULT_CHUNK_SIZE_BYTES)
        return TransferMetadata(
            transferId = json.getString("transferId"),
            type = AndroidTransferType.valueOf(json.getString("transferType")),
            senderDeviceId = json.getString("senderDeviceId"),
            senderPublicKey = json.optString("senderPublicKey"),
            receiverDeviceId = json.getString("receiverDeviceId"),
            fileName = payload.getString("fileName"),
            mimeType = payload.getString("mimeType"),
            sizeBytes = sizeBytes,
            chunkSizeBytes = chunkSize,
            totalChunks = payload.optLong("totalChunks", ChunkCalculator.totalChunks(sizeBytes, chunkSize)),
            sha256 = payload.optString("sha256").takeUnless(String::isBlank),
            createdAtEpochMillis = Instant.parse(json.getString("createdAt")).toEpochMilli(),
        )
    }
}

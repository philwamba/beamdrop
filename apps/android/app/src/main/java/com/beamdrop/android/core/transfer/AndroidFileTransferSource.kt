package com.beamdrop.android.core.transfer

import android.content.ContentResolver
import android.net.Uri
import android.provider.OpenableColumns
import java.io.InputStream

class AndroidFileTransferSource(
    private val contentResolver: ContentResolver,
    private val uri: Uri,
) : TransferByteSource {
    override val sizeBytes: Long by lazy {
        val queriedSize = contentResolver.query(uri, arrayOf(OpenableColumns.SIZE), null, null, null)?.use { cursor ->
            val index = cursor.getColumnIndex(OpenableColumns.SIZE)
            if (cursor.moveToFirst() && index >= 0 && !cursor.isNull(index)) cursor.getLong(index) else -1L
        } ?: -1L
        val descriptorSize = if (queriedSize >= 0) queriedSize else {
            contentResolver.openAssetFileDescriptor(uri, "r")?.use { it.length } ?: -1L
        }
        require(descriptorSize >= 0) { "Selected file size is unknown and cannot be transferred safely" }
        descriptorSize
    }

    val displayName: String by lazy {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (cursor.moveToFirst() && index >= 0) cursor.getString(index) else null
        } ?: uri.lastPathSegment ?: "Selected file"
    }

    val mimeType: String
        get() = contentResolver.getType(uri) ?: "application/octet-stream"

    override fun openStream(): InputStream =
        requireNotNull(contentResolver.openInputStream(uri)) { "Unable to open selected file" }
}

package com.beamdrop.android.core.clipboard

import android.content.ClipDescription
import android.content.ClipboardManager
import com.beamdrop.android.core.transfer.TransferHistoryRecord
import com.beamdrop.android.core.transfer.TransferManager
import com.beamdrop.android.core.transfer.TransferPeer

class ManualClipboardSender(
    private val clipboardManager: ClipboardManager,
    private val transferManager: TransferManager,
) {
    fun sendCurrentClipboardText(peer: TransferPeer): ClipboardSendResult {
        val clip = clipboardManager.primaryClip ?: return ClipboardSendResult.Empty
        val description = clipboardManager.primaryClipDescription ?: return ClipboardSendResult.Empty
        if (!description.hasMimeType(ClipDescription.MIMETYPE_TEXT_PLAIN) &&
            !description.hasMimeType(ClipDescription.MIMETYPE_TEXT_HTML)
        ) {
            return ClipboardSendResult.Unsupported
        }
        val text = clip.getItemAt(0)?.coerceToText(null)?.toString().orEmpty()
        if (text.isBlank()) return ClipboardSendResult.Empty
        return ClipboardSendResult.Sent(transferManager.sendClipboardText(peer, text))
    }
}

sealed class ClipboardSendResult {
    data class Sent(val record: TransferHistoryRecord) : ClipboardSendResult()
    data object Empty : ClipboardSendResult()
    data object Unsupported : ClipboardSendResult()
}

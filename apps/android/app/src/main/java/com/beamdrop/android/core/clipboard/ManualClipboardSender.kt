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
        if (SensitiveClipboardDetector.looksSensitive(text)) return ClipboardSendResult.SensitiveBlocked
        return ClipboardSendResult.Sent(transferManager.sendClipboardText(peer, text))
    }
}

object SensitiveClipboardDetector {
    private val sensitiveWords = listOf(
        "password",
        "passcode",
        "otp",
        "2fa",
        "secret",
        "private key",
        "api_key",
        "token=",
        "bearer ",
    )

    fun looksSensitive(text: String): Boolean {
        val lower = text.lowercase()
        if (sensitiveWords.any(lower::contains)) return true
        val digits = text.count(Char::isDigit)
        return digits >= 12 && mightContainCardOrSsn(text)
    }

    private fun mightContainCardOrSsn(text: String): Boolean {
        val normalized = text.filter { it.isDigit() || it == '-' || it == ' ' }
        return normalized
            .split(' ', '-')
            .filter(String::isNotBlank)
            .any { part -> part.length == 3 || part.length == 4 || part.length >= 12 }
    }
}

sealed class ClipboardSendResult {
    data class Sent(val record: TransferHistoryRecord) : ClipboardSendResult()
    data object Empty : ClipboardSendResult()
    data object Unsupported : ClipboardSendResult()
    data object SensitiveBlocked : ClipboardSendResult()
}

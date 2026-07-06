package com.beamdrop.android.core.notifications

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import com.beamdrop.android.MainActivity

object TransferNotificationActions {
    const val ACTION_CANCEL_TRANSFER = "com.beamdrop.android.action.CANCEL_TRANSFER"
    const val ACTION_SEND_CLIPBOARD = "com.beamdrop.android.action.SEND_CLIPBOARD"
    const val EXTRA_TRANSFER_ID = "transfer_id"

    fun sendClipboardIntent(context: Context): PendingIntent =
        PendingIntent.getActivity(
            context,
            1001,
            Intent(context, MainActivity::class.java).setAction(ACTION_SEND_CLIPBOARD),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    fun cancelTransferIntent(context: Context, transferId: String): PendingIntent =
        PendingIntent.getActivity(
            context,
            transferId.hashCode(),
            Intent(context, MainActivity::class.java)
                .setAction(ACTION_CANCEL_TRANSFER)
                .putExtra(EXTRA_TRANSFER_ID, transferId),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
}


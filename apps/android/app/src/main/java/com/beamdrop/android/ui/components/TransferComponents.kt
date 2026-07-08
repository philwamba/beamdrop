package com.beamdrop.android.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Send
import androidx.compose.material.icons.outlined.Block
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.StopCircle
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.beamdrop.android.core.transfer.IncomingTransferRequest
import com.beamdrop.android.core.transfer.TransferHistoryRecord
import com.beamdrop.android.core.transfer.TransferProgress
import com.beamdrop.android.core.transfer.TransferStatus
import com.beamdrop.android.ui.util.formatBytes

@Composable
internal fun TransferProgressCard(
    progress: TransferProgress,
    onCancel: () -> Unit,
) {
    var confirmCancel by remember { mutableStateOf(false) }
    if (confirmCancel) {
        AlertDialog(
            onDismissRequest = { confirmCancel = false },
            title = { Text("Cancel transfer?") },
            text = {
                Text("This stops the current transfer with ${progress.peer.displayName}. The cancelled transfer will appear in history.")
            },
            confirmButton = {
                Button(onClick = {
                    confirmCancel = false
                    onCancel()
                }) { Text("Cancel transfer") }
            },
            dismissButton = {
                TextButton(onClick = { confirmCancel = false }) { Text("Keep sending") }
            },
        )
    }

    SectionSurface {
        Text(progress.metadata.fileName, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        Text("${progress.peer.displayName} · ${progress.direction.name} · ${progress.status.name}")
        Spacer(Modifier.height(10.dp))
        LinearProgressIndicator(
            progress = { progress.percent / 100f },
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(8.dp))
        Text(
            "${progress.percent}% · ${formatBytes(progress.bytesTransferred)} of ${formatBytes(progress.metadata.sizeBytes)} · ${formatBytes(progress.speedBytesPerSecond)}/s",
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.height(10.dp))
        OutlinedButton(onClick = { confirmCancel = true }) {
            Icon(Icons.Outlined.StopCircle, contentDescription = null)
            Spacer(Modifier.size(8.dp))
            Text("Cancel")
        }
    }
}

@Composable
internal fun ReceiveApprovalPromptDialog(
    request: IncomingTransferRequest,
    onAccept: () -> Unit,
    onReject: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onReject,
        title = { Text("Receive file?") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(request.sender.displayName, fontWeight = FontWeight.SemiBold)
                Text("File: ${request.metadata.fileName}")
                Text("Size: ${formatBytes(request.metadata.sizeBytes)}")
                Text("Unknown and revoked devices are rejected before this prompt. Accepting does not change trust.")
            }
        },
        confirmButton = { Button(onClick = onAccept) { Text("Accept") } },
        dismissButton = { TextButton(onClick = onReject) { Text("Reject") } },
    )
}

@Composable
internal fun HistoryRow(record: TransferHistoryRecord) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(
            imageVector = when (record.status) {
                TransferStatus.Completed -> Icons.Outlined.CheckCircle
                TransferStatus.Cancelled -> Icons.Outlined.StopCircle
                TransferStatus.Rejected, TransferStatus.Failed, TransferStatus.Corrupted, TransferStatus.Incomplete -> Icons.Outlined.Block
                else -> Icons.AutoMirrored.Outlined.Send
            },
            contentDescription = null,
            tint = when (record.status) {
                TransferStatus.Completed -> MaterialTheme.colorScheme.secondary
                TransferStatus.Cancelled -> MaterialTheme.colorScheme.tertiary
                TransferStatus.Rejected, TransferStatus.Failed, TransferStatus.Corrupted, TransferStatus.Incomplete -> MaterialTheme.colorScheme.error
                else -> MaterialTheme.colorScheme.primary
            },
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(record.fileName, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(
                "${record.direction.name} · ${record.status.name} · ${record.peerDisplayName} · ${formatBytes(record.sizeBytes)}",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            record.errorMessage?.let { ErrorText(it) }
        }
    }
}

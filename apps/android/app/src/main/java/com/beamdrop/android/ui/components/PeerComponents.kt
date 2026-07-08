package com.beamdrop.android.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Block
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.beamdrop.android.core.pairing.TrustState
import com.beamdrop.android.core.pairing.TrustedPeer
import com.beamdrop.android.core.transfer.TransferPeer

@Composable
internal fun PeerRow(peer: TrustedPeer) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(
            if (peer.trustState == TrustState.Trusted) Icons.Outlined.CheckCircle else Icons.Outlined.Block,
            contentDescription = null,
            tint = if (peer.trustState == TrustState.Trusted) MaterialTheme.colorScheme.secondary else MaterialTheme.colorScheme.error,
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(peer.displayName, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(
                "${peer.platform.wireName} · ${peer.trustState.name.lowercase()} · ${peer.fingerprint}",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

@Composable
internal fun PeerChoiceList(
    peers: List<TransferPeer>,
    selectedPeer: TransferPeer?,
    onSelect: (TransferPeer) -> Unit,
) {
    if (peers.isEmpty()) {
        Text("No trusted devices available. Pair a device first.", color = MaterialTheme.colorScheme.onSurfaceVariant)
        return
    }
    peers.forEach { peer ->
        val selected = selectedPeer?.deviceId == peer.deviceId
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(peer.displayName, fontWeight = FontWeight.SemiBold)
                Text(
                    if (peer.endpointHost == null) "Trusted · endpoint unavailable" else "Trusted · ${peer.endpointHost}:${peer.endpointPort}",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            if (selected) {
                AssistChip(onClick = {}, label = { Text("Selected") })
            } else {
                TextButton(onClick = { onSelect(peer) }) { Text("Use") }
            }
        }
        Spacer(Modifier.height(8.dp))
    }
}

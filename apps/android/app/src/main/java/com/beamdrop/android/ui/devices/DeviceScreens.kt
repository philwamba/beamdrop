package com.beamdrop.android.ui.devices

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.Block
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.beamdrop.android.core.pairing.TrustState
import com.beamdrop.android.core.pairing.TrustedPeer
import com.beamdrop.android.core.transfer.DEFAULT_TRANSFER_PORT
import com.beamdrop.android.navigation.BeamDropDestination
import com.beamdrop.android.ui.components.BeamDropBottomBar
import com.beamdrop.android.ui.components.EmptyDevices
import com.beamdrop.android.ui.components.ErrorText
import com.beamdrop.android.ui.components.PeerRow
import com.beamdrop.android.ui.components.SectionSurface

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun TrustedDevicesScreen(
    peers: List<TrustedPeer>,
    onHome: () -> Unit,
    onHistory: () -> Unit,
    onSettings: () -> Unit,
    onScan: () -> Unit,
    onRevoke: (String) -> Unit,
    onPair: () -> Unit,
    onDevice: (TrustedPeer) -> Unit,
) {
    var pendingRevoke by remember { mutableStateOf<TrustedPeer?>(null) }
    pendingRevoke?.let { peer ->
        AlertDialog(
            onDismissRequest = { pendingRevoke = null },
            title = { Text("Revoke trust?") },
            text = {
                Text("Future sends and resumes from ${peer.displayName} will be blocked until it is paired again with QR approval.")
            },
            confirmButton = {
                Button(onClick = {
                    onRevoke(peer.deviceId)
                    pendingRevoke = null
                }) { Text("Revoke") }
            },
            dismissButton = { TextButton(onClick = { pendingRevoke = null }) { Text("Cancel") } },
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Trusted Devices") },
            )
        },
        bottomBar = {
            BeamDropBottomBar(
                current = BeamDropDestination.Devices,
                onHome = onHome,
                onDevices = {},
                onHistory = onHistory,
                onSettings = onSettings,
            )
        },
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .background(MaterialTheme.colorScheme.background)
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            if (peers.isEmpty()) {
                item {
                    SectionSurface {
                        EmptyDevices(onPair = onPair, onScan = onScan)
                    }
                }
            } else {
                items(peers, key = { it.deviceId }) { peer ->
                    SectionSurface {
                        PeerRow(peer)
                        Spacer(Modifier.height(10.dp))
                        OutlinedButton(onClick = { onDevice(peer) }) {
                            Text("View Details")
                        }
                        Spacer(Modifier.height(6.dp))
                        if (peer.trustState == TrustState.Trusted) {
                            OutlinedButton(onClick = { pendingRevoke = peer }) {
                                Icon(Icons.Outlined.Block, contentDescription = null)
                                Spacer(Modifier.size(8.dp))
                                Text("Revoke trust")
                            }
                        } else {
                            Text("Revoked devices cannot transfer or resume until deliberately re-paired.")
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun DeviceDetailScreen(
    peer: TrustedPeer?,
    onBack: () -> Unit,
    onRevoke: () -> Unit,
) {
    var confirmRevoke by remember { mutableStateOf(false) }
    if (confirmRevoke) {
        AlertDialog(
            onDismissRequest = { confirmRevoke = false },
            title = { Text("Revoke Trust?") },
            text = { Text("This device will be blocked from sending, receiving, or resuming transfers until it is paired again.") },
            confirmButton = {
                Button(onClick = {
                    confirmRevoke = false
                    onRevoke()
                }) { Text("Revoke") }
            },
            dismissButton = { TextButton(onClick = { confirmRevoke = false }) { Text("Cancel") } },
        )
    }
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Device Detail") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .background(MaterialTheme.colorScheme.background)
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            if (peer == null) {
                item { SectionSurface { ErrorText("No device selected. Return to trusted devices and choose a device.") } }
            } else {
                item {
                    SectionSurface {
                        Text(peer.displayName, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
                        Text("Platform: ${peer.platform.wireName}", color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text("Trust: ${peer.trustState.name}", color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text("Fingerprint: ${peer.fingerprint}", color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text("Endpoint: ${peer.endpoint?.host ?: "Not available"}:${peer.endpoint?.port ?: DEFAULT_TRANSFER_PORT}", color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Spacer(Modifier.height(12.dp))
                        if (peer.trustState == TrustState.Trusted) {
                            OutlinedButton(onClick = { confirmRevoke = true }) {
                                Icon(Icons.Outlined.Block, contentDescription = null)
                                Spacer(Modifier.size(8.dp))
                                Text("Revoke Trust")
                            }
                        } else {
                            ErrorText("Revoked devices are blocked until deliberately re-paired.")
                        }
                    }
                }
            }
        }
    }
}

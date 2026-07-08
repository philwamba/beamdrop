package com.beamdrop.android.ui.home

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Send
import androidx.compose.material.icons.outlined.AttachFile
import androidx.compose.material.icons.outlined.ContentPaste
import androidx.compose.material.icons.outlined.Devices
import androidx.compose.material.icons.outlined.History
import androidx.compose.material.icons.outlined.Security
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.beamdrop.android.R
import com.beamdrop.android.core.pairing.DeviceIdentity
import com.beamdrop.android.core.pairing.Fingerprint
import com.beamdrop.android.core.pairing.TrustState
import com.beamdrop.android.core.pairing.TrustedPeer
import com.beamdrop.android.core.transfer.TransferHistoryRecord
import com.beamdrop.android.navigation.BeamDropDestination
import com.beamdrop.android.ui.components.BeamDropBottomBar
import com.beamdrop.android.ui.components.EmptyDevices
import com.beamdrop.android.ui.components.HistoryRow
import com.beamdrop.android.ui.components.PeerRow
import com.beamdrop.android.ui.components.SectionSurface

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun HomeScreen(
    identity: DeviceIdentity,
    peers: List<TrustedPeer>,
    history: List<TransferHistoryRecord>,
    clipboardMessage: String?,
    onPair: () -> Unit,
    onScan: () -> Unit,
    onNearby: () -> Unit,
    onDevices: () -> Unit,
    onPermissions: () -> Unit,
    onSendText: () -> Unit,
    onSendFile: () -> Unit,
    onSendClipboard: () -> Unit,
    onHistory: () -> Unit,
    onSettings: () -> Unit,
    onAbout: () -> Unit,
    onOnboarding: () -> Unit,
    onNameSaved: (String) -> Unit,
) {
    var name by remember(identity.displayName) { mutableStateOf(identity.displayName) }
    val trustedCount = peers.count { it.trustState == TrustState.Trusted }
    val identityCode = remember(identity.publicKey) {
        Fingerprint.fromPublicKey(identity.publicKey)
            .split(":")
            .take(2)
            .joinToString(" ")
    }
    Scaffold(
        bottomBar = {
            BeamDropBottomBar(
                current = BeamDropDestination.Home,
                onHome = {},
                onDevices = onDevices,
                onHistory = onHistory,
                onSettings = onSettings,
            )
        },
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .background(MaterialTheme.colorScheme.background)
                .padding(padding)
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            item {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .fillParentMaxHeight(0.82f),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.End,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        IconButton(onClick = onHistory) {
                            Icon(Icons.Outlined.History, contentDescription = "Transfer history")
                        }
                        IconButton(onClick = onAbout) {
                            Icon(Icons.Outlined.Security, contentDescription = "About BeamDrop")
                        }
                    }

                    Spacer(Modifier.weight(1f))

                    Surface(
                        shape = MaterialTheme.shapes.extraLarge,
                        color = MaterialTheme.colorScheme.surface,
                        tonalElevation = 2.dp,
                        shadowElevation = 0.dp,
                    ) {
                        Image(
                            painter = painterResource(id = R.drawable.beamdrop_logo),
                            contentDescription = "BeamDrop logo",
                            modifier = Modifier
                                .padding(24.dp)
                                .size(116.dp),
                        )
                    }

                    Spacer(Modifier.height(28.dp))
                    Text(
                        identity.displayName,
                        style = MaterialTheme.typography.displaySmall,
                        fontWeight = FontWeight.Medium,
                        textAlign = TextAlign.Center,
                    )
                    Text(
                        "#$identityCode",
                        style = MaterialTheme.typography.headlineSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        textAlign = TextAlign.Center,
                    )

                    Spacer(Modifier.weight(1f))
                    Text(
                        if (trustedCount == 0) {
                            "No trusted devices yet"
                        } else {
                            "$trustedCount trusted ${if (trustedCount == 1) "device" else "devices"}"
                        },
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        textAlign = TextAlign.Center,
                    )
                }
            }

            item {
                SectionSurface {
                    Text("Send", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                    Text(
                        "Choose what to send to a trusted device.",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Spacer(Modifier.height(12.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
                        Button(onClick = onSendText, modifier = Modifier.weight(1f)) {
                            Icon(Icons.AutoMirrored.Outlined.Send, contentDescription = null)
                            Spacer(Modifier.size(8.dp))
                            Text("Text")
                        }
                        OutlinedButton(onClick = onSendFile, modifier = Modifier.weight(1f)) {
                            Icon(Icons.Outlined.AttachFile, contentDescription = null)
                            Spacer(Modifier.size(8.dp))
                            Text("File")
                        }
                    }
                    Spacer(Modifier.height(8.dp))
                    OutlinedButton(onClick = onSendClipboard, modifier = Modifier.fillMaxWidth()) {
                        Icon(Icons.Outlined.ContentPaste, contentDescription = null)
                        Spacer(Modifier.size(8.dp))
                        Text("Paste clipboard text")
                    }
                }
            }

            item {
                SectionSurface {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        Icon(Icons.Outlined.Devices, contentDescription = null)
                        Column(modifier = Modifier.weight(1f)) {
                            Text("Receive and pair", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                            Text("Show your QR or scan another device.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                    Spacer(Modifier.height(12.dp))
                    if (peers.none { it.trustState == TrustState.Trusted }) {
                        EmptyDevices(onPair, onScan)
                    } else {
                        peers.filter { it.trustState == TrustState.Trusted }.take(3).forEach { PeerRow(it) }
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            TextButton(onClick = onDevices) { Text("Manage devices") }
                            TextButton(onClick = onScan) { Text("Scan QR") }
                        }
                    }
                }
            }

            item {
                SectionSurface {
                    Text("This phone", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                    Text("Rename this device so it is easy to recognize while pairing.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(Modifier.height(12.dp))
                    OutlinedTextField(
                        value = name,
                        onValueChange = { name = it },
                        label = { Text("Device name") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                    )
                    Spacer(Modifier.height(10.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        AssistChip(onClick = {}, label = { Text("This phone") })
                        AssistChip(onClick = {}, label = { Text("No account needed") })
                    }
                    Spacer(Modifier.height(12.dp))
                    Button(onClick = { onNameSaved(name) }) {
                        Text("Save name")
                    }
                }
            }

            clipboardMessage?.let { message ->
                item {
                    SectionSurface {
                        Text(message, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }

            item {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
                    OutlinedButton(onClick = onNearby, modifier = Modifier.weight(1f)) {
                        Icon(Icons.Outlined.Devices, contentDescription = null)
                        Spacer(Modifier.size(8.dp))
                        Text("Nearby")
                    }
                    OutlinedButton(onClick = onPermissions, modifier = Modifier.weight(1f)) {
                        Icon(Icons.Outlined.Security, contentDescription = null)
                        Spacer(Modifier.size(8.dp))
                        Text("Help")
                    }
                }
            }

            item {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
                    TextButton(onClick = onOnboarding, modifier = Modifier.weight(1f)) {
                        Text("How it works")
                    }
                    TextButton(onClick = onAbout, modifier = Modifier.weight(1f)) {
                        Text("About")
                    }
                }
            }

            if (history.isNotEmpty()) {
                item {
                    SectionSurface {
                        Text("Recent transfer", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                        Spacer(Modifier.height(8.dp))
                        HistoryRow(history.first())
                    }
                }
            }
        }
    }
}

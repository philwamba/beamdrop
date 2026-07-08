package com.beamdrop.android.ui.transfer

import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.automirrored.outlined.Send
import androidx.compose.material.icons.outlined.AttachFile
import androidx.compose.material.icons.outlined.Link
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.beamdrop.android.core.pairing.TrustedPeer
import com.beamdrop.android.core.transfer.AndroidFileTransferSource
import com.beamdrop.android.core.transfer.TransferHistoryRecord
import com.beamdrop.android.core.transfer.TransferManager
import com.beamdrop.android.core.transfer.TransferPeer
import com.beamdrop.android.core.transfer.TransferProgress
import com.beamdrop.android.navigation.BeamDropDestination
import com.beamdrop.android.ui.components.BeamDropBottomBar
import com.beamdrop.android.ui.components.ErrorText
import com.beamdrop.android.ui.components.HistoryRow
import com.beamdrop.android.ui.components.PeerChoiceList
import com.beamdrop.android.ui.components.SectionSurface
import com.beamdrop.android.ui.components.TransferProgressCard

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun SendTextScreen(
    peers: List<TrustedPeer>,
    onBack: () -> Unit,
    onSendText: (TransferPeer, String) -> Unit,
    onSendUrl: (TransferPeer, String) -> Unit,
) {
    val trustedPeers = remember(peers) { peers.trustedTransferPeers() }
    var text by remember { mutableStateOf("") }
    var selectedPeer by remember(trustedPeers) { mutableStateOf(trustedPeers.firstOrNull()) }
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Send Text Or Link") },
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
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            item {
                SectionSurface {
                    Text("Trusted device", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                    Spacer(Modifier.height(8.dp))
                    PeerChoiceList(trustedPeers, selectedPeer) { selectedPeer = it }
                }
            }
            item {
                SectionSurface {
                    OutlinedTextField(
                        value = text,
                        onValueChange = { text = it },
                        label = { Text("Text or URL") },
                        minLines = 4,
                        modifier = Modifier.fillMaxWidth(),
                    )
                    Spacer(Modifier.height(12.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
                        Button(
                            onClick = { selectedPeer?.let { onSendText(it, text) } },
                            enabled = selectedPeer != null && text.isNotBlank(),
                            modifier = Modifier.weight(1f),
                        ) {
                            Icon(Icons.AutoMirrored.Outlined.Send, contentDescription = null)
                            Spacer(Modifier.size(8.dp))
                            Text("Send text")
                        }
                        OutlinedButton(
                            onClick = { selectedPeer?.let { onSendUrl(it, text) } },
                            enabled = selectedPeer != null && text.startsWith("http", ignoreCase = true),
                            modifier = Modifier.weight(1f),
                        ) {
                            Icon(Icons.Outlined.Link, contentDescription = null)
                            Spacer(Modifier.size(8.dp))
                            Text("Send link")
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun SendFileScreen(
    peers: List<TrustedPeer>,
    transferManager: TransferManager,
    onBack: () -> Unit,
    onProgress: (TransferProgress) -> Unit,
    onDone: () -> Unit,
) {
    val context = LocalContext.current
    val mainHandler = remember { Handler(Looper.getMainLooper()) }
    val trustedPeers = remember(peers) { peers.trustedTransferPeers() }
    var selectedPeer by remember(trustedPeers) { mutableStateOf(trustedPeers.firstOrNull()) }
    var selectedUri by remember { mutableStateOf<Uri?>(null) }
    var selectedName by remember { mutableStateOf<String?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        selectedUri = uri
        selectedName = uri?.let { AndroidFileTransferSource(context.contentResolver, it).displayName }
        error = null
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Send File") },
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
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            item {
                SectionSurface {
                    Text("Selected file", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                    Text(selectedName ?: "Choose a file with Android's native file picker.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(Modifier.height(12.dp))
                    OutlinedButton(onClick = { picker.launch(arrayOf("*/*")) }) {
                        Icon(Icons.Outlined.AttachFile, contentDescription = null)
                        Spacer(Modifier.size(8.dp))
                        Text("Choose file")
                    }
                }
            }
            item {
                SectionSurface {
                    Text("Trusted device", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                    Spacer(Modifier.height(8.dp))
                    PeerChoiceList(trustedPeers, selectedPeer) { selectedPeer = it }
                }
            }
            item {
                SectionSurface {
                    Text("Large files are streamed in 4 MB chunks. BeamDrop verifies the final SHA-256 hash before marking received files complete.")
                    Spacer(Modifier.height(12.dp))
                    Button(
                        onClick = {
                            val uri = selectedUri ?: return@Button
                            val peer = selectedPeer ?: return@Button
                            Thread {
                                val result = runCatching {
                                    val source = AndroidFileTransferSource(context.contentResolver, uri)
                                    transferManager.sendFile(
                                        peer = peer,
                                        fileName = source.displayName,
                                        mimeType = source.mimeType,
                                        source = source,
                                        onProgress = { progress -> mainHandler.post { onProgress(progress) } },
                                    )
                                }
                                mainHandler.post {
                                    error = result.exceptionOrNull()?.message
                                    onDone()
                                }
                            }.start()
                        },
                        enabled = selectedUri != null && selectedPeer != null,
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Icon(Icons.AutoMirrored.Outlined.Send, contentDescription = null)
                        Spacer(Modifier.size(8.dp))
                        Text("Send selected file")
                    }
                    error?.let {
                        Spacer(Modifier.height(8.dp))
                        ErrorText(it)
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun TransferHistoryScreen(
    history: List<TransferHistoryRecord>,
    progress: TransferProgress?,
    onHome: () -> Unit,
    onDevices: () -> Unit,
    onSettings: () -> Unit,
    onCancel: (String) -> Unit,
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Transfer History") },
            )
        },
        bottomBar = {
            BeamDropBottomBar(
                current = BeamDropDestination.History,
                onHome = onHome,
                onDevices = onDevices,
                onHistory = {},
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
            progress?.let {
                item {
                    TransferProgressCard(progress = it, onCancel = { onCancel(it.metadata.transferId) })
                }
            }
            if (history.isEmpty()) {
                item {
                    SectionSurface {
                        Text("No transfers yet", fontWeight = FontWeight.SemiBold)
                        Text("Sent, received, failed, and cancelled transfers appear here.")
                    }
                }
            } else {
                items(history, key = { it.transferId }) { record ->
                    SectionSurface { HistoryRow(record) }
                }
            }
        }
    }
}

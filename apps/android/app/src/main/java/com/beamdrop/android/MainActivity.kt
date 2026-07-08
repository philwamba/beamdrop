package com.beamdrop.android

import android.Manifest
import android.content.ClipboardManager
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.automirrored.outlined.Send
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Block
import androidx.compose.material.icons.outlined.AttachFile
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.ContentPaste
import androidx.compose.material.icons.outlined.Devices
import androidx.compose.material.icons.outlined.History
import androidx.compose.material.icons.outlined.Link
import androidx.compose.material.icons.outlined.QrCode
import androidx.compose.material.icons.outlined.QrCodeScanner
import androidx.compose.material.icons.outlined.Refresh
import androidx.compose.material.icons.outlined.Security
import androidx.compose.material.icons.outlined.StopCircle
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Divider
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.beamdrop.android.core.identity.DeviceIdentityRepository
import com.beamdrop.android.core.identity.DeviceNameRepository
import com.beamdrop.android.core.clipboard.ClipboardSendResult
import com.beamdrop.android.core.clipboard.ManualClipboardSender
import com.beamdrop.android.core.notifications.TransferNotificationActions
import com.beamdrop.android.core.pairing.DeviceIdentity
import com.beamdrop.android.core.pairing.PairingError
import com.beamdrop.android.core.pairing.PairingSessionFactory
import com.beamdrop.android.core.pairing.PairingValidator
import com.beamdrop.android.core.pairing.TrustState
import com.beamdrop.android.core.pairing.TrustedPeer
import com.beamdrop.android.core.permissions.PermissionPlanner
import com.beamdrop.android.core.permissions.PermissionStateMapper
import com.beamdrop.android.core.permissions.PermissionStatus
import com.beamdrop.android.core.permissions.RuntimePermissionGrant
import com.beamdrop.android.core.storage.SharedPreferencesTrustedPeerStore
import com.beamdrop.android.core.storage.TrustedPeerRepository
import com.beamdrop.android.core.transfer.AndroidFileTransferSource
import com.beamdrop.android.core.transfer.AndroidTransferType
import com.beamdrop.android.core.crypto.SessionTransferEncryption
import com.beamdrop.android.core.transfer.AppPrivateReceiveTargetFactory
import com.beamdrop.android.core.transfer.DEFAULT_TRANSFER_PORT
import com.beamdrop.android.core.transfer.IncomingTransferRequest
import com.beamdrop.android.core.transfer.PeerTrustPolicy
import com.beamdrop.android.core.transfer.ReceiveDecision
import com.beamdrop.android.core.transfer.ReceiveApprovalPrompt
import com.beamdrop.android.core.transfer.SharedPreferencesTransferHistoryStore
import com.beamdrop.android.core.transfer.SocketTransferTransport
import com.beamdrop.android.core.transfer.TcpIncomingTransferServer
import com.beamdrop.android.core.transfer.TransferDirection
import com.beamdrop.android.core.transfer.TransferHistoryRecord
import com.beamdrop.android.core.transfer.TransferManager
import com.beamdrop.android.core.transfer.TransferMetadata
import com.beamdrop.android.core.transfer.TransferPeer
import com.beamdrop.android.core.transfer.TransferProgress
import com.beamdrop.android.core.transfer.TransferStatus
import com.beamdrop.android.ui.pairing.PairNewDevicePresenter
import com.beamdrop.android.ui.pairing.PairNewDeviceUiState
import com.beamdrop.android.ui.pairing.QrCodeBitmap
import com.beamdrop.android.ui.pairing.ScanQrController
import com.beamdrop.android.ui.pairing.ScanQrUiState
import com.google.zxing.BarcodeFormat
import com.google.zxing.BinaryBitmap
import com.google.zxing.DecodeHintType
import com.google.zxing.MultiFormatReader
import com.google.zxing.NotFoundException
import com.google.zxing.PlanarYUVLuminanceSource
import com.google.zxing.common.HybridBinarizer
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val deviceNameRepository = DeviceNameRepository(this)
        val identityRepository = DeviceIdentityRepository(this, deviceNameRepository)
        val localIdentity = identityRepository.getOrCreateIdentity()
        val trustedPeerRepository = TrustedPeerRepository(SharedPreferencesTrustedPeerStore(this))
        val historyStore = SharedPreferencesTransferHistoryStore(this)
        val transferManager = TransferManager(
            trustPolicy = PeerTrustPolicy(trustedPeerRepository),
            transport = SocketTransferTransport(),
            receiveTargetFactory = AppPrivateReceiveTargetFactory(this),
            historyStore = historyStore,
            approvalPrompt = ManualReceiveApprovalPrompt,
            localDeviceId = localIdentity.deviceId,
            localPublicKey = localIdentity.publicKey,
            encryptionPolicy = SessionTransferEncryption(identityRepository.getOrCreateSessionSecretKey()),
            logger = { message -> Log.i("BeamDropTransfer", message) },
        )
        val clipboardSender = ManualClipboardSender(
            clipboardManager = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager,
            transferManager = transferManager,
        )
        val incomingServer = TcpIncomingTransferServer(
            transferManager = transferManager,
            trustedPeerRepository = trustedPeerRepository,
            port = DEFAULT_TRANSFER_PORT,
        )
        Thread {
            while (!Thread.currentThread().isInterrupted) {
                runCatching { incomingServer.runOnce() }
                    .onFailure { Thread.sleep(1_000) }
            }
        }.apply {
            name = "BeamDropIncomingTransferServer"
            start()
        }

        setContent {
            BeamDropTheme {
                BeamDropApp(
                    identityRepository = identityRepository,
                    deviceNameRepository = deviceNameRepository,
                    trustedPeerRepository = trustedPeerRepository,
                    historyStore = historyStore,
                    transferManager = transferManager,
                    clipboardSender = clipboardSender,
                    startupAction = intent?.action,
                )
            }
        }
    }
}

private enum class Screen {
    Home,
    Onboarding,
    Nearby,
    Pair,
    Scan,
    Devices,
    DeviceDetail,
    Permissions,
    SendText,
    SendFile,
    History,
    Settings,
    Privacy,
    Diagnostics,
    About,
}

@Composable
private fun BeamDropTheme(content: @Composable () -> Unit) {
    val dark = isSystemInDarkTheme()
    MaterialTheme(
        colorScheme = if (dark) darkColorScheme(
            primary = Color(0xFFAECBFA),
            secondary = Color(0xFF8FD8CA),
            tertiary = Color(0xFFFFD28A),
            surface = Color(0xFF111318),
            surfaceVariant = Color(0xFF232832),
            background = Color(0xFF0B0D12),
        ) else lightColorScheme(
            primary = Color(0xFF1967D2),
            secondary = Color(0xFF146C5F),
            tertiary = Color(0xFF7A4D00),
            surface = Color(0xFFFAFBFD),
            surfaceVariant = Color(0xFFE8EDF7),
            background = Color(0xFFF5F7FB),
        ),
        content = content,
    )
}

@Composable
private fun BeamDropApp(
    identityRepository: DeviceIdentityRepository,
    deviceNameRepository: DeviceNameRepository,
    trustedPeerRepository: TrustedPeerRepository,
    historyStore: SharedPreferencesTransferHistoryStore,
    transferManager: TransferManager,
    clipboardSender: ManualClipboardSender,
    startupAction: String?,
) {
    var screen by remember {
        mutableStateOf(
            if (startupAction == TransferNotificationActions.ACTION_SEND_CLIPBOARD) Screen.SendText else Screen.Home,
        )
    }
    var identity by remember { mutableStateOf(identityRepository.getOrCreateIdentity()) }
    var peers by remember { mutableStateOf(trustedPeerRepository.listPeers()) }
    var history by remember { mutableStateOf(historyStore.list()) }
    var progress by remember { mutableStateOf<TransferProgress?>(null) }
    var refreshPairing by remember { mutableIntStateOf(0) }
    var selectedDevice by remember { mutableStateOf<TrustedPeer?>(null) }
    var clipboardMessage by remember { mutableStateOf<String?>(null) }

    fun reloadPeers() {
        peers = trustedPeerRepository.listPeers()
    }

    fun reloadHistory() {
        history = historyStore.list()
    }

    fun goBack() {
        screen = when (screen) {
            Screen.Home -> Screen.Home
            Screen.DeviceDetail -> Screen.Devices
            Screen.Privacy, Screen.Diagnostics, Screen.About -> Screen.Settings
            else -> Screen.Home
        }
    }

    BackHandler(enabled = screen != Screen.Home) {
        goBack()
    }

    when (screen) {
        Screen.Home -> HomeScreen(
            identity = identity,
            peers = peers,
            history = history,
            clipboardMessage = clipboardMessage,
            onPair = { screen = Screen.Pair },
            onScan = { screen = Screen.Scan },
            onNearby = { screen = Screen.Nearby },
            onDevices = { screen = Screen.Devices },
            onPermissions = { screen = Screen.Permissions },
            onSendText = { screen = Screen.SendText },
            onSendFile = { screen = Screen.SendFile },
            onSettings = { screen = Screen.Settings },
            onAbout = { screen = Screen.About },
            onOnboarding = { screen = Screen.Onboarding },
            onHistory = {
                reloadHistory()
                screen = Screen.History
            },
            onSendClipboard = {
                peers.firstTrustedTransferPeer()?.let { peer ->
                    clipboardMessage = when (clipboardSender.sendCurrentClipboardText(peer)) {
                        is ClipboardSendResult.Sent -> "Clipboard sent."
                        ClipboardSendResult.Empty -> "Clipboard is empty."
                        ClipboardSendResult.Unsupported -> "Clipboard does not contain supported text."
                        ClipboardSendResult.SensitiveBlocked -> "Clipboard looks sensitive and was not sent."
                    }
                    reloadHistory()
                } ?: run { clipboardMessage = "Pair a trusted device before sending clipboard text." }
            },
            onNameSaved = {
                deviceNameRepository.setDeviceName(it)
                identity = identityRepository.getOrCreateIdentity()
            },
        )

        Screen.Onboarding -> OnboardingScreen(
            onBack = ::goBack,
            onPair = { screen = Screen.Pair },
        )

        Screen.Nearby -> NearbyDevicesScreen(
            onBack = ::goBack,
            onPair = { screen = Screen.Pair },
            onDiagnostics = { screen = Screen.Diagnostics },
        )

        Screen.Pair -> PairNewDeviceScreen(
            state = remember(identity, refreshPairing) {
                PairNewDevicePresenter(PairingSessionFactory()).buildState(
                    identity,
                    endpoint = com.beamdrop.android.core.pairing.EndpointHint(
                        host = LocalNetworkAddress.firstUsableIpv4Address(),
                        port = DEFAULT_TRANSFER_PORT,
                        route = "local",
                    ),
                )
            },
            onBack = ::goBack,
            onRefresh = { refreshPairing++ },
            onScan = { screen = Screen.Scan },
        )

        Screen.Scan -> ScanQrScreen(
            controller = remember {
                ScanQrController(
                    validator = PairingValidator(trustedPeerRepository),
                    trustedPeerRepository = trustedPeerRepository,
                )
            },
            onBack = {
                reloadPeers()
                goBack()
            },
            onTrusted = {
                reloadPeers()
                screen = Screen.Devices
            },
        )

        Screen.Devices -> TrustedDevicesScreen(
            peers = peers,
            onBack = ::goBack,
            onHome = { screen = Screen.Home },
            onHistory = {
                reloadHistory()
                screen = Screen.History
            },
            onSettings = { screen = Screen.Settings },
            onRevoke = {
                trustedPeerRepository.revoke(it)
                reloadPeers()
            },
            onPair = { screen = Screen.Pair },
            onDevice = {
                selectedDevice = it
                screen = Screen.DeviceDetail
            },
        )

        Screen.DeviceDetail -> DeviceDetailScreen(
            peer = selectedDevice,
            onBack = ::goBack,
            onRevoke = {
                selectedDevice?.let { trustedPeerRepository.revoke(it.deviceId) }
                reloadPeers()
                screen = Screen.Devices
            },
        )

        Screen.Permissions -> PermissionExplanationScreen(
            onBack = ::goBack,
        )

        Screen.SendText -> SendTextScreen(
            peers = peers,
            onBack = ::goBack,
            onSendText = { peer, text ->
                transferManager.sendText(peer, text)
                reloadHistory()
                screen = Screen.History
            },
            onSendUrl = { peer, url ->
                transferManager.sendUrl(peer, url)
                reloadHistory()
                screen = Screen.History
            },
        )

        Screen.SendFile -> SendFileScreen(
            peers = peers,
            transferManager = transferManager,
            onBack = ::goBack,
            onProgress = { progress = it },
            onDone = {
                reloadHistory()
                screen = Screen.History
            },
        )

        Screen.History -> TransferHistoryScreen(
            history = history,
            progress = progress,
            onBack = ::goBack,
            onHome = { screen = Screen.Home },
            onDevices = { screen = Screen.Devices },
            onSettings = { screen = Screen.Settings },
            onCancel = {
                transferManager.cancelTransfer(it)
                reloadHistory()
            },
        )

        Screen.Settings -> SettingsScreen(
            onBack = ::goBack,
            onHome = { screen = Screen.Home },
            onDevices = { screen = Screen.Devices },
            onHistory = {
                reloadHistory()
                screen = Screen.History
            },
            onPrivacy = { screen = Screen.Privacy },
            onDiagnostics = { screen = Screen.Diagnostics },
            onPermissions = { screen = Screen.Permissions },
            onAbout = { screen = Screen.About },
        )

        Screen.Privacy -> PrivacyScreen(onBack = ::goBack)

        Screen.Diagnostics -> NetworkDiagnosticsScreen(
            onBack = ::goBack,
            onPair = { screen = Screen.Pair },
        )

        Screen.About -> AboutScreen(onBack = ::goBack)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun HomeScreen(
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
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("BeamDrop") },
                actions = {
                    IconButton(onClick = onSettings) {
                        Icon(Icons.Outlined.Security, contentDescription = "Settings")
                    }
                },
            )
        },
        bottomBar = {
            BeamDropBottomBar(
                current = Screen.Home,
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
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            item {
                SectionSurface {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Image(
                            painter = painterResource(id = R.drawable.beamdrop_logo),
                            contentDescription = "BeamDrop logo",
                            modifier = Modifier.size(44.dp),
                        )
                        Column {
                            Text("Ready to send", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                            Text(
                                if (trustedCount == 0) "Pair a device to start" else "$trustedCount trusted ${if (trustedCount == 1) "device" else "devices"}",
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
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
                    Spacer(Modifier.height(14.dp))
                    Button(onClick = { onNameSaved(name) }) {
                        Text("Save name")
                    }
                }
            }

            item {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
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
            }

            item {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
                    OutlinedButton(onClick = onSendClipboard, modifier = Modifier.weight(1f)) {
                        Icon(Icons.Outlined.ContentPaste, contentDescription = null)
                        Spacer(Modifier.size(8.dp))
                        Text("Paste")
                    }
                    OutlinedButton(onClick = onHistory, modifier = Modifier.weight(1f)) {
                        Icon(Icons.Outlined.History, contentDescription = null)
                        Spacer(Modifier.size(8.dp))
                        Text("Activity")
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
                    Button(onClick = onPair, modifier = Modifier.weight(1f)) {
                        Icon(Icons.Outlined.QrCode, contentDescription = null)
                        Spacer(Modifier.size(8.dp))
                        Text("Show my QR")
                    }
                    OutlinedButton(onClick = onScan, modifier = Modifier.weight(1f)) {
                        Icon(Icons.Outlined.QrCodeScanner, contentDescription = null)
                        Spacer(Modifier.size(8.dp))
                        Text("Scan QR")
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
                    OutlinedButton(onClick = onSettings, modifier = Modifier.weight(1f)) {
                        Icon(Icons.Outlined.Security, contentDescription = null)
                        Spacer(Modifier.size(8.dp))
                        Text("Settings")
                    }
                }
            }

            item {
                SectionSurface {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Outlined.Devices, contentDescription = null)
                        Spacer(Modifier.size(10.dp))
                        Text("Your devices", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                    }
                    Spacer(Modifier.height(12.dp))
                    if (peers.none { it.trustState == TrustState.Trusted }) {
                        EmptyDevices(onPair, onScan)
                    } else {
                        peers.filter { it.trustState == TrustState.Trusted }.take(3).forEach { PeerRow(it) }
                        TextButton(onClick = onDevices) { Text("Manage trusted devices") }
                    }
                }
            }

            item {
                OutlinedButton(onClick = onPermissions, modifier = Modifier.fillMaxWidth()) {
                    Icon(Icons.Outlined.Security, contentDescription = null)
                    Spacer(Modifier.size(8.dp))
                    Text("Permissions and connection help")
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

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun OnboardingScreen(onBack: () -> Unit, onPair: () -> Unit) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Onboarding") },
                navigationIcon = { TextButton(onClick = onBack) { Text("Back") } },
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
            item {
                SectionSurface(horizontalAlignment = Alignment.CenterHorizontally) {
                    Image(
                        painter = painterResource(id = R.drawable.beamdrop_logo),
                        contentDescription = "BeamDrop logo",
                        modifier = Modifier.size(72.dp),
                    )
                    Spacer(Modifier.height(12.dp))
                    Text("BeamDrop", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
                    Text("Private local transfer for trusted devices.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            item { SectionSurface { Text("Private Local Transfer", fontWeight = FontWeight.SemiBold); Text("Send text and files between devices you trust without requiring login or cloud upload.", color = MaterialTheme.colorScheme.onSurfaceVariant) } }
            item { SectionSurface { Text("Pair With QR", fontWeight = FontWeight.SemiBold); Text("Trust is explicit. Unknown devices cannot send content until approved.", color = MaterialTheme.colorScheme.onSurfaceVariant) } }
            item { SectionSurface { Text("Clipboard Is Manual", fontWeight = FontWeight.SemiBold); Text("Android clipboard sending is user-triggered and respects platform restrictions.", color = MaterialTheme.colorScheme.onSurfaceVariant) } }
            item {
                Button(onClick = onPair, modifier = Modifier.fillMaxWidth()) {
                    Text("Pair First Device")
                }
            }
        }
    }
}

@Composable
private fun EmptyDevices(onPair: () -> Unit, onScan: () -> Unit) {
    Text("Connect another device", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
    Text(
        "Scan a BeamDrop QR code or show this phone's QR. You approve before anything is trusted.",
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
    Spacer(Modifier.height(12.dp))
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Button(onClick = onScan) { Text("Scan QR") }
        OutlinedButton(onClick = onPair) { Text("Show my QR") }
    }
}

@Composable
private fun BeamDropBottomBar(
    current: Screen,
    onHome: () -> Unit,
    onDevices: () -> Unit,
    onHistory: () -> Unit,
    onSettings: () -> Unit,
) {
    NavigationBar {
        NavigationBarItem(
            selected = current == Screen.Home,
            onClick = onHome,
            icon = { Icon(Icons.Outlined.QrCode, contentDescription = null) },
            label = { Text("Home") },
        )
        NavigationBarItem(
            selected = current == Screen.Devices,
            onClick = onDevices,
            icon = { Icon(Icons.Outlined.Devices, contentDescription = null) },
            label = { Text("Devices") },
        )
        NavigationBarItem(
            selected = current == Screen.History,
            onClick = onHistory,
            icon = { Icon(Icons.Outlined.History, contentDescription = null) },
            label = { Text("History") },
        )
        NavigationBarItem(
            selected = current == Screen.Settings,
            onClick = onSettings,
            icon = { Icon(Icons.Outlined.Security, contentDescription = null) },
            label = { Text("Settings") },
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun NearbyDevicesScreen(
    onBack: () -> Unit,
    onPair: () -> Unit,
    onDiagnostics: () -> Unit,
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Nearby Devices") },
                navigationIcon = { TextButton(onClick = onBack) { Text("Back") } },
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
            item {
                SectionSurface {
                    Text("No devices found", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                    Text(
                        "BeamDrop looks for ${com.beamdrop.android.core.pairing.BEAMDROP_SERVICE_NAME} on your local network. Public Wi-Fi, guest networks, VPNs, and corporate client isolation can block discovery.",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Spacer(Modifier.height(12.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        Button(onClick = onPair) { Text("Pair With QR") }
                        OutlinedButton(onClick = onDiagnostics) { Text("Run Diagnostics") }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PairNewDeviceScreen(
    state: PairNewDeviceUiState,
    onBack: () -> Unit,
    onRefresh: () -> Unit,
    onScan: () -> Unit,
) {
    val qrBitmap = remember(state.qrPayload) { QrCodeBitmap.create(state.qrPayload) }
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Pair new device") },
                navigationIcon = { TextButton(onClick = onBack) { Text("Close") } },
                actions = {
                    IconButton(onClick = onRefresh) {
                        Icon(Icons.Outlined.Refresh, contentDescription = "Refresh QR")
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
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            item {
                SectionSurface(horizontalAlignment = Alignment.CenterHorizontally) {
                    Image(
                        painter = painterResource(id = R.drawable.beamdrop_logo),
                        contentDescription = "BeamDrop logo",
                        modifier = Modifier.size(64.dp),
                    )
                    Spacer(Modifier.height(12.dp))
                    Text(state.identity.displayName, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
                    Text("Android · protocol v${state.identity.protocolVersion}", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(Modifier.height(16.dp))
                    Surface(
                        shape = RoundedCornerShape(8.dp),
                        color = Color.White,
                        shadowElevation = 1.dp,
                    ) {
                        Image(
                            bitmap = qrBitmap,
                            contentDescription = "BeamDrop pairing QR code",
                            modifier = Modifier
                                .padding(14.dp)
                                .size(260.dp),
                        )
                    }
                    Spacer(Modifier.height(12.dp))
                    AssistChip(onClick = {}, label = { Text(state.endpointLabel) })
                    Text(
                        "QR includes device ID, public key, protocol version, service name, and endpoint status. It expires automatically.",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }

            item {
                Button(onClick = onScan, modifier = Modifier.fillMaxWidth()) {
                    Icon(Icons.Outlined.QrCodeScanner, contentDescription = null)
                    Spacer(Modifier.size(8.dp))
                    Text("Scan another BeamDrop QR")
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ScanQrScreen(
    controller: ScanQrController,
    onBack: () -> Unit,
    onTrusted: () -> Unit,
) {
    var state by remember { mutableStateOf(controller.state) }
    var rawQr by remember { mutableStateOf("") }
    val context = LocalContext.current
    var cameraGrant by remember {
        mutableStateOf(
            if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
                RuntimePermissionGrant.Granted
            } else {
                null
            },
        )
    }
    val cameraLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        cameraGrant = if (granted) RuntimePermissionGrant.Granted else RuntimePermissionGrant.Denied
        if (granted) {
            controller.markCameraReady()
            state = controller.state
        }
    }

    if (state is ScanQrUiState.PendingApproval) {
        PairingApprovalDialog(
            request = (state as ScanQrUiState.PendingApproval).request,
            onApprove = {
                state = controller.approveCurrentRequest()
                if (state is ScanQrUiState.Trusted) onTrusted()
            },
            onReject = { state = controller.rejectCurrentRequest() },
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Scan QR code") },
                navigationIcon = { TextButton(onClick = onBack) { Text("Close") } },
            )
        },
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .background(MaterialTheme.colorScheme.background)
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            item {
                PermissionCameraCard(
                    grant = cameraGrant,
                    onRequest = { cameraLauncher.launch(Manifest.permission.CAMERA) },
                )
            }

            if (cameraGrant == RuntimePermissionGrant.Granted) {
                item {
                    SectionSurface {
                        Text("Point your camera at a BeamDrop QR", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                        Text(
                            "When a valid code is found, BeamDrop will show the device name and ask you to approve it.",
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Spacer(Modifier.height(12.dp))
                        QrCameraScanner(
                            onQrCode = { scanned ->
                                state = controller.handleScannedText(scanned)
                            },
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(320.dp),
                        )
                    }
                }
            }

            item {
                SectionSurface {
                    Text("Paste pairing code", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                    Text(
                        "Use this fallback if the camera cannot read the QR or another device shared the code as text.",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Spacer(Modifier.height(12.dp))
                    OutlinedTextField(
                        value = rawQr,
                        onValueChange = { rawQr = it },
                        label = { Text("BeamDrop QR payload") },
                        minLines = 4,
                        modifier = Modifier.fillMaxWidth(),
                    )
                    Spacer(Modifier.height(12.dp))
                    Button(
                        onClick = { state = controller.handleScannedText(rawQr) },
                        enabled = rawQr.isNotBlank(),
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text("Validate pairing QR")
                    }
                }
            }

            item {
                ScanStateMessage(state)
            }
        }
    }
}

@Composable
private fun PermissionCameraCard(
    grant: RuntimePermissionGrant?,
    onRequest: () -> Unit,
) {
    SectionSurface {
        Text("Camera permission", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        Text(
            "BeamDrop uses the camera only when you scan a QR code. Pairing still requires approval before trust is saved.",
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.height(12.dp))
        when (grant) {
            RuntimePermissionGrant.Granted -> AssistChip(onClick = {}, label = { Text("Camera ready") })
            RuntimePermissionGrant.Denied -> ErrorText("Camera denied. Use manual payload entry or enable camera in Android settings.")
            RuntimePermissionGrant.ShowRationale, null -> Button(onClick = onRequest) { Text("Allow camera") }
        }
    }
}

@Composable
private fun QrCameraScanner(
    onQrCode: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val executor = remember { Executors.newSingleThreadExecutor() }
    val didScan = remember { AtomicBoolean(false) }

    DisposableEffect(Unit) {
        onDispose {
            executor.shutdown()
        }
    }

    AndroidView(
        modifier = modifier,
        factory = { viewContext ->
            val previewView = PreviewView(viewContext).apply {
                scaleType = PreviewView.ScaleType.FILL_CENTER
            }
            val cameraProviderFuture = ProcessCameraProvider.getInstance(viewContext)
            cameraProviderFuture.addListener(
                {
                    val cameraProvider = cameraProviderFuture.get()
                    val preview = Preview.Builder().build().also {
                        it.setSurfaceProvider(previewView.surfaceProvider)
                    }
                    val analysis = ImageAnalysis.Builder()
                        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                        .build()
                        .also { imageAnalysis ->
                            imageAnalysis.setAnalyzer(executor) { image ->
                                val result = decodeQrCode(image)
                                image.close()
                                if (result != null && didScan.compareAndSet(false, true)) {
                                    Handler(Looper.getMainLooper()).post { onQrCode(result) }
                                }
                            }
                        }

                    runCatching {
                        cameraProvider.unbindAll()
                        cameraProvider.bindToLifecycle(
                            lifecycleOwner,
                            CameraSelector.DEFAULT_BACK_CAMERA,
                            preview,
                            analysis,
                        )
                    }.onFailure { error ->
                        Log.w("BeamDropQrScanner", "Camera scanner could not start: ${error.message}")
                    }
                },
                ContextCompat.getMainExecutor(context),
            )
            previewView
        },
    )
}

private fun decodeQrCode(image: ImageProxy): String? {
    val luminance = image.toLuminanceBytes()
    val source = PlanarYUVLuminanceSource(
        luminance,
        image.width,
        image.height,
        0,
        0,
        image.width,
        image.height,
        false,
    )
    val bitmap = BinaryBitmap(HybridBinarizer(source))
    val reader = MultiFormatReader().apply {
        setHints(
            mapOf(
                DecodeHintType.POSSIBLE_FORMATS to listOf(BarcodeFormat.QR_CODE),
                DecodeHintType.TRY_HARDER to true,
            ),
        )
    }
    return try {
        reader.decode(bitmap).text
    } catch (_: NotFoundException) {
        null
    } catch (error: Exception) {
        Log.w("BeamDropQrScanner", "QR decode failed: ${error.message}")
        null
    } finally {
        reader.reset()
    }
}

private fun ImageProxy.toLuminanceBytes(): ByteArray {
    val plane = planes.first()
    val buffer = plane.buffer
    val rowStride = plane.rowStride
    val pixelStride = plane.pixelStride
    val data = ByteArray(width * height)
    val row = ByteArray(rowStride)
    var outputOffset = 0

    for (y in 0 until height) {
        buffer.position(y * rowStride)
        val bytesToRead = minOf(rowStride, buffer.remaining())
        buffer.get(row, 0, bytesToRead)
        var inputOffset = 0
        for (x in 0 until width) {
            data[outputOffset++] = row[inputOffset]
            inputOffset += pixelStride
        }
    }

    return data
}

@Composable
private fun PairingApprovalDialog(
    request: com.beamdrop.android.core.pairing.PairingRequest,
    onApprove: () -> Unit,
    onReject: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onReject,
        title = { Text("Trust this device?") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(request.remoteDevice.displayName, fontWeight = FontWeight.SemiBold)
                Text("Platform: ${request.remoteDevice.platform.wireName}")
                Text("Fingerprint: ${request.fingerprint}")
                Text("Trust status: pairing approval required")
                Text("Unknown devices cannot transfer until you approve pairing.")
            }
        },
        confirmButton = { Button(onClick = onApprove) { Text("Approve") } },
        dismissButton = { TextButton(onClick = onReject) { Text("Reject") } },
    )
}

@Composable
private fun ScanStateMessage(state: ScanQrUiState) {
    when (state) {
        ScanQrUiState.NeedsCameraPermissionExplanation ->
            InfoText("Grant camera permission or paste a BeamDrop QR payload.")

        ScanQrUiState.Ready ->
            InfoText("Ready to scan. No trust will be stored until you approve.")

        is ScanQrUiState.PendingApproval ->
            InfoText("Pairing request pending approval.")

        is ScanQrUiState.Trusted ->
            InfoText("${state.peer.displayName} is now trusted.")

        is ScanQrUiState.Error ->
            ErrorText(state.error.userMessage())
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun TrustedDevicesScreen(
    peers: List<TrustedPeer>,
    onBack: () -> Unit,
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
                navigationIcon = { TextButton(onClick = onBack) { Text("Back") } },
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
                        EmptyDevices(onPair = onPair, onScan = onPair)
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
private fun DeviceDetailScreen(
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
                navigationIcon = { TextButton(onClick = onBack) { Text("Back") } },
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

@Composable
private fun PeerRow(peer: TrustedPeer) {
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

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PermissionExplanationScreen(onBack: () -> Unit) {
    val planned = remember {
        PermissionPlanner.planForSdk(Build.VERSION.SDK_INT, activeTransferProgress = false)
            .map { PermissionStateMapper.map(it, grant = null) }
    }
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Permissions") },
                navigationIcon = { TextButton(onClick = onBack) { Text("Back") } },
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
            items(planned) { permission ->
                SectionSurface {
                    Text(permission.permission.title, fontWeight = FontWeight.SemiBold)
                    Text(permission.explanation, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(Modifier.height(8.dp))
                    AssistChip(onClick = {}, label = { Text(permission.status.label()) })
                }
            }
            item {
                SectionSurface {
                    Text("Bluetooth", fontWeight = FontWeight.SemiBold)
                    Text(
                        "Not requested for the current local QR and Wi-Fi discovery flow. It can be added later if a Bluetooth transport is implemented.",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}

@Composable
private fun SectionSurface(
    modifier: Modifier = Modifier,
    horizontalAlignment: Alignment.Horizontal = Alignment.Start,
    content: @Composable ColumnScope.() -> Unit,
) {
    Surface(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(8.dp),
        color = MaterialTheme.colorScheme.surface,
        tonalElevation = 1.dp,
        shadowElevation = 0.dp,
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            horizontalAlignment = horizontalAlignment,
            content = content,
        )
    }
}

@Composable
private fun InfoText(text: String) {
    Text(text, color = MaterialTheme.colorScheme.onSurfaceVariant)
}

@Composable
private fun ErrorText(text: String) {
    Text(text, color = MaterialTheme.colorScheme.error, fontWeight = FontWeight.SemiBold)
}

private fun PairingError.userMessage(): String = when (this) {
    PairingError.LocalNetworkPermissionDenied -> "Local network permission denied. Enable nearby Wi-Fi access to discover devices."
    PairingError.NoDevicesFound -> "No BeamDrop devices found. Try QR pairing, manual endpoint entry, or network diagnostics."
    PairingError.QrInvalid -> "QR invalid. Scan a current BeamDrop pairing QR code."
    PairingError.QrExpired -> "QR expired. Ask the other device to refresh its QR code."
    PairingError.PairingRejected -> "Pairing rejected. No trust was stored."
    PairingError.DeviceAlreadyTrusted -> "Device already trusted. Open trusted devices to view it."
    PairingError.ProtocolUnsupported -> "Protocol mismatch. One BeamDrop app needs to be updated."
    PairingError.ServiceNameMismatch -> "QR is not for the BeamDrop local service."
    PairingError.DevicePreviouslyRevoked -> "This device was revoked. Re-pairing requires deliberate approval."
}

private fun PermissionStatus.label(): String = when (this) {
    PermissionStatus.Granted -> "Granted"
    PermissionStatus.NeedsRequest -> "Request when needed"
    PermissionStatus.NeedsRationale -> "Needs explanation"
    PermissionStatus.Denied -> "Denied"
    PermissionStatus.NotRequired -> "Not required on this Android version"
    PermissionStatus.ManifestOnly -> "Declared in manifest"
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SendTextScreen(
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
                navigationIcon = { TextButton(onClick = onBack) { Text("Back") } },
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
private fun SendFileScreen(
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
                navigationIcon = { TextButton(onClick = onBack) { Text("Back") } },
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
private fun TransferHistoryScreen(
    history: List<TransferHistoryRecord>,
    progress: TransferProgress?,
    onBack: () -> Unit,
    onCancel: (String) -> Unit,
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Transfer History") },
                navigationIcon = { TextButton(onClick = onBack) { Text("Back") } },
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

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SettingsScreen(
    onBack: () -> Unit,
    onPrivacy: () -> Unit,
    onDiagnostics: () -> Unit,
    onPermissions: () -> Unit,
    onAbout: () -> Unit,
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Settings") },
                navigationIcon = { TextButton(onClick = onBack) { Text("Back") } },
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
            item {
                SectionSurface {
                    Text("Transfer Defaults", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                    Text("Auto-accept is off by default. Only trusted devices can be considered for future auto-accept rules.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            item { SettingsRow("Privacy", "Clipboard and trust behavior.", onPrivacy) }
            item { SettingsRow("Permissions", "Camera, notifications, and local network explanations.", onPermissions) }
            item { SettingsRow("Network Diagnostics", "Troubleshoot Bonjour, Wi-Fi isolation, VPNs, and manual QR fallback.", onDiagnostics) }
            item { SettingsRow("About", "Version, native stack, and release status.", onAbout) }
        }
    }
}

@Composable
private fun SettingsRow(title: String, detail: String, onClick: () -> Unit) {
    SectionSurface {
        Text(title, fontWeight = FontWeight.SemiBold)
        Text(detail, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.height(8.dp))
        OutlinedButton(onClick = onClick) { Text("Open") }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PrivacyScreen(onBack: () -> Unit) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Privacy") },
                navigationIcon = { TextButton(onClick = onBack) { Text("Back") } },
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
            item { SectionSurface { Text("Local-First", fontWeight = FontWeight.SemiBold); Text("BeamDrop sends over the local network when possible and does not require login or cloud upload for local MVP transfers.", color = MaterialTheme.colorScheme.onSurfaceVariant) } }
            item { SectionSurface { Text("Clipboard", fontWeight = FontWeight.SemiBold); Text("Android clipboard sending is manual and user-triggered. BeamDrop does not hide background clipboard monitoring behind a service.", color = MaterialTheme.colorScheme.onSurfaceVariant) } }
            item { SectionSurface { Text("Device Trust", fontWeight = FontWeight.SemiBold); Text("Unknown devices are rejected. Revoked devices are blocked before content is accepted.", color = MaterialTheme.colorScheme.onSurfaceVariant) } }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun NetworkDiagnosticsScreen(onBack: () -> Unit, onPair: () -> Unit) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Network Diagnostics") },
                navigationIcon = { TextButton(onClick = onBack) { Text("Back") } },
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
            item { SectionSurface { Text("Local Address", fontWeight = FontWeight.SemiBold); Text(LocalNetworkAddress.firstUsableIpv4Address() ?: "No usable local IPv4 address found.", color = MaterialTheme.colorScheme.onSurfaceVariant) } }
            item { SectionSurface { Text("Discovery Service", fontWeight = FontWeight.SemiBold); Text("${com.beamdrop.android.core.pairing.BEAMDROP_SERVICE_NAME} may be blocked by public Wi-Fi, guest networks, VPNs, or corporate isolation.", color = MaterialTheme.colorScheme.onSurfaceVariant) } }
            item { SectionSurface { Text("Manual Fallback", fontWeight = FontWeight.SemiBold); Text("Use QR pairing when discovery fails. Security rules stay the same.", color = MaterialTheme.colorScheme.onSurfaceVariant); Spacer(Modifier.height(8.dp)); Button(onClick = onPair) { Text("Pair With QR") } } }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AboutScreen(onBack: () -> Unit) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("About") },
                navigationIcon = { TextButton(onClick = onBack) { Text("Back") } },
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
            item {
                SectionSurface(horizontalAlignment = Alignment.CenterHorizontally) {
                    Image(
                        painter = painterResource(id = R.drawable.beamdrop_logo),
                        contentDescription = "BeamDrop logo",
                        modifier = Modifier.size(72.dp),
                    )
                    Spacer(Modifier.height(12.dp))
                    Text("BeamDrop For Android", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                    Text("Native Kotlin and Jetpack Compose app for private local transfer between trusted devices.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            item { SectionSurface { Text("Release Status", fontWeight = FontWeight.SemiBold); Text("MVP development. Production downloads will be published after signing, verification, and release testing.", color = MaterialTheme.colorScheme.onSurfaceVariant) } }
        }
    }
}

@Composable
private fun TransferProgressCard(
    progress: TransferProgress,
    onCancel: () -> Unit,
) {
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
        OutlinedButton(onClick = onCancel) {
            Icon(Icons.Outlined.StopCircle, contentDescription = null)
            Spacer(Modifier.size(8.dp))
            Text("Cancel")
        }
    }
}

@Composable
private fun ReceiveApprovalPromptDialog(
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
private fun PeerChoiceList(
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

@Composable
private fun HistoryRow(record: TransferHistoryRecord) {
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

private object ManualReceiveApprovalPrompt : ReceiveApprovalPrompt {
    override fun decide(request: IncomingTransferRequest): ReceiveDecision = ReceiveDecision.Reject
}

private fun List<TrustedPeer>.trustedTransferPeers(): List<TransferPeer> =
    filter { it.trustState == TrustState.Trusted }.map { it.toTransferPeer() }

private fun List<TrustedPeer>.firstTrustedTransferPeer(): TransferPeer? =
    trustedTransferPeers().firstOrNull()

private fun TrustedPeer.toTransferPeer(): TransferPeer = TransferPeer(
    deviceId = deviceId,
    displayName = displayName,
    platform = platform,
    publicKey = publicKey,
    endpointHost = endpoint?.host,
    endpointPort = endpoint?.port,
    autoAcceptTransfers = false,
)

private object LocalNetworkAddress {
    fun firstUsableIpv4Address(): String? = runCatching {
        java.net.NetworkInterface.getNetworkInterfaces().asSequence()
            .filter { it.isUp && !it.isLoopback }
            .flatMap { it.inetAddresses.asSequence() }
            .filterIsInstance<java.net.Inet4Address>()
            .mapNotNull { it.hostAddress }
            .firstOrNull { !it.startsWith("127.") && !it.startsWith("169.254.") }
    }.getOrNull()
}

private fun formatBytes(bytes: Long): String {
    val units = listOf("B", "KB", "MB", "GB")
    var value = bytes.toDouble()
    var unit = 0
    while (value >= 1024 && unit < units.lastIndex) {
        value /= 1024
        unit++
    }
    return if (unit == 0) "${bytes} B" else "%.1f %s".format(value, units[unit])
}

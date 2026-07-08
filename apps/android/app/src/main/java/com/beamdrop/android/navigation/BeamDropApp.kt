package com.beamdrop.android.navigation

import androidx.activity.compose.BackHandler
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.beamdrop.android.core.clipboard.ClipboardSendResult
import com.beamdrop.android.core.clipboard.ManualClipboardSender
import com.beamdrop.android.core.identity.DeviceIdentityRepository
import com.beamdrop.android.core.identity.DeviceNameRepository
import com.beamdrop.android.core.notifications.TransferNotificationActions
import com.beamdrop.android.core.pairing.EndpointHint
import com.beamdrop.android.core.pairing.PairingCodec
import com.beamdrop.android.core.pairing.PairingSessionFactory
import com.beamdrop.android.core.pairing.PairingValidator
import com.beamdrop.android.core.pairing.TrustedPeer
import com.beamdrop.android.core.storage.TrustedPeerRepository
import com.beamdrop.android.core.transfer.DEFAULT_TRANSFER_PORT
import com.beamdrop.android.core.transfer.SharedPreferencesTransferHistoryStore
import com.beamdrop.android.core.transfer.TransferManager
import com.beamdrop.android.core.transfer.TransferProgress
import com.beamdrop.android.ui.devices.DeviceDetailScreen
import com.beamdrop.android.ui.devices.TrustedDevicesScreen
import com.beamdrop.android.ui.home.HomeScreen
import com.beamdrop.android.ui.nearby.NearbyDevicesScreen
import com.beamdrop.android.ui.onboarding.OnboardingScreen
import com.beamdrop.android.ui.pairing.PairNewDevicePresenter
import com.beamdrop.android.ui.pairing.PairNewDeviceScreen
import com.beamdrop.android.ui.pairing.ScanQrController
import com.beamdrop.android.ui.pairing.ScanQrScreen
import com.beamdrop.android.ui.settings.AboutScreen
import com.beamdrop.android.ui.settings.NetworkDiagnosticsScreen
import com.beamdrop.android.ui.settings.PermissionExplanationScreen
import com.beamdrop.android.ui.settings.PrivacyScreen
import com.beamdrop.android.ui.settings.SettingsScreen
import com.beamdrop.android.ui.transfer.SendFileScreen
import com.beamdrop.android.ui.transfer.SendTextScreen
import com.beamdrop.android.ui.transfer.TransferHistoryScreen
import com.beamdrop.android.ui.transfer.firstTrustedTransferPeer
import com.beamdrop.android.ui.transfer.toTransferPeer
import com.beamdrop.android.ui.util.LocalNetworkAddress

@Composable
internal fun BeamDropApp(
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
            if (startupAction == TransferNotificationActions.ACTION_SEND_CLIPBOARD) {
                BeamDropDestination.SendText
            } else {
                BeamDropDestination.Home
            },
        )
    }
    var identity by remember { mutableStateOf(identityRepository.getOrCreateIdentity()) }
    var peers by remember { mutableStateOf(trustedPeerRepository.listPeers()) }
    var history by remember { mutableStateOf(historyStore.list()) }
    var progress by remember { mutableStateOf<TransferProgress?>(null) }
    var refreshPairing by remember { mutableIntStateOf(0) }
    var selectedDevice by remember { mutableStateOf<TrustedPeer?>(null) }
    var clipboardMessage by remember { mutableStateOf<String?>(null) }
    var previousScreen by remember { mutableStateOf<BeamDropDestination?>(null) }

    fun reloadPeers() {
        peers = trustedPeerRepository.listPeers()
    }

    fun reloadHistory() {
        history = historyStore.list()
    }

    fun localEndpoint(): EndpointHint = EndpointHint(
        host = LocalNetworkAddress.firstUsableIpv4Address(),
        port = DEFAULT_TRANSFER_PORT,
        route = "local",
    )

    fun navigate(target: BeamDropDestination) {
        if (screen != target) {
            previousScreen = screen
            screen = target
        }
    }

    fun navigateTop(target: BeamDropDestination) {
        previousScreen = null
        screen = target
    }

    fun goBack() {
        screen = when (screen) {
            BeamDropDestination.Home -> BeamDropDestination.Home
            BeamDropDestination.Devices,
            BeamDropDestination.History,
            BeamDropDestination.Settings,
            -> BeamDropDestination.Home
            BeamDropDestination.DeviceDetail -> BeamDropDestination.Devices
            BeamDropDestination.Privacy,
            BeamDropDestination.Diagnostics,
            BeamDropDestination.About,
            -> previousScreen ?: BeamDropDestination.Settings
            else -> previousScreen ?: BeamDropDestination.Home
        }
        previousScreen = null
    }

    BackHandler(enabled = screen != BeamDropDestination.Home) {
        goBack()
    }

    when (screen) {
        BeamDropDestination.Home -> HomeScreen(
            identity = identity,
            peers = peers,
            history = history,
            clipboardMessage = clipboardMessage,
            onPair = { navigate(BeamDropDestination.Pair) },
            onScan = { navigate(BeamDropDestination.Scan) },
            onNearby = { navigate(BeamDropDestination.Nearby) },
            onDevices = { navigateTop(BeamDropDestination.Devices) },
            onPermissions = { navigate(BeamDropDestination.Permissions) },
            onSendText = { navigate(BeamDropDestination.SendText) },
            onSendFile = { navigate(BeamDropDestination.SendFile) },
            onSettings = { navigateTop(BeamDropDestination.Settings) },
            onAbout = { navigate(BeamDropDestination.About) },
            onOnboarding = { navigate(BeamDropDestination.Onboarding) },
            onHistory = {
                reloadHistory()
                navigateTop(BeamDropDestination.History)
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

        BeamDropDestination.Onboarding -> OnboardingScreen(
            onBack = ::goBack,
            onPair = { navigate(BeamDropDestination.Pair) },
        )

        BeamDropDestination.Nearby -> NearbyDevicesScreen(
            onBack = ::goBack,
            onPair = { navigate(BeamDropDestination.Pair) },
            onDiagnostics = { navigate(BeamDropDestination.Diagnostics) },
        )

        BeamDropDestination.Pair -> PairNewDeviceScreen(
            state = remember(identity, refreshPairing) {
                PairNewDevicePresenter(PairingSessionFactory()).buildState(
                    identity,
                    endpoint = EndpointHint(
                        host = LocalNetworkAddress.firstUsableIpv4Address(),
                        port = DEFAULT_TRANSFER_PORT,
                        route = "local",
                    ),
                )
            },
            onBack = ::goBack,
            onRefresh = { refreshPairing++ },
            onScan = { navigate(BeamDropDestination.Scan) },
        )

        BeamDropDestination.Scan -> ScanQrScreen(
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
            onTrusted = { peer ->
                reloadPeers()
                runCatching {
                    val payload = PairingCodec.encode(
                        PairingSessionFactory().createPayload(identity, endpoint = localEndpoint()),
                    )
                    transferManager.sendPairingRequest(peer.toTransferPeer(), payload)
                    reloadHistory()
                }.onFailure {
                    clipboardMessage = "Device trusted locally, but the other device did not receive the pairing request: ${it.message}"
                }
                navigateTop(BeamDropDestination.Devices)
            },
        )

        BeamDropDestination.Devices -> TrustedDevicesScreen(
            peers = peers,
            onHome = { navigateTop(BeamDropDestination.Home) },
            onHistory = {
                reloadHistory()
                navigateTop(BeamDropDestination.History)
            },
            onSettings = { navigateTop(BeamDropDestination.Settings) },
            onScan = { navigate(BeamDropDestination.Scan) },
            onRevoke = {
                trustedPeerRepository.revoke(it)
                reloadPeers()
            },
            onPair = { navigate(BeamDropDestination.Pair) },
            onDevice = {
                selectedDevice = it
                navigate(BeamDropDestination.DeviceDetail)
            },
        )

        BeamDropDestination.DeviceDetail -> DeviceDetailScreen(
            peer = selectedDevice,
            onBack = ::goBack,
            onRevoke = {
                selectedDevice?.let { trustedPeerRepository.revoke(it.deviceId) }
                reloadPeers()
                navigateTop(BeamDropDestination.Devices)
            },
        )

        BeamDropDestination.Permissions -> PermissionExplanationScreen(
            onBack = ::goBack,
        )

        BeamDropDestination.SendText -> SendTextScreen(
            peers = peers,
            onBack = ::goBack,
            onSendText = { peer, text ->
                transferManager.sendText(peer, text)
                reloadHistory()
                navigateTop(BeamDropDestination.History)
            },
            onSendUrl = { peer, url ->
                transferManager.sendUrl(peer, url)
                reloadHistory()
                navigateTop(BeamDropDestination.History)
            },
        )

        BeamDropDestination.SendFile -> SendFileScreen(
            peers = peers,
            transferManager = transferManager,
            onBack = ::goBack,
            onProgress = { progress = it },
            onDone = {
                reloadHistory()
                navigateTop(BeamDropDestination.History)
            },
        )

        BeamDropDestination.History -> TransferHistoryScreen(
            history = history,
            progress = progress,
            onHome = { navigateTop(BeamDropDestination.Home) },
            onDevices = { navigateTop(BeamDropDestination.Devices) },
            onSettings = { navigateTop(BeamDropDestination.Settings) },
            onCancel = {
                transferManager.cancelTransfer(it)
                reloadHistory()
            },
        )

        BeamDropDestination.Settings -> SettingsScreen(
            onHome = { navigateTop(BeamDropDestination.Home) },
            onDevices = { navigateTop(BeamDropDestination.Devices) },
            onHistory = {
                reloadHistory()
                navigateTop(BeamDropDestination.History)
            },
            onPrivacy = { navigate(BeamDropDestination.Privacy) },
            onDiagnostics = { navigate(BeamDropDestination.Diagnostics) },
            onPermissions = { navigate(BeamDropDestination.Permissions) },
            onAbout = { navigate(BeamDropDestination.About) },
        )

        BeamDropDestination.Privacy -> PrivacyScreen(onBack = ::goBack)

        BeamDropDestination.Diagnostics -> NetworkDiagnosticsScreen(
            onBack = ::goBack,
            onPair = { navigate(BeamDropDestination.Pair) },
        )

        BeamDropDestination.About -> AboutScreen(onBack = ::goBack)
    }
}

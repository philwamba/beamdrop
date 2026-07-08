package com.beamdrop.android

import android.content.ClipboardManager
import android.content.Context
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import com.beamdrop.android.core.clipboard.ManualClipboardSender
import com.beamdrop.android.core.crypto.SessionTransferEncryption
import com.beamdrop.android.core.identity.DeviceIdentityRepository
import com.beamdrop.android.core.identity.DeviceNameRepository
import com.beamdrop.android.core.storage.SharedPreferencesTrustedPeerStore
import com.beamdrop.android.core.storage.TrustedPeerRepository
import com.beamdrop.android.core.transfer.AppPrivateReceiveTargetFactory
import com.beamdrop.android.core.transfer.DEFAULT_TRANSFER_PORT
import com.beamdrop.android.core.transfer.IncomingTransferRequest
import com.beamdrop.android.core.transfer.PeerTrustPolicy
import com.beamdrop.android.core.transfer.ReceiveApprovalPrompt
import com.beamdrop.android.core.transfer.ReceiveDecision
import com.beamdrop.android.core.transfer.SharedPreferencesTransferHistoryStore
import com.beamdrop.android.core.transfer.SocketTransferTransport
import com.beamdrop.android.core.transfer.TcpIncomingTransferServer
import com.beamdrop.android.core.transfer.TransferManager
import com.beamdrop.android.navigation.BeamDropApp
import com.beamdrop.android.ui.theme.BeamDropTheme

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

private object ManualReceiveApprovalPrompt : ReceiveApprovalPrompt {
    override fun decide(request: IncomingTransferRequest): ReceiveDecision = ReceiveDecision.Reject
}

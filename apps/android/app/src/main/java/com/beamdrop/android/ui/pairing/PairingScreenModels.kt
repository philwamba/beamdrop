package com.beamdrop.android.ui.pairing

import com.beamdrop.android.core.pairing.DeviceIdentity
import com.beamdrop.android.core.pairing.PairingError
import com.beamdrop.android.core.pairing.PairingRequest
import com.beamdrop.android.core.pairing.TrustedPeer

data class PairNewDeviceUiState(
    val identity: DeviceIdentity,
    val qrPayload: String,
    val expiresAtEpochMillis: Long,
    val endpointLabel: String,
)

sealed class ScanQrUiState {
    data object NeedsCameraPermissionExplanation : ScanQrUiState()
    data object Ready : ScanQrUiState()
    data class PendingApproval(val request: PairingRequest) : ScanQrUiState()
    data class Error(val error: PairingError) : ScanQrUiState()
    data class Trusted(val peer: TrustedPeer) : ScanQrUiState()
}

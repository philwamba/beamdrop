package com.beamdrop.android.ui.pairing

import com.beamdrop.android.core.pairing.EndpointHint
import com.beamdrop.android.core.pairing.PairingCodec
import com.beamdrop.android.core.pairing.PairingError
import com.beamdrop.android.core.pairing.PairingSessionFactory
import com.beamdrop.android.core.pairing.PairingValidationResult
import com.beamdrop.android.core.pairing.PairingValidator
import com.beamdrop.android.core.storage.ApprovalResult
import com.beamdrop.android.core.storage.TrustedPeerRepository

class PairNewDevicePresenter(
    private val sessionFactory: PairingSessionFactory,
) {
    fun buildState(
        identity: com.beamdrop.android.core.pairing.DeviceIdentity,
        endpoint: EndpointHint?,
    ): PairNewDeviceUiState {
        val payload = sessionFactory.createPayload(identity, endpoint)
        return PairNewDeviceUiState(
            identity = identity,
            qrPayload = PairingCodec.encode(payload),
            expiresAtEpochMillis = payload.expiresAtEpochMillis,
            endpointLabel = endpoint?.let {
                if (it.isUsable()) "${it.route}: ${it.host}:${it.port}" else "Endpoint pending"
            } ?: "Endpoint pending",
        )
    }
}

class ScanQrController(
    private val validator: PairingValidator,
    private val trustedPeerRepository: TrustedPeerRepository,
) {
    var state: ScanQrUiState = ScanQrUiState.NeedsCameraPermissionExplanation
        private set

    fun markCameraReady() {
        state = ScanQrUiState.Ready
    }

    fun handleScannedText(raw: String): ScanQrUiState {
        state = when (val result = validator.validate(raw)) {
            is PairingValidationResult.Valid -> ScanQrUiState.PendingApproval(result.request)
            is PairingValidationResult.Invalid -> ScanQrUiState.Error(result.reason)
        }
        return state
    }

    fun approveCurrentRequest(): ScanQrUiState {
        val request = (state as? ScanQrUiState.PendingApproval)?.request
            ?: return ScanQrUiState.Error(PairingError.QrInvalid).also { state = it }

        state = when (val result = trustedPeerRepository.approvePairing(request)) {
            is ApprovalResult.Approved -> ScanQrUiState.Trusted(result.peer)
            ApprovalResult.AlreadyTrusted -> ScanQrUiState.Error(PairingError.DeviceAlreadyTrusted)
            ApprovalResult.PreviouslyRevoked -> ScanQrUiState.Error(PairingError.DevicePreviouslyRevoked)
        }
        return state
    }

    fun rejectCurrentRequest(): ScanQrUiState {
        state = ScanQrUiState.Error(PairingError.PairingRejected)
        return state
    }
}

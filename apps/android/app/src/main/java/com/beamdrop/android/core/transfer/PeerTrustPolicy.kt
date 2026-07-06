package com.beamdrop.android.core.transfer

import com.beamdrop.android.core.pairing.TrustState
import com.beamdrop.android.core.storage.TrustedPeerRepository

class PeerTrustPolicy(
    private val trustedPeerRepository: TrustedPeerRepository,
) {
    fun requireTrusted(peer: TransferPeer): TransferTrustResult {
        val state = trustedPeerRepository.trustStateFor(peer.deviceId, peer.publicKey)
        return when (state) {
            TrustState.Trusted -> TransferTrustResult.Allowed
            TrustState.Revoked -> TransferTrustResult.Rejected(TransferError.RevokedPeerRejected(peer.deviceId))
            TrustState.Unknown, TrustState.Pairing -> TransferTrustResult.Rejected(TransferError.UnknownPeerRejected(peer.deviceId))
        }
    }
}

sealed class TransferTrustResult {
    data object Allowed : TransferTrustResult()
    data class Rejected(val error: TransferError) : TransferTrustResult()
}


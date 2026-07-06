package com.beamdrop.android.core.storage

import com.beamdrop.android.core.pairing.DeviceIdentity
import com.beamdrop.android.core.pairing.Fingerprint
import com.beamdrop.android.core.pairing.PairingRequest
import com.beamdrop.android.core.pairing.TrustState
import com.beamdrop.android.core.pairing.TrustedPeer
import com.beamdrop.android.core.pairing.TrustedPeerLookup
import java.time.Clock

class TrustedPeerRepository(
    private val store: TrustedPeerStore,
    private val clock: Clock = Clock.systemUTC(),
) : TrustedPeerLookup {
    override fun trustStateFor(deviceId: String, publicKey: String): TrustState {
        val peer = store.get(deviceId) ?: return TrustState.Unknown
        return if (peer.publicKey == publicKey) peer.trustState else TrustState.Unknown
    }

    fun listPeers(): List<TrustedPeer> = store.list()

    fun getPeer(deviceId: String): TrustedPeer? = store.get(deviceId)

    fun approvePairing(request: PairingRequest, allowRepairOfRevokedPeer: Boolean = false): ApprovalResult {
        val existing = store.get(request.remoteDevice.deviceId)
        if (existing?.trustState == TrustState.Trusted && existing.publicKey == request.remoteDevice.publicKey) {
            return ApprovalResult.AlreadyTrusted
        }
        if (existing?.trustState == TrustState.Revoked && !allowRepairOfRevokedPeer) {
            return ApprovalResult.PreviouslyRevoked
        }

        val peer = request.remoteDevice.toTrustedPeer(
            trustedAtEpochMillis = clock.millis(),
            lastSeenEpochMillis = request.receivedAtEpochMillis,
            endpoint = request.remoteEndpoint,
        )
        store.upsert(peer)
        return ApprovalResult.Approved(peer)
    }

    fun revoke(deviceId: String): Boolean {
        val peer = store.get(deviceId) ?: return false
        store.upsert(
            peer.copy(
                trustState = TrustState.Revoked,
                revokedAtEpochMillis = clock.millis(),
            ),
        )
        return true
    }

    fun canTransfer(deviceId: String, publicKey: String): Boolean {
        val peer = store.get(deviceId) ?: return false
        return peer.trustState == TrustState.Trusted && peer.publicKey == publicKey
    }

    private fun DeviceIdentity.toTrustedPeer(
        trustedAtEpochMillis: Long,
        lastSeenEpochMillis: Long,
        endpoint: com.beamdrop.android.core.pairing.EndpointHint?,
    ) = TrustedPeer(
        deviceId = deviceId,
        displayName = displayName,
        platform = platform,
        publicKey = publicKey,
        fingerprint = Fingerprint.fromPublicKey(publicKey),
        trustState = TrustState.Trusted,
        endpoint = endpoint,
        trustedAtEpochMillis = trustedAtEpochMillis,
        revokedAtEpochMillis = null,
        lastSeenEpochMillis = lastSeenEpochMillis,
    )
}

sealed class ApprovalResult {
    data class Approved(val peer: TrustedPeer) : ApprovalResult()
    data object AlreadyTrusted : ApprovalResult()
    data object PreviouslyRevoked : ApprovalResult()
}

interface TrustedPeerStore {
    fun list(): List<TrustedPeer>
    fun get(deviceId: String): TrustedPeer?
    fun upsert(peer: TrustedPeer)
}

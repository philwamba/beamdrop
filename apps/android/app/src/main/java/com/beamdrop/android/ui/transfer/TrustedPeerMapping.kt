package com.beamdrop.android.ui.transfer

import com.beamdrop.android.core.pairing.TrustState
import com.beamdrop.android.core.pairing.TrustedPeer
import com.beamdrop.android.core.transfer.TransferPeer

internal fun List<TrustedPeer>.trustedTransferPeers(): List<TransferPeer> =
    filter { it.trustState == TrustState.Trusted }.map { it.toTransferPeer() }

internal fun List<TrustedPeer>.firstTrustedTransferPeer(): TransferPeer? =
    trustedTransferPeers().firstOrNull()

internal fun TrustedPeer.toTransferPeer(): TransferPeer = TransferPeer(
    deviceId = deviceId,
    displayName = displayName,
    platform = platform,
    publicKey = publicKey,
    endpointHost = endpoint?.host,
    endpointPort = endpoint?.port,
    autoAcceptTransfers = false,
)

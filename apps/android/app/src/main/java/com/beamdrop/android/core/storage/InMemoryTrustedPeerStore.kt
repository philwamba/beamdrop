package com.beamdrop.android.core.storage

import com.beamdrop.android.core.pairing.TrustedPeer

class InMemoryTrustedPeerStore(
    initialPeers: List<TrustedPeer> = emptyList(),
) : TrustedPeerStore {
    private val peers = LinkedHashMap<String, TrustedPeer>()

    init {
        initialPeers.forEach { peers[it.deviceId] = it }
    }

    override fun list(): List<TrustedPeer> = peers.values.toList()

    override fun get(deviceId: String): TrustedPeer? = peers[deviceId]

    override fun upsert(peer: TrustedPeer) {
        peers[peer.deviceId] = peer
    }
}

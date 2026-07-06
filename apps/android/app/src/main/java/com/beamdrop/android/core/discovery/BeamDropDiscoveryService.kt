package com.beamdrop.android.core.discovery

import com.beamdrop.android.core.pairing.BEAMDROP_SERVICE_NAME
import com.beamdrop.android.core.pairing.DeviceIdentity
import com.beamdrop.android.core.pairing.EndpointHint

const val BEAMDROP_NSD_SERVICE_TYPE = "$BEAMDROP_SERVICE_NAME."

data class DiscoveredBeamDropService(
    val serviceInstanceName: String,
    val endpoint: EndpointHint,
    val deviceId: String?,
    val displayName: String?,
    val publicKey: String?,
)

sealed class DiscoveryEvent {
    data object Started : DiscoveryEvent()
    data class Found(val service: DiscoveredBeamDropService) : DiscoveryEvent()
    data class Lost(val serviceInstanceName: String) : DiscoveryEvent()
    data class Failed(val reason: String) : DiscoveryEvent()
    data object Stopped : DiscoveryEvent()
}

interface BeamDropDiscoveryService {
    fun register(identity: DeviceIdentity, port: Int, onFailure: (String) -> Unit)
    fun discover(onEvent: (DiscoveryEvent) -> Unit)
    fun stop()
}

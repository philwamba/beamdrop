package com.beamdrop.android.core.pairing

import java.time.Clock
import java.time.Duration
import java.util.UUID

class PairingSessionFactory(
    private val clock: Clock = Clock.systemUTC(),
    private val validity: Duration = Duration.ofMinutes(5),
) {
    fun createPayload(identity: DeviceIdentity, endpoint: EndpointHint?): PairingQrPayload =
        PairingQrPayload(
            pairingSessionId = UUID.randomUUID().toString(),
            deviceId = identity.deviceId,
            displayName = identity.displayName,
            platform = identity.platform,
            publicKey = identity.publicKey,
            serviceName = BEAMDROP_SERVICE_NAME,
            endpoint = endpoint,
            protocolVersion = identity.protocolVersion,
            expiresAtEpochMillis = clock.instant().plus(validity).toEpochMilli(),
        )
}

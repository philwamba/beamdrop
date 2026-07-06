package com.beamdrop.android.core.pairing

import java.time.Clock
import java.util.UUID

class PairingValidator(
    private val trustedPeerLookup: TrustedPeerLookup,
    private val clock: Clock = Clock.systemUTC(),
) {
    fun validate(rawQrPayload: String): PairingValidationResult {
        val payload = PairingCodec.decode(rawQrPayload)
            ?: return PairingValidationResult.Invalid(PairingError.QrInvalid)

        if (payload.protocolVersion != BEAMDROP_PROTOCOL_VERSION) {
            return PairingValidationResult.Invalid(PairingError.ProtocolUnsupported)
        }
        if (payload.serviceName != BEAMDROP_SERVICE_NAME) {
            return PairingValidationResult.Invalid(PairingError.ServiceNameMismatch)
        }
        if (payload.isExpired(clock.instant())) {
            return PairingValidationResult.Invalid(PairingError.QrExpired)
        }
        if (payload.deviceId.isBlank() || payload.publicKey.isBlank() || payload.displayName.isBlank()) {
            return PairingValidationResult.Invalid(PairingError.QrInvalid)
        }
        if (payload.platform == DevicePlatform.Unknown) {
            return PairingValidationResult.Invalid(PairingError.QrInvalid)
        }

        val currentState = trustedPeerLookup.trustStateFor(payload.deviceId, payload.publicKey)
        if (currentState == TrustState.Trusted) {
            return PairingValidationResult.Invalid(PairingError.DeviceAlreadyTrusted)
        }
        if (currentState == TrustState.Revoked) {
            return PairingValidationResult.Invalid(PairingError.DevicePreviouslyRevoked)
        }

        val fingerprint = Fingerprint.fromPublicKey(payload.publicKey)
        return PairingValidationResult.Valid(
            PairingRequest(
                requestId = UUID.randomUUID().toString(),
                remoteDevice = DeviceIdentity(
                    deviceId = payload.deviceId,
                    displayName = payload.displayName,
                    platform = payload.platform,
                    publicKey = payload.publicKey,
                    protocolVersion = payload.protocolVersion,
                ),
                remoteEndpoint = payload.endpoint,
                pairingSessionId = payload.pairingSessionId,
                receivedAtEpochMillis = clock.millis(),
                fingerprint = fingerprint,
            ),
        )
    }
}

interface TrustedPeerLookup {
    fun trustStateFor(deviceId: String, publicKey: String): TrustState
}

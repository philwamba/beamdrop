package com.beamdrop.android.core.pairing

import java.time.Instant

const val BEAMDROP_PROTOCOL_VERSION = 1
const val BEAMDROP_PROTOCOL_VERSION_NAME = "1.0"
const val BEAMDROP_SERVICE_NAME = "_beamdrop._tcp"

enum class DevicePlatform(val wireName: String) {
    Android("android"),
    Ios("ios"),
    MacOS("macos"),
    Windows("windows"),
    Unknown("unknown");

    companion object {
        fun fromWireName(value: String): DevicePlatform =
            when (value.lowercase()) {
                "iphone" -> Ios
                else -> entries.firstOrNull { it.wireName == value.lowercase() } ?: Unknown
            }
    }
}

enum class TrustState {
    Unknown,
    Pairing,
    Trusted,
    Revoked,
}

data class EndpointHint(
    val host: String?,
    val port: Int?,
    val route: String = "local",
) {
    fun isUsable(): Boolean = !host.isNullOrBlank() && port != null && port in 1..65535
}

data class DeviceIdentity(
    val deviceId: String,
    val displayName: String,
    val platform: DevicePlatform,
    val publicKey: String,
    val protocolVersion: Int = BEAMDROP_PROTOCOL_VERSION,
)

data class PairingQrPayload(
    val pairingSessionId: String,
    val deviceId: String,
    val displayName: String,
    val platform: DevicePlatform,
    val publicKey: String,
    val serviceName: String,
    val endpoint: EndpointHint?,
    val protocolVersion: Int,
    val expiresAtEpochMillis: Long,
) {
    fun isExpired(now: Instant): Boolean = expiresAtEpochMillis <= now.toEpochMilli()
}

data class PairingRequest(
    val requestId: String,
    val remoteDevice: DeviceIdentity,
    val remoteEndpoint: EndpointHint?,
    val pairingSessionId: String,
    val receivedAtEpochMillis: Long,
    val fingerprint: String,
)

data class TrustedPeer(
    val deviceId: String,
    val displayName: String,
    val platform: DevicePlatform,
    val publicKey: String,
    val fingerprint: String,
    val trustState: TrustState,
    val endpoint: EndpointHint?,
    val trustedAtEpochMillis: Long?,
    val revokedAtEpochMillis: Long?,
    val lastSeenEpochMillis: Long?,
)

sealed class PairingValidationResult {
    data class Valid(val request: PairingRequest) : PairingValidationResult()
    data class Invalid(val reason: PairingError) : PairingValidationResult()
}

enum class PairingError {
    LocalNetworkPermissionDenied,
    NoDevicesFound,
    QrInvalid,
    QrExpired,
    PairingRejected,
    DeviceAlreadyTrusted,
    ProtocolUnsupported,
    ServiceNameMismatch,
    DevicePreviouslyRevoked,
}

package com.beamdrop.android.core.pairing

import com.beamdrop.android.core.storage.InMemoryTrustedPeerStore
import com.beamdrop.android.core.storage.TrustedPeerRepository
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset

class PairingValidatorTest {
    private val clock = Clock.fixed(Instant.parse("2026-07-06T12:00:00Z"), ZoneOffset.UTC)
    private val repository = TrustedPeerRepository(InMemoryTrustedPeerStore(), clock)
    private val validator = PairingValidator(repository, clock)

    @Test
    fun validQrPayloadProducesPairingRequest() {
        val result = validator.validate(validPayload())

        assertTrue(result is PairingValidationResult.Valid)
        val request = (result as PairingValidationResult.Valid).request
        assertEquals("android-phone", request.remoteDevice.displayName)
        assertEquals(DevicePlatform.Android, request.remoteDevice.platform)
        assertEquals("session-1", request.pairingSessionId)
        assertEquals("local", request.remoteEndpoint?.route)
    }

    @Test
    fun expiredQrPayloadIsRejected() {
        val payload = payloadObject(expiresAtEpochMillis = clock.millis() - 1)

        val result = validator.validate(PairingCodec.encode(payload))

        assertEquals(PairingValidationResult.Invalid(PairingError.QrExpired), result)
    }

    @Test
    fun invalidServiceNameIsRejected() {
        val payload = payloadObject(serviceName = "_other._tcp")

        val result = validator.validate(PairingCodec.encode(payload))

        assertEquals(PairingValidationResult.Invalid(PairingError.ServiceNameMismatch), result)
    }

    @Test
    fun alreadyTrustedDeviceIsRejected() {
        val request = (validator.validate(validPayload()) as PairingValidationResult.Valid).request
        repository.approvePairing(request)

        val result = validator.validate(validPayload())

        assertEquals(PairingValidationResult.Invalid(PairingError.DeviceAlreadyTrusted), result)
    }

    private fun validPayload(): String = PairingCodec.encode(payloadObject())

    private fun payloadObject(
        serviceName: String = BEAMDROP_SERVICE_NAME,
        expiresAtEpochMillis: Long = clock.millis() + 60_000,
    ) = PairingQrPayload(
        pairingSessionId = "session-1",
        deviceId = "device-1",
        displayName = "android-phone",
        platform = DevicePlatform.Android,
        publicKey = "public-key",
        serviceName = serviceName,
        endpoint = EndpointHint(host = "192.0.2.20", port = 45844),
        protocolVersion = BEAMDROP_PROTOCOL_VERSION,
        expiresAtEpochMillis = expiresAtEpochMillis,
    )
}

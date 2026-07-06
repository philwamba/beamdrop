package com.beamdrop.android.core.storage

import com.beamdrop.android.core.pairing.DeviceIdentity
import com.beamdrop.android.core.pairing.DevicePlatform
import com.beamdrop.android.core.pairing.EndpointHint
import com.beamdrop.android.core.pairing.PairingRequest
import com.beamdrop.android.core.pairing.TrustState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset

class TrustedPeerRepositoryTest {
    private val clock = Clock.fixed(Instant.parse("2026-07-06T12:00:00Z"), ZoneOffset.UTC)

    @Test
    fun approvingPairingStoresTrustedPeer() {
        val repository = TrustedPeerRepository(InMemoryTrustedPeerStore(), clock)

        val result = repository.approvePairing(pairingRequest())

        assertTrue(result is ApprovalResult.Approved)
        assertEquals(TrustState.Trusted, repository.listPeers().single().trustState)
        assertEquals("192.0.2.40", repository.listPeers().single().endpoint?.host)
        assertTrue(repository.canTransfer("device-1", "public-key"))
    }

    @Test
    fun duplicateApprovalReturnsAlreadyTrusted() {
        val repository = TrustedPeerRepository(InMemoryTrustedPeerStore(), clock)
        repository.approvePairing(pairingRequest())

        val result = repository.approvePairing(pairingRequest())

        assertEquals(ApprovalResult.AlreadyTrusted, result)
    }

    @Test
    fun publicKeyMismatchCannotTransfer() {
        val repository = TrustedPeerRepository(InMemoryTrustedPeerStore(), clock)
        repository.approvePairing(pairingRequest())

        assertFalse(repository.canTransfer("device-1", "different-public-key"))
    }

    private fun pairingRequest() = PairingRequest(
        requestId = "request-1",
        remoteDevice = DeviceIdentity(
            deviceId = "device-1",
            displayName = "Android phone",
            platform = DevicePlatform.Android,
            publicKey = "public-key",
        ),
        remoteEndpoint = EndpointHint(host = "192.0.2.40", port = 49320),
        pairingSessionId = "session-1",
        receivedAtEpochMillis = clock.millis(),
        fingerprint = "AA:BB",
    )
}

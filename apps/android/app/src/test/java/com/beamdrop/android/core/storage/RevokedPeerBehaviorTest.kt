package com.beamdrop.android.core.storage

import com.beamdrop.android.core.pairing.DeviceIdentity
import com.beamdrop.android.core.pairing.DevicePlatform
import com.beamdrop.android.core.pairing.PairingRequest
import com.beamdrop.android.core.pairing.TrustState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset

class RevokedPeerBehaviorTest {
    private val clock = Clock.fixed(Instant.parse("2026-07-06T12:00:00Z"), ZoneOffset.UTC)

    @Test
    fun revokedPeerCannotTransfer() {
        val repository = TrustedPeerRepository(InMemoryTrustedPeerStore(), clock)
        repository.approvePairing(request())

        assertTrue(repository.revoke("device-1"))

        assertFalse(repository.canTransfer("device-1", "public-key"))
        assertEquals(TrustState.Revoked, repository.listPeers().single().trustState)
    }

    @Test
    fun revokedPeerDoesNotRegainTrustWithoutExplicitRepair() {
        val repository = TrustedPeerRepository(InMemoryTrustedPeerStore(), clock)
        repository.approvePairing(request())
        repository.revoke("device-1")

        val result = repository.approvePairing(request())

        assertEquals(ApprovalResult.PreviouslyRevoked, result)
        assertFalse(repository.canTransfer("device-1", "public-key"))
    }

    @Test
    fun deliberateRepairCanTrustRevokedPeerAfterPairingFlow() {
        val repository = TrustedPeerRepository(InMemoryTrustedPeerStore(), clock)
        repository.approvePairing(request())
        repository.revoke("device-1")

        val result = repository.approvePairing(request(), allowRepairOfRevokedPeer = true)

        assertTrue(result is ApprovalResult.Approved)
        assertTrue(repository.canTransfer("device-1", "public-key"))
    }

    private fun request() = PairingRequest(
        requestId = "request-1",
        remoteDevice = DeviceIdentity(
            deviceId = "device-1",
            displayName = "Android phone",
            platform = DevicePlatform.Android,
            publicKey = "public-key",
        ),
        remoteEndpoint = null,
        pairingSessionId = "session-1",
        receivedAtEpochMillis = clock.millis(),
        fingerprint = "AA:BB",
    )
}

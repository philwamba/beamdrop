package com.beamdrop.android.core.permissions

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PermissionStateMapperTest {
    @Test
    fun android13RequiresNearbyWifiAndNotificationsAtRuntime() {
        val plan = PermissionPlanner.planForSdk(33)

        val nearby = plan.single { it.permission == BeamDropPermission.NearbyWifiDevices }
        val notifications = plan.single { it.permission == BeamDropPermission.Notifications }

        assertEquals(PermissionAvailability.Runtime, nearby.availability)
        assertTrue(nearby.requiredNow)
        assertEquals(PermissionAvailability.Runtime, notifications.availability)
        assertTrue(notifications.requiredNow)
    }

    @Test
    fun preAndroid13DoesNotRequireNearbyWifiOrNotificationRuntimePermissions() {
        val plan = PermissionPlanner.planForSdk(32)

        assertEquals(
            PermissionAvailability.NotRequired,
            plan.single { it.permission == BeamDropPermission.NearbyWifiDevices }.availability,
        )
        assertEquals(
            PermissionAvailability.NotRequired,
            plan.single { it.permission == BeamDropPermission.Notifications }.availability,
        )
    }

    @Test
    fun foregroundServicePermissionOnlyRequiredForActiveTransferProgress() {
        val idle = PermissionPlanner.planForSdk(34, activeTransferProgress = false)
            .single { it.permission == BeamDropPermission.ForegroundTransferService }
        val active = PermissionPlanner.planForSdk(34, activeTransferProgress = true)
            .single { it.permission == BeamDropPermission.ForegroundTransferService }

        assertFalse(idle.requiredNow)
        assertTrue(active.requiredNow)
        assertEquals(PermissionAvailability.ManifestOnly, active.availability)
    }

    @Test
    fun mapperConvertsRuntimeGrantToUiStatus() {
        val planned = PlannedPermission(
            permission = BeamDropPermission.Camera,
            availability = PermissionAvailability.Runtime,
            requiredNow = false,
        )

        assertEquals(
            PermissionStatus.Granted,
            PermissionStateMapper.map(planned, RuntimePermissionGrant.Granted).status,
        )
        assertEquals(
            PermissionStatus.NeedsRationale,
            PermissionStateMapper.map(planned, RuntimePermissionGrant.ShowRationale).status,
        )
        assertEquals(
            PermissionStatus.Denied,
            PermissionStateMapper.map(planned, RuntimePermissionGrant.Denied, permanentlyDenied = true).status,
        )
    }
}

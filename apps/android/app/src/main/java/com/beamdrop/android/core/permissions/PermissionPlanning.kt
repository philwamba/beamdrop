package com.beamdrop.android.core.permissions

import android.Manifest
import android.os.Build

enum class BeamDropPermission(
    val manifestPermission: String?,
    val title: String,
    val explanation: String,
) {
    Internet(
        manifestPermission = Manifest.permission.INTERNET,
        title = "Internet",
        explanation = "BeamDrop uses network access for local transfer sockets and future optional relay routes.",
    ),
    NetworkState(
        manifestPermission = Manifest.permission.ACCESS_NETWORK_STATE,
        title = "Network state",
        explanation = "BeamDrop checks whether local networking is available before nearby discovery and transfer.",
    ),
    NearbyWifiDevices(
        manifestPermission = Manifest.permission.NEARBY_WIFI_DEVICES,
        title = "Nearby Wi-Fi devices",
        explanation = "Android may require this for nearby local discovery without using location.",
    ),
    Camera(
        manifestPermission = Manifest.permission.CAMERA,
        title = "Camera",
        explanation = "BeamDrop uses the camera only when you scan a pairing QR code.",
    ),
    Notifications(
        manifestPermission = Manifest.permission.POST_NOTIFICATIONS,
        title = "Notifications",
        explanation = "BeamDrop can show incoming transfer requests and active transfer progress.",
    ),
    ForegroundTransferService(
        manifestPermission = Manifest.permission.FOREGROUND_SERVICE_DATA_SYNC,
        title = "Active transfer progress",
        explanation = "Long transfers may need a visible foreground service so Android does not stop them.",
    ),
}

enum class PermissionAvailability {
    ManifestOnly,
    Runtime,
    NotRequired,
}

data class PlannedPermission(
    val permission: BeamDropPermission,
    val availability: PermissionAvailability,
    val requiredNow: Boolean,
)

object PermissionPlanner {
    fun planForSdk(sdkInt: Int, activeTransferProgress: Boolean = false): List<PlannedPermission> =
        buildList {
            add(PlannedPermission(BeamDropPermission.Internet, PermissionAvailability.ManifestOnly, requiredNow = true))
            add(PlannedPermission(BeamDropPermission.NetworkState, PermissionAvailability.ManifestOnly, requiredNow = true))
            add(
                PlannedPermission(
                    BeamDropPermission.NearbyWifiDevices,
                    if (sdkInt >= Build.VERSION_CODES.TIRAMISU) PermissionAvailability.Runtime else PermissionAvailability.NotRequired,
                    requiredNow = sdkInt >= Build.VERSION_CODES.TIRAMISU,
                ),
            )
            add(PlannedPermission(BeamDropPermission.Camera, PermissionAvailability.Runtime, requiredNow = false))
            add(
                PlannedPermission(
                    BeamDropPermission.Notifications,
                    if (sdkInt >= Build.VERSION_CODES.TIRAMISU) PermissionAvailability.Runtime else PermissionAvailability.NotRequired,
                    requiredNow = sdkInt >= Build.VERSION_CODES.TIRAMISU,
                ),
            )
            add(
                PlannedPermission(
                    BeamDropPermission.ForegroundTransferService,
                    if (sdkInt >= 34) PermissionAvailability.ManifestOnly else PermissionAvailability.NotRequired,
                    requiredNow = activeTransferProgress,
                ),
            )
        }
}

enum class RuntimePermissionGrant {
    Granted,
    Denied,
    ShowRationale,
}

data class PermissionExplanationState(
    val permission: BeamDropPermission,
    val status: PermissionStatus,
    val explanation: String,
)

enum class PermissionStatus {
    Granted,
    NeedsRequest,
    NeedsRationale,
    Denied,
    NotRequired,
    ManifestOnly,
}

object PermissionStateMapper {
    fun map(
        plannedPermission: PlannedPermission,
        grant: RuntimePermissionGrant?,
        permanentlyDenied: Boolean = false,
    ): PermissionExplanationState {
        val status = when (plannedPermission.availability) {
            PermissionAvailability.NotRequired -> PermissionStatus.NotRequired
            PermissionAvailability.ManifestOnly -> PermissionStatus.ManifestOnly
            PermissionAvailability.Runtime -> when {
                grant == RuntimePermissionGrant.Granted -> PermissionStatus.Granted
                grant == RuntimePermissionGrant.ShowRationale -> PermissionStatus.NeedsRationale
                permanentlyDenied -> PermissionStatus.Denied
                else -> PermissionStatus.NeedsRequest
            }
        }
        return PermissionExplanationState(
            permission = plannedPermission.permission,
            status = status,
            explanation = plannedPermission.permission.explanation,
        )
    }
}

package com.beamdrop.android.ui.settings

import android.os.Build
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.beamdrop.android.R
import com.beamdrop.android.core.pairing.BEAMDROP_SERVICE_NAME
import com.beamdrop.android.core.permissions.PermissionPlanner
import com.beamdrop.android.core.permissions.PermissionStateMapper
import com.beamdrop.android.core.permissions.PermissionStatus
import com.beamdrop.android.navigation.BeamDropDestination
import com.beamdrop.android.ui.components.BeamDropBottomBar
import com.beamdrop.android.ui.components.SectionSurface
import com.beamdrop.android.ui.util.LocalNetworkAddress

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun PermissionExplanationScreen(onBack: () -> Unit) {
    val planned = remember {
        PermissionPlanner.planForSdk(Build.VERSION.SDK_INT, activeTransferProgress = false)
            .map { PermissionStateMapper.map(it, grant = null) }
    }
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Permissions") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .background(MaterialTheme.colorScheme.background)
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            items(planned) { permission ->
                SectionSurface {
                    Text(permission.permission.title, fontWeight = FontWeight.SemiBold)
                    Text(permission.explanation, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(Modifier.height(8.dp))
                    AssistChip(onClick = {}, label = { Text(permission.status.label()) })
                }
            }
            item {
                SectionSurface {
                    Text("Bluetooth", fontWeight = FontWeight.SemiBold)
                    Text(
                        "Not requested for the current local QR and Wi-Fi discovery flow. It can be added later if a Bluetooth transport is implemented.",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun SettingsScreen(
    onHome: () -> Unit,
    onDevices: () -> Unit,
    onHistory: () -> Unit,
    onPrivacy: () -> Unit,
    onDiagnostics: () -> Unit,
    onPermissions: () -> Unit,
    onAbout: () -> Unit,
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Settings") },
            )
        },
        bottomBar = {
            BeamDropBottomBar(
                current = BeamDropDestination.Settings,
                onHome = onHome,
                onDevices = onDevices,
                onHistory = onHistory,
                onSettings = {},
            )
        },
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .background(MaterialTheme.colorScheme.background)
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                SectionSurface {
                    Text("Transfer Defaults", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                    Text("Auto-accept is off by default. Only trusted devices can be considered for future auto-accept rules.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            item { SettingsRow("Privacy", "Clipboard and trust behavior.", onPrivacy) }
            item { SettingsRow("Permissions", "Camera, notifications, and local network explanations.", onPermissions) }
            item { SettingsRow("Network Diagnostics", "Troubleshoot Bonjour, Wi-Fi isolation, VPNs, and manual QR fallback.", onDiagnostics) }
            item { SettingsRow("About", "Version, native stack, and release status.", onAbout) }
        }
    }
}

@Composable
private fun SettingsRow(title: String, detail: String, onClick: () -> Unit) {
    SectionSurface {
        Text(title, fontWeight = FontWeight.SemiBold)
        Text(detail, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.height(8.dp))
        OutlinedButton(onClick = onClick) { Text("Open") }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun PrivacyScreen(onBack: () -> Unit) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Privacy") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .background(MaterialTheme.colorScheme.background)
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                SectionSurface {
                    Text("Local-First", fontWeight = FontWeight.SemiBold)
                    Text("BeamDrop sends over the local network when possible and does not require login or cloud upload for local MVP transfers.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            item {
                SectionSurface {
                    Text("Clipboard", fontWeight = FontWeight.SemiBold)
                    Text("Android clipboard sending is manual and user-triggered. BeamDrop does not hide background clipboard monitoring behind a service.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            item {
                SectionSurface {
                    Text("Device Trust", fontWeight = FontWeight.SemiBold)
                    Text("Unknown devices are rejected. Revoked devices are blocked before content is accepted.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun NetworkDiagnosticsScreen(onBack: () -> Unit, onPair: () -> Unit) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Network Diagnostics") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .background(MaterialTheme.colorScheme.background)
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                SectionSurface {
                    Text("Local Address", fontWeight = FontWeight.SemiBold)
                    Text(LocalNetworkAddress.firstUsableIpv4Address() ?: "No usable local IPv4 address found.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            item {
                SectionSurface {
                    Text("Discovery Service", fontWeight = FontWeight.SemiBold)
                    Text("$BEAMDROP_SERVICE_NAME may be blocked by public Wi-Fi, guest networks, VPNs, or corporate isolation.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            item {
                SectionSurface {
                    Text("Manual Fallback", fontWeight = FontWeight.SemiBold)
                    Text("Use QR pairing when discovery fails. Security rules stay the same.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(Modifier.height(8.dp))
                    Button(onClick = onPair) { Text("Pair With QR") }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun AboutScreen(onBack: () -> Unit) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("About") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .background(MaterialTheme.colorScheme.background)
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                SectionSurface(horizontalAlignment = Alignment.CenterHorizontally) {
                    Image(
                        painter = painterResource(id = R.drawable.beamdrop_logo),
                        contentDescription = "BeamDrop logo",
                        modifier = Modifier.size(72.dp),
                    )
                    Spacer(Modifier.height(12.dp))
                    Text("BeamDrop For Android", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                    Text("Native Kotlin and Jetpack Compose app for private local transfer between trusted devices.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            item {
                SectionSurface {
                    Text("Release Status", fontWeight = FontWeight.SemiBold)
                    Text("MVP development. Production downloads will be published after signing, verification, and release testing.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
    }
}

private fun PermissionStatus.label(): String = when (this) {
    PermissionStatus.Granted -> "Granted"
    PermissionStatus.NeedsRequest -> "Request when needed"
    PermissionStatus.NeedsRationale -> "Needs explanation"
    PermissionStatus.Denied -> "Denied"
    PermissionStatus.NotRequired -> "Not required on this Android version"
    PermissionStatus.ManifestOnly -> "Declared in manifest"
}

package com.beamdrop.android.ui.components

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Devices
import androidx.compose.material.icons.outlined.History
import androidx.compose.material.icons.outlined.QrCode
import androidx.compose.material.icons.outlined.Security
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import com.beamdrop.android.navigation.BeamDropDestination

@Composable
internal fun BeamDropBottomBar(
    current: BeamDropDestination,
    onHome: () -> Unit,
    onDevices: () -> Unit,
    onHistory: () -> Unit,
    onSettings: () -> Unit,
) {
    NavigationBar {
        NavigationBarItem(
            selected = current == BeamDropDestination.Home,
            onClick = onHome,
            icon = { Icon(Icons.Outlined.QrCode, contentDescription = null) },
            label = { Text("Home") },
        )
        NavigationBarItem(
            selected = current == BeamDropDestination.Devices,
            onClick = onDevices,
            icon = { Icon(Icons.Outlined.Devices, contentDescription = null) },
            label = { Text("Devices") },
        )
        NavigationBarItem(
            selected = current == BeamDropDestination.History,
            onClick = onHistory,
            icon = { Icon(Icons.Outlined.History, contentDescription = null) },
            label = { Text("History") },
        )
        NavigationBarItem(
            selected = current == BeamDropDestination.Settings,
            onClick = onSettings,
            icon = { Icon(Icons.Outlined.Security, contentDescription = null) },
            label = { Text("Settings") },
        )
    }
}

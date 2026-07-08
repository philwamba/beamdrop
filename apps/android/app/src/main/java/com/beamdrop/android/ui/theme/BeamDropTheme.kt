package com.beamdrop.android.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

@Composable
internal fun BeamDropTheme(content: @Composable () -> Unit) {
    val dark = isSystemInDarkTheme()
    MaterialTheme(
        colorScheme = if (dark) {
            darkColorScheme(
                primary = Color(0xFFAECBFA),
                secondary = Color(0xFF8FD8CA),
                tertiary = Color(0xFFFFD28A),
                surface = Color(0xFF111318),
                surfaceVariant = Color(0xFF232832),
                background = Color(0xFF0B0D12),
            )
        } else {
            lightColorScheme(
                primary = Color(0xFF1967D2),
                secondary = Color(0xFF146C5F),
                tertiary = Color(0xFF7A4D00),
                surface = Color(0xFFFAFBFD),
                surfaceVariant = Color(0xFFE8EDF7),
                background = Color(0xFFF5F7FB),
            )
        },
        content = content,
    )
}

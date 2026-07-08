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
                primary = Color(0xFF7EDDCB),
                secondary = Color(0xFF4FB7A5),
                tertiary = Color(0xFFFFD28A),
                surface = Color(0xFF111318),
                surfaceVariant = Color(0xFF1E302D),
                background = Color(0xFF07110F),
            )
        } else {
            lightColorScheme(
                primary = Color(0xFF00796B),
                secondary = Color(0xFF0B6F61),
                tertiary = Color(0xFF7A4D00),
                surface = Color(0xFFFAFBFD),
                surfaceVariant = Color(0xFFE4F1EE),
                background = Color(0xFFF7FAF9),
            )
        },
        content = content,
    )
}

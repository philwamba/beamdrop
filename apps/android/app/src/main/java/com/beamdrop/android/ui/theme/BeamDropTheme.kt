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
                primary = Color(0xFF80C7FF),
                secondary = Color(0xFF53D3FF),
                tertiary = Color(0xFF9BB7FF),
                surface = Color(0xFF101419),
                surfaceVariant = Color(0xFF1E2B36),
                background = Color(0xFF081018),
            )
        } else {
            lightColorScheme(
                primary = Color(0xFF0B7FEB),
                secondary = Color(0xFF23B9F2),
                tertiary = Color(0xFF2457C5),
                surface = Color(0xFFFAFBFD),
                surfaceVariant = Color(0xFFE4F2FF),
                background = Color(0xFFF6FAFF),
            )
        },
        content = content,
    )
}

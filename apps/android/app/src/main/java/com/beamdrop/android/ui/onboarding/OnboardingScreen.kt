package com.beamdrop.android.ui.onboarding

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.beamdrop.android.R
import com.beamdrop.android.ui.components.SectionSurface

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun OnboardingScreen(onBack: () -> Unit, onPair: () -> Unit) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Onboarding") },
                navigationIcon = { TextButton(onClick = onBack) { Text("Back") } },
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
                    Text("BeamDrop", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
                    Text("Private local transfer for trusted devices.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            item {
                SectionSurface {
                    Text("Private Local Transfer", fontWeight = FontWeight.SemiBold)
                    Text("Send text and files between devices you trust without requiring login or cloud upload.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            item {
                SectionSurface {
                    Text("Pair With QR", fontWeight = FontWeight.SemiBold)
                    Text("Trust is explicit. Unknown devices cannot send content until approved.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            item {
                SectionSurface {
                    Text("Clipboard Is Manual", fontWeight = FontWeight.SemiBold)
                    Text("Android clipboard sending is user-triggered and respects platform restrictions.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            item {
                Button(onClick = onPair, modifier = Modifier.fillMaxWidth()) {
                    Text("Pair First Device")
                }
            }
        }
    }
}

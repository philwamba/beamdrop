package com.beamdrop.android.ui.pairing

import android.Manifest
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.QrCodeScanner
import androidx.compose.material.icons.outlined.Refresh
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.beamdrop.android.R
import com.beamdrop.android.core.pairing.PairingError
import com.beamdrop.android.core.pairing.PairingRequest
import com.beamdrop.android.core.permissions.RuntimePermissionGrant
import com.beamdrop.android.ui.components.ErrorText
import com.beamdrop.android.ui.components.InfoText
import com.beamdrop.android.ui.components.SectionSurface
import com.google.zxing.BarcodeFormat
import com.google.zxing.BinaryBitmap
import com.google.zxing.DecodeHintType
import com.google.zxing.MultiFormatReader
import com.google.zxing.NotFoundException
import com.google.zxing.PlanarYUVLuminanceSource
import com.google.zxing.common.GlobalHistogramBinarizer
import com.google.zxing.common.HybridBinarizer
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun PairNewDeviceScreen(
    state: PairNewDeviceUiState,
    onBack: () -> Unit,
    onRefresh: () -> Unit,
    onScan: () -> Unit,
) {
    val qrBitmap = remember(state.qrPayload) { QrCodeBitmap.create(state.qrPayload) }
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Pair new device") },
                navigationIcon = { TextButton(onClick = onBack) { Text("Close") } },
                actions = {
                    IconButton(onClick = onRefresh) {
                        Icon(Icons.Outlined.Refresh, contentDescription = "Refresh QR")
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
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            item {
                SectionSurface(horizontalAlignment = Alignment.CenterHorizontally) {
                    Image(
                        painter = painterResource(id = R.drawable.beamdrop_logo),
                        contentDescription = "BeamDrop logo",
                        modifier = Modifier.size(64.dp),
                    )
                    Spacer(Modifier.height(12.dp))
                    Text(state.identity.displayName, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
                    Text("Android · protocol v${state.identity.protocolVersion}", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(Modifier.height(16.dp))
                    Surface(
                        shape = RoundedCornerShape(8.dp),
                        color = Color.White,
                        shadowElevation = 1.dp,
                    ) {
                        Image(
                            bitmap = qrBitmap,
                            contentDescription = "BeamDrop pairing QR code",
                            modifier = Modifier
                                .padding(14.dp)
                                .size(260.dp),
                        )
                    }
                    Spacer(Modifier.height(12.dp))
                    AssistChip(onClick = {}, label = { Text(state.endpointLabel) })
                    Text(
                        "QR includes device ID, public key, protocol version, service name, and endpoint status. It expires automatically.",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }

            item {
                Button(onClick = onScan, modifier = Modifier.fillMaxWidth()) {
                    Icon(Icons.Outlined.QrCodeScanner, contentDescription = null)
                    Spacer(Modifier.size(8.dp))
                    Text("Scan another BeamDrop QR")
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun ScanQrScreen(
    controller: ScanQrController,
    onBack: () -> Unit,
    onTrusted: () -> Unit,
) {
    var state by remember { mutableStateOf(controller.state) }
    var rawQr by remember { mutableStateOf("") }
    var scanAttempt by remember { mutableIntStateOf(0) }
    val context = LocalContext.current
    var cameraGrant by remember {
        mutableStateOf(
            if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
                RuntimePermissionGrant.Granted
            } else {
                null
            },
        )
    }
    val cameraLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        cameraGrant = if (granted) RuntimePermissionGrant.Granted else RuntimePermissionGrant.Denied
        if (granted) {
            controller.markCameraReady()
            state = controller.state
        }
    }
    LaunchedEffect(cameraGrant) {
        if (cameraGrant == RuntimePermissionGrant.Granted && state == ScanQrUiState.NeedsCameraPermissionExplanation) {
            controller.markCameraReady()
            state = controller.state
        }
    }

    if (state is ScanQrUiState.PendingApproval) {
        PairingApprovalDialog(
            request = (state as ScanQrUiState.PendingApproval).request,
            onApprove = {
                state = controller.approveCurrentRequest()
                if (state is ScanQrUiState.Trusted) onTrusted()
            },
            onReject = { state = controller.rejectCurrentRequest() },
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Scan QR code") },
                navigationIcon = { TextButton(onClick = onBack) { Text("Close") } },
            )
        },
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .background(MaterialTheme.colorScheme.background)
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            item {
                PermissionCameraCard(
                    grant = cameraGrant,
                    onRequest = { cameraLauncher.launch(Manifest.permission.CAMERA) },
                )
            }

            if (cameraGrant == RuntimePermissionGrant.Granted) {
                item {
                    SectionSurface {
                        Text("Point your camera at a BeamDrop QR", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                        Text(
                            "When a valid code is found, BeamDrop will show the device name and ask you to approve it.",
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Spacer(Modifier.height(12.dp))
                        key(scanAttempt) {
                            QrCameraScanner(
                                onQrCode = { scanned ->
                                    state = controller.handleScannedText(scanned)
                                },
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(320.dp),
                            )
                        }
                    }
                }
            }

            item {
                SectionSurface {
                    Text("Paste pairing code", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                    Text(
                        "Use this fallback if the camera cannot read the QR or another device shared the code as text.",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Spacer(Modifier.height(12.dp))
                    OutlinedTextField(
                        value = rawQr,
                        onValueChange = { rawQr = it },
                        label = { Text("BeamDrop QR payload") },
                        minLines = 4,
                        modifier = Modifier.fillMaxWidth(),
                    )
                    Spacer(Modifier.height(12.dp))
                    Button(
                        onClick = { state = controller.handleScannedText(rawQr) },
                        enabled = rawQr.isNotBlank(),
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text("Validate pairing QR")
                    }
                }
            }

            item {
                ScanStateMessage(
                    state = state,
                    onScanAgain = {
                        controller.markCameraReady()
                        state = controller.state
                        scanAttempt++
                    },
                )
            }
        }
    }
}

@Composable
private fun PermissionCameraCard(
    grant: RuntimePermissionGrant?,
    onRequest: () -> Unit,
) {
    SectionSurface {
        Text("Camera permission", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        Text(
            "BeamDrop uses the camera only when you scan a QR code. Pairing still requires approval before trust is saved.",
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.height(12.dp))
        when (grant) {
            RuntimePermissionGrant.Granted -> AssistChip(onClick = {}, label = { Text("Camera ready") })
            RuntimePermissionGrant.Denied -> ErrorText("Camera denied. Use manual payload entry or enable camera in Android settings.")
            RuntimePermissionGrant.ShowRationale, null -> Button(onClick = onRequest) { Text("Allow camera") }
        }
    }
}

@Composable
private fun QrCameraScanner(
    onQrCode: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val executor = remember { Executors.newSingleThreadExecutor() }
    val didScan = remember { AtomicBoolean(false) }

    DisposableEffect(Unit) {
        onDispose {
            executor.shutdown()
        }
    }

    AndroidView(
        modifier = modifier,
        factory = { viewContext ->
            val previewView = PreviewView(viewContext).apply {
                scaleType = PreviewView.ScaleType.FILL_CENTER
            }
            val cameraProviderFuture = ProcessCameraProvider.getInstance(viewContext)
            cameraProviderFuture.addListener(
                {
                    val cameraProvider = cameraProviderFuture.get()
                    val preview = Preview.Builder().build().also {
                        it.setSurfaceProvider(previewView.surfaceProvider)
                    }
                    val analysis = ImageAnalysis.Builder()
                        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                        .build()
                        .also { imageAnalysis ->
                            imageAnalysis.setAnalyzer(executor) { image ->
                                try {
                                    val result = decodeQrCode(image)
                                    if (result != null && didScan.compareAndSet(false, true)) {
                                        Handler(Looper.getMainLooper()).post { onQrCode(result) }
                                    }
                                } finally {
                                    image.close()
                                }
                            }
                        }

                    runCatching {
                        cameraProvider.unbindAll()
                        cameraProvider.bindToLifecycle(
                            lifecycleOwner,
                            CameraSelector.DEFAULT_BACK_CAMERA,
                            preview,
                            analysis,
                        )
                    }.onFailure { error ->
                        Log.w("BeamDropQrScanner", "Camera scanner could not start: ${error.message}")
                    }
                },
                ContextCompat.getMainExecutor(context),
            )
            previewView
        },
    )
}

private fun decodeQrCode(image: ImageProxy): String? {
    val frame = image.toLuminanceFrame()
    return sequenceOf(
        frame,
        frame.rotateClockwise(),
        frame.rotateClockwise().rotateClockwise(),
        frame.rotateCounterClockwise(),
    ).firstNotNullOfOrNull { decodeQrFrame(it) }
}

private fun decodeQrFrame(frame: LuminanceFrame): String? {
    val source = PlanarYUVLuminanceSource(
        frame.bytes,
        frame.width,
        frame.height,
        0,
        0,
        frame.width,
        frame.height,
        false,
    )
    val reader = MultiFormatReader().apply {
        setHints(
            mapOf(
                DecodeHintType.POSSIBLE_FORMATS to listOf(BarcodeFormat.QR_CODE),
                DecodeHintType.TRY_HARDER to true,
                DecodeHintType.CHARACTER_SET to "UTF-8",
            ),
        )
    }
    return try {
        reader.decode(BinaryBitmap(HybridBinarizer(source))).text
    } catch (_: NotFoundException) {
        try {
            reader.decode(BinaryBitmap(GlobalHistogramBinarizer(source))).text
        } catch (_: NotFoundException) {
            null
        }
    } catch (error: Exception) {
        Log.w("BeamDropQrScanner", "QR decode failed: ${error.message}")
        null
    } finally {
        reader.reset()
    }
}

private data class LuminanceFrame(
    val bytes: ByteArray,
    val width: Int,
    val height: Int,
) {
    fun rotateClockwise(): LuminanceFrame {
        val rotated = ByteArray(bytes.size)
        for (y in 0 until height) {
            for (x in 0 until width) {
                rotated[x * height + (height - y - 1)] = bytes[y * width + x]
            }
        }
        return LuminanceFrame(rotated, height, width)
    }

    fun rotateCounterClockwise(): LuminanceFrame {
        val rotated = ByteArray(bytes.size)
        for (y in 0 until height) {
            for (x in 0 until width) {
                rotated[(width - x - 1) * height + y] = bytes[y * width + x]
            }
        }
        return LuminanceFrame(rotated, height, width)
    }
}

private fun ImageProxy.toLuminanceFrame(): LuminanceFrame {
    val plane = planes.first()
    val buffer = plane.buffer
    val rowStride = plane.rowStride
    val pixelStride = plane.pixelStride
    val data = ByteArray(width * height)
    if (pixelStride == 1 && rowStride == width) {
        buffer.rewind()
        buffer.get(data, 0, minOf(data.size, buffer.remaining()))
        return LuminanceFrame(data, width, height)
    }

    val row = ByteArray(rowStride)
    var outputOffset = 0
    for (y in 0 until height) {
        buffer.position(y * rowStride)
        val bytesToRead = minOf(rowStride, buffer.remaining())
        buffer.get(row, 0, bytesToRead)
        for (x in 0 until width) {
            val inputOffset = x * pixelStride
            data[outputOffset++] = if (inputOffset < bytesToRead) row[inputOffset] else 0
        }
    }

    return LuminanceFrame(data, width, height)
}

@Composable
private fun PairingApprovalDialog(
    request: PairingRequest,
    onApprove: () -> Unit,
    onReject: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onReject,
        title = { Text("Trust this device?") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(request.remoteDevice.displayName, fontWeight = FontWeight.SemiBold)
                Text("Platform: ${request.remoteDevice.platform.wireName}")
                Text("Fingerprint: ${request.fingerprint}")
                Text("Trust status: pairing approval required")
                Text("Unknown devices cannot transfer until you approve pairing.")
            }
        },
        confirmButton = { Button(onClick = onApprove) { Text("Approve") } },
        dismissButton = { TextButton(onClick = onReject) { Text("Reject") } },
    )
}

@Composable
private fun ScanStateMessage(state: ScanQrUiState, onScanAgain: () -> Unit) {
    when (state) {
        ScanQrUiState.NeedsCameraPermissionExplanation ->
            InfoText("Grant camera permission or paste a BeamDrop QR payload.")

        ScanQrUiState.Ready ->
            InfoText("Ready to scan. No trust will be stored until you approve.")

        is ScanQrUiState.PendingApproval ->
            InfoText("Pairing request pending approval.")

        is ScanQrUiState.Trusted ->
            InfoText("${state.peer.displayName} is now trusted.")

        is ScanQrUiState.Error -> {
            ErrorText(state.error.userMessage())
            Spacer(Modifier.height(8.dp))
            OutlinedButton(onClick = onScanAgain) {
                Icon(Icons.Outlined.Refresh, contentDescription = null)
                Spacer(Modifier.size(8.dp))
                Text("Scan again")
            }
        }
    }
}

private fun PairingError.userMessage(): String = when (this) {
    PairingError.LocalNetworkPermissionDenied -> "Local network permission denied. Enable nearby Wi-Fi access to discover devices."
    PairingError.NoDevicesFound -> "No BeamDrop devices found. Try QR pairing, manual endpoint entry, or network diagnostics."
    PairingError.QrInvalid -> "QR invalid. Scan a current BeamDrop pairing QR code."
    PairingError.QrExpired -> "QR expired. Ask the other device to refresh its QR code."
    PairingError.PairingRejected -> "Pairing rejected. No trust was stored."
    PairingError.DeviceAlreadyTrusted -> "Device already trusted. Open trusted devices to view it."
    PairingError.ProtocolUnsupported -> "Protocol mismatch. One BeamDrop app needs to be updated."
    PairingError.ServiceNameMismatch -> "QR is not for the BeamDrop local service."
    PairingError.DevicePreviouslyRevoked -> "This device was revoked. Re-pairing requires deliberate approval."
}

package com.beamdrop.android.core.transfer

import android.content.Context
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.InputStream
import java.io.OutputStream

class AppPrivateReceiveTargetFactory(
    private val context: Context,
) : ReceiveTargetFactory {
    override fun create(metadata: TransferMetadata): ReceiveTarget {
        val safeName = metadata.fileName.safeFileName()
        val receiveDir = File(context.getExternalFilesDir(null) ?: context.filesDir, "BeamDrop/Received")
        val stagingDir = File(context.cacheDir, "beamdrop-staging").apply { mkdirs() }
        receiveDir.mkdirs()
        val stagingFile = File(stagingDir, "${metadata.transferId}.part")
        val destination = uniqueDestination(receiveDir, safeName)
        return AppPrivateReceiveTarget(stagingFile, destination)
    }

    private fun uniqueDestination(directory: File, fileName: String): File {
        val base = fileName.substringBeforeLast('.', fileName)
        val extension = fileName.substringAfterLast('.', missingDelimiterValue = "")
        var candidate = File(directory, fileName)
        var copy = 1
        while (candidate.exists()) {
            val name = if (extension.isBlank()) "$base-$copy" else "$base-$copy.$extension"
            candidate = File(directory, name)
            copy++
        }
        return candidate
    }
}

private class AppPrivateReceiveTarget(
    private val stagingFile: File,
    private val destination: File,
) : ReceiveTarget {
    override fun openOutputStream(): OutputStream = FileOutputStream(stagingFile)

    override fun openInputStreamForVerification(): InputStream = FileInputStream(stagingFile)

    override fun commitVerified() {
        destination.parentFile?.mkdirs()
        if (!stagingFile.renameTo(destination)) {
            FileInputStream(stagingFile).use { input ->
                FileOutputStream(destination).use { output -> input.copyTo(output) }
            }
            stagingFile.delete()
        }
    }

    override fun discard() {
        stagingFile.delete()
    }
}

private fun String.safeFileName(): String {
    val cleaned = replace(Regex("[/\\\\:\\u0000-\\u001F]"), "_").trim()
    return cleaned.takeIf { it.isNotBlank() }?.take(180) ?: "BeamDrop file"
}


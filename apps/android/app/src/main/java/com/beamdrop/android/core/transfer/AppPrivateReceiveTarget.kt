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
        val safeName = SafeFileName.requireSafe(metadata.fileName)
        val receiveDir = File(context.getExternalFilesDir(null) ?: context.filesDir, "BeamDrop/Received")
        val stagingDir = File(context.cacheDir, "beamdrop-staging").apply { mkdirs() }
        receiveDir.mkdirs()
        val stagingFile = File(stagingDir, "${metadata.transferId}.part")
        val destination = uniqueDestination(receiveDir, safeName)
        require(destination.isInside(receiveDir)) { "Received file path escapes the BeamDrop save directory." }
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

object SafeFileName {
    private val disallowed = Regex("[/\\\\:\\u0000-\\u001F]")

    fun requireSafe(fileName: String): String {
        val trimmed = fileName.trim()
        require(trimmed.isNotBlank()) { "File name is required." }
        require(trimmed != "." && trimmed != "..") { "Path traversal file names are not allowed." }
        require(!disallowed.containsMatchIn(trimmed)) { "File name must not contain path separators or control characters." }
        return trimmed.take(180)
    }
}

private fun File.isInside(directory: File): Boolean {
    val root = directory.canonicalFile
    val child = canonicalFile
    return child.path == root.path || child.path.startsWith(root.path + File.separator)
}

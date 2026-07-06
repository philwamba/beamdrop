package com.beamdrop.android.core.transfer

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class SafeFileNameTest {
    @Test
    fun ordinaryFileNameIsAccepted() {
        assertEquals("notes.txt", SafeFileName.requireSafe(" notes.txt "))
    }

    @Test
    fun pathTraversalFileNameIsRejected() {
        assertThrows(IllegalArgumentException::class.java) {
            SafeFileName.requireSafe("../secret.txt")
        }
        assertThrows(IllegalArgumentException::class.java) {
            SafeFileName.requireSafe("..\\secret.txt")
        }
    }
}

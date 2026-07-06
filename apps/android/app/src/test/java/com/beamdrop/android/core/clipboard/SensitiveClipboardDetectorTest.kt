package com.beamdrop.android.core.clipboard

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SensitiveClipboardDetectorTest {
    @Test
    fun sensitiveClipboardItemIsBlocked() {
        assertTrue(SensitiveClipboardDetector.looksSensitive("password=correct-horse-battery-staple"))
        assertTrue(SensitiveClipboardDetector.looksSensitive("Bearer abcdefghijklmnopqrstuvwxyz"))
    }

    @Test
    fun ordinaryClipboardTextIsAllowed() {
        assertFalse(SensitiveClipboardDetector.looksSensitive("Lunch at 12 near the office"))
    }
}

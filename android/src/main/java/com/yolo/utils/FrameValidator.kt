package com.yolo.utils

import android.util.Log
import com.margelo.nitro.camera.HybridFrameSpec


object FrameValidator {
    private const val TAG = "YOLO_TAG_FrameValidator"
    fun isValidYuv(frame: HybridFrameSpec): Boolean {
        if (!frame.isValid) {
            Log.e(TAG, "❌ Frame is not valid")
            return false
        }

        val planes = frame.getPlanes()
        if (planes.size < 3) {
            Log.e(TAG, "❌ Expected 3 YUV planes, got ${planes.size}")
            return false
        }

        planes.forEachIndexed { index, plane ->
            if (!plane.isValid) {
                Log.e(TAG, "❌ Plane $index is not valid")
                return false
            }
        }
        return true
    }
}
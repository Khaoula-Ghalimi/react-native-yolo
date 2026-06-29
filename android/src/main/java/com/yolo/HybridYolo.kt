package com.yolo

import android.util.Base64
import android.util.Log

import com.margelo.nitro.camera.HybridFrameSpec
import com.margelo.nitro.yolo.HybridYoloModelSpec
import com.margelo.nitro.yolo.HybridYoloSpec

import com.yolo.utils.FrameJpegConverter
import com.yolo.utils.FrameValidator


class HybridYolo : HybridYoloSpec() {
    companion object {
        private const val TAG = "YOLO_TAG"
    }
    override fun loadModel(modelPath: String): HybridYoloModelSpec {
        Log.d(TAG, "Trying to load model object: $modelPath")
        return HybridYoloModel(modelPath)
    }
    override fun frameToBase64(frame: HybridFrameSpec): String {
        return try {
            if (!FrameValidator.isValidYuv(frame)) return ""

            val jpegBytes = FrameJpegConverter.toJpegBytes(
            frame = frame,
            quality = 80
            )

            Base64.encodeToString(jpegBytes, Base64.NO_WRAP)
        } catch (e: Exception) {
            Log.e(TAG, "❌ frameToBase64 failed", e)
            ""
        }
    }
}

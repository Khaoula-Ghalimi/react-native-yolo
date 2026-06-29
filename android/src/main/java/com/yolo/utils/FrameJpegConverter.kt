package com.yolo.utils

import android.util.Log
import com.margelo.nitro.camera.HybridFrameSpec
import kotlin.math.roundToInt

object FrameJpegConverter {
    private const val TAG = "YOLO_TAG_FrameJpegConverter"
    fun toJpegBytes(frame : HybridFrameSpec, quality: Int = 80): ByteArray {
        val width = frame.width.roundToInt()
        val height = frame.height.roundToInt()

        val nv21 = Yuv420ToNv21Converter.convert(frame, width, height)

        val jpegBytes = Nv21JpegEncoder.encode(
            nv21 = nv21,
            width = width,
            height = height,
            quality = quality
        )
        return BitmapOrientationFixer.fix(
            jpegBytes = jpegBytes,
            frame = frame,
            quality = quality
        )
    }
}
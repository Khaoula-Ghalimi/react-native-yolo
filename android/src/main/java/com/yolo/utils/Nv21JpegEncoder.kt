package com.yolo.utils

import android.graphics.ImageFormat
import android.graphics.Rect
import android.graphics.YuvImage
import java.io.ByteArrayOutputStream


object Nv21JpegEncoder {
    fun encode(
        nv21: ByteArray,
        width: Int,
        height: Int,
        quality: Int
    ): ByteArray {
        val yuvImage = YuvImage(
        nv21,
        ImageFormat.NV21,
        width,
        height,
        null
        )

        val output = ByteArrayOutputStream()

        yuvImage.compressToJpeg(
        Rect(0, 0, width, height),
        quality,
        output
        )

        return output.toByteArray()
    }
}
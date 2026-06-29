package com.yolo.utils

import com.margelo.nitro.camera.HybridFrameSpec
import kotlin.math.roundToInt
import android.util.Log

object Yuv420ToNv21Converter {
    fun convert(frame: HybridFrameSpec, width: Int, height: Int): ByteArray {

        val planes = frame.getPlanes()

        val yPlane = planes[0]
        val uPlane = planes[1]
        val vPlane = planes[2]

        val yBytes = yPlane.getPixelBuffer().toByteArray()
        val uBytes = uPlane.getPixelBuffer().toByteArray()
        val vBytes = vPlane.getPixelBuffer().toByteArray()

        val yRowStride = yPlane.bytesPerRow.roundToInt()
        val uRowStride = uPlane.bytesPerRow.roundToInt()
        val vRowStride = vPlane.bytesPerRow.roundToInt()

        val ySize = width * height
        val uvSize = width * height / 2
        val nv21 = ByteArray(ySize + uvSize)

        var dst = 0

        for (row in 0 until height) {
            val src = row * yRowStride
            if (src + width > yBytes.size) break

            System.arraycopy(yBytes, src, nv21, dst, width)
            dst += width
        }

        val chromaWidth = width / 2
        val chromaHeight = height / 2

        var uvDst = ySize

        for (row in 0 until chromaHeight) {
            for (col in 0 until chromaWidth) {
                val uIndex = row * uRowStride + col * 2
                val vIndex = row * vRowStride + col * 2

                if (
                uIndex >= uBytes.size ||
                vIndex >= vBytes.size ||
                uvDst + 1 >= nv21.size
                ) {
                return nv21
                }

                nv21[uvDst++] = vBytes[vIndex]
                nv21[uvDst++] = uBytes[uIndex]
            }
        }
        return nv21
    }
}
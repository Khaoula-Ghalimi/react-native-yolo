package com.yolo

import android.net.Uri
import android.util.Log
import com.margelo.nitro.NitroModules
import com.margelo.nitro.yolo.HybridYoloSpec
import java.io.File
import java.io.RandomAccessFile
import java.net.URL
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel
import org.tensorflow.lite.Interpreter
import org.tensorflow.lite.support.common.FileUtil
import yolo.com.loader.YoloModelLoader
import com.margelo.nitro.camera.HybridFrameSpec

import android.util.Base64
import com.yolo.utils.FrameJpegConverter
import com.yolo.utils.FrameValidator

import com.margelo.nitro.yolo.Detection
import com.margelo.nitro.yolo.BoundingBox

import java.nio.ByteBuffer
import java.nio.ByteOrder
import org.tensorflow.lite.DataType
import kotlin.math.roundToInt


class HybridYolo : HybridYoloSpec() {
    companion object {
        private const val TAG = "YOLO_TAG"
    }
    private var interpreter: Interpreter? = null

    private var inputBuffer: ByteBuffer? = null
    private var inputWidth = 0
    private var inputHeight = 0
    private var inputDataType: DataType? = null

    private val modelLoader = YoloModelLoader()

    override fun sum(num1: Double, num2: Double): Double {
        return num1 + num2
    }

    override fun loadModel(modelPath: String) {
        val context =
                NitroModules.applicationContext ?: throw IllegalStateException("Context is null")

        Log.d(TAG, "Trying to load: $modelPath")

        try {
            val modelBuffer = modelLoader.load(modelPath)

            interpreter?.close()
            interpreter = Interpreter(modelBuffer)

            val inputTensor = interpreter!!.getInputTensor(0)
            val shape = inputTensor.shape()

            inputHeight = shape[1]
            inputWidth = shape[2]
            inputDataType = inputTensor.dataType()
            inputBuffer = modelLoader.makeInputBuffer(interpreter!!)

            val outputTensor = interpreter!!.getOutputTensor(0)
            Log.d(TAG, "✅ YOLO model loaded")
            Log.d(TAG, "📥 Input shape: ${inputTensor.shape().contentToString()}")
            Log.d(TAG, "📤 Output shape: ${outputTensor.shape().contentToString()}")
            Log.d(TAG, "📥 Input type: ${inputTensor.dataType()}")
            Log.d(TAG, "📤 Output type: ${outputTensor.dataType()}")

            Log.d(TAG, "Input shape=${shape.contentToString()} type=$inputDataType")
            Log.d(TAG, "✅ Model loaded successfully!")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to load model: ${e.message}", e)
        }
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

    override fun detect(frame: HybridFrameSpec): Array<Detection> {
        val localInterpreter = interpreter ?: run {
            Log.e(TAG, "❌ Model is not loaded. Please call loadModel() first.")
            return emptyArray()
        }

        if (!FrameValidator.isValidYuv(frame)) {
            Log.e(TAG, "❌ Invalid frame provided for detection.")
            return emptyArray()
        }

        val input = inputBuffer ?: return emptyArray()

        fillInputFromYuvFrame(
            frame = frame,
            input = input,
            dstWidth = inputWidth,
            dstHeight = inputHeight,
            dataType = inputDataType ?: DataType.FLOAT32
        )

        val output = Array(1) { Array(300) { FloatArray(6) } }

        localInterpreter.run(input, output)

        val detections = parseNmsOutput(output, confidenceThreshold = 0.5f)
        if (detections.isEmpty()) {
            val best = output[0].maxByOrNull { it[4] }
            Log.d(TAG, "No detections. Best row=${best?.contentToString()}")
        } else {
            Log.d(TAG, "✅ Detections: ${detections.size}")
        }


        return detections.toTypedArray()
    }

    private fun parseNmsOutput(
        output: Array<Array<FloatArray>>,
        confidenceThreshold: Float = 0.5f
    ): List<Detection> {
        val detections = mutableListOf<Detection>()

        val batchMatrix = output[0]

        for (i in batchMatrix.indices) {
            val row = batchMatrix[i]

            val score = row[4]
            if (score < confidenceThreshold) continue

            val x1 = row[0].toDouble()
            val y1 = row[1].toDouble()
            val x2 = row[2].toDouble()
            val y2 = row[3].toDouble()
            val classId = row[5].toDouble()

            detections.add(
                Detection(
                    boundingBox = BoundingBox(
                        x1 = x1,
                        y1 = y1,
                        x2 = x2,
                        y2 = y2
                    ),
                    score = score.toDouble(),
                    classId = classId
                )
            )
        }

        return detections
    }



    private fun fillInputFromYuvFrame(
        frame: HybridFrameSpec,
        input: ByteBuffer,
        dstWidth: Int,
        dstHeight: Int,
        dataType: DataType
    ) {
        val srcWidth = frame.width.toInt()
        val srcHeight = frame.height.toInt()

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

        input.rewind()

        for (dy in 0 until dstHeight) {
            // val sy = dy * srcHeight / dstHeight

            for (dx in 0 until dstWidth) {
                val srcX = dy * srcWidth / dstHeight
                val srcY = srcHeight - 1 - (dx * srcHeight / dstWidth)

                val yIndex = srcY * yRowStride + srcX

                val uvX = srcX / 2
                val uvY = srcY / 2

                val uIndex = uvY * uRowStride + uvX * 2
                val vIndex = uvY * vRowStride + uvX * 2

                if (
                    yIndex >= yBytes.size ||
                    uIndex >= uBytes.size ||
                    vIndex >= vBytes.size
                ) {
                    continue
                }

                val y = yBytes[yIndex].toInt() and 0xFF
                val u = uBytes[uIndex].toInt() and 0xFF
                val v = vBytes[vIndex].toInt() and 0xFF

                val rFloat = y + 1.402f * (v - 128)
                val gFloat = y - 0.344136f * (u - 128) - 0.714136f * (v - 128)
                val bFloat = y + 1.772f * (u - 128)

                val r = rFloat.roundToInt().coerceIn(0, 255)
                val g = gFloat.roundToInt().coerceIn(0, 255)
                val b = bFloat.roundToInt().coerceIn(0, 255)

                when (dataType) {
                    DataType.FLOAT32 -> {
                        input.putFloat(r / 255f)
                        input.putFloat(g / 255f)
                        input.putFloat(b / 255f)
                    }

                    DataType.UINT8 -> {
                        input.put(r.toByte())
                        input.put(g.toByte())
                        input.put(b.toByte())
                    }

                    else -> error("Unsupported input type: $dataType")
                }
            }
        }
        input.rewind()
    }

    private fun yuvToRgb(y: Int, u: Int, v: Int): IntArray {
        val yf = y.toFloat()
        val uf = u.toFloat() - 128f
        val vf = v.toFloat() - 128f

        val r = (yf + 1.402f * vf).roundToInt().coerceIn(0, 255)
        val g = (yf - 0.344136f * uf - 0.714136f * vf).roundToInt().coerceIn(0, 255)
        val b = (yf + 1.772f * uf).roundToInt().coerceIn(0, 255)

        return intArrayOf(r, g, b)
    }

}

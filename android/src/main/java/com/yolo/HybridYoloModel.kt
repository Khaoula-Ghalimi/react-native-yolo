package com.yolo

import android.util.Log
import com.margelo.nitro.yolo.HybridYoloModelSpec
import com.margelo.nitro.yolo.Detection
import com.margelo.nitro.yolo.BoundingBox
import com.margelo.nitro.camera.HybridFrameSpec
import com.yolo.utils.FrameValidator
import java.nio.ByteBuffer
import org.tensorflow.lite.DataType
import org.tensorflow.lite.Interpreter
import yolo.com.loader.YoloModelLoader
import kotlin.math.roundToInt
import com.margelo.nitro.camera.CameraOrientation

class HybridYoloModel(
    modelPath: String
) : HybridYoloModelSpec() {

    companion object {
        private const val TAG = "YOLO_MODEL_TAG"
    }

    private val modelLoader = YoloModelLoader()

    private var interpreter: Interpreter? = null
    private var inputBuffer: ByteBuffer? = null
    private var inputWidth = 0
    private var inputHeight = 0
    private var inputDataType: DataType? = null

    private val lock = Any()

    init {
        load(modelPath)
    }

    private fun load(modelPath: String) {
        try {
            val modelBuffer = modelLoader.load(modelPath)

            interpreter = Interpreter(modelBuffer)

            val localInterpreter = interpreter!!

            val inputTensor = localInterpreter.getInputTensor(0)
            val outputTensor = localInterpreter.getOutputTensor(0)

            val shape = inputTensor.shape()

            inputHeight = shape[1]
            inputWidth = shape[2]
            inputDataType = inputTensor.dataType()
            inputBuffer = modelLoader.makeInputBuffer(localInterpreter)

            Log.d(TAG, "✅ YOLO model instance loaded")
            Log.d(TAG, "📥 Input shape: ${inputTensor.shape().contentToString()}")
            Log.d(TAG, "📤 Output shape: ${outputTensor.shape().contentToString()}")
            Log.d(TAG, "📥 Input type: ${inputTensor.dataType()}")
            Log.d(TAG, "📤 Output type: ${outputTensor.dataType()}")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to load model instance", e)
        }
    }

    override fun detect(frame: HybridFrameSpec): Array<Detection> {
        val localInterpreter = interpreter ?: run {
            Log.e(TAG, "❌ This model instance is not loaded.")
            return emptyArray()
        }

        if (!FrameValidator.isValidYuv(frame)) {
            Log.e(TAG, "❌ Invalid frame provided for detection.")
            return emptyArray()
        }

        val input = inputBuffer ?: return emptyArray()

        synchronized(lock) {
            input.rewind()

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

            return detections.toTypedArray()
        }
    }

    override fun close() {
        interpreter?.close()
        interpreter = null
        inputBuffer = null
        Log.d(TAG, "🧹 YOLO model disposed")
    }

    private fun parseNmsOutput(
        output: Array<Array<FloatArray>>,
        confidenceThreshold: Float = 0.5f
    ): List<Detection> {
        val detections = mutableListOf<Detection>()

        for (row in output[0]) {
            val score = row[4]
            if (score < confidenceThreshold) continue

            detections.add(
                Detection(
                    boundingBox = BoundingBox(
                        x1 = row[0].toDouble(),
                        y1 = row[1].toDouble(),
                        x2 = row[2].toDouble(),
                        y2 = row[3].toDouble()
                    ),
                    score = score.toDouble(),
                    classId = row[5].toDouble()
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
            for (dx in 0 until dstWidth) {
                val (srcX, srcY) = mapModelPixelToFramePixel(
                    dx = dx,
                    dy = dy,
                    dstWidth = dstWidth,
                    dstHeight = dstHeight,
                    srcWidth = srcWidth,
                    srcHeight = srcHeight,
                    orientation = frame.orientation
                )

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

    private fun mapModelPixelToFramePixel(
        dx: Int,
        dy: Int,
        dstWidth: Int,
        dstHeight: Int,
        srcWidth: Int,
        srcHeight: Int,
        orientation: CameraOrientation
    ): Pair<Int, Int> {
        val nx = dx.toFloat() / dstWidth
        val ny = dy.toFloat() / dstHeight

        return when (orientation) {
            CameraOrientation.UP -> {
                val srcX = (nx * srcWidth).toInt()
                val srcY = (ny * srcHeight).toInt()
                srcX.coerceIn(0, srcWidth - 1) to srcY.coerceIn(0, srcHeight - 1)
            }

            CameraOrientation.DOWN -> {
                val srcX = ((1f - nx) * srcWidth).toInt()
                val srcY = ((1f - ny) * srcHeight).toInt()
                srcX.coerceIn(0, srcWidth - 1) to srcY.coerceIn(0, srcHeight - 1)
            }

            CameraOrientation.LEFT -> {
                val srcX = (ny * srcWidth).toInt()
                val srcY = ((1f - nx) * srcHeight).toInt()
                srcX.coerceIn(0, srcWidth - 1) to srcY.coerceIn(0, srcHeight - 1)
            }

            CameraOrientation.RIGHT -> {
                val srcX = ((1f - ny) * srcWidth).toInt()
                val srcY = (nx * srcHeight).toInt()
                srcX.coerceIn(0, srcWidth - 1) to srcY.coerceIn(0, srcHeight - 1)
            }
        }
    }
}
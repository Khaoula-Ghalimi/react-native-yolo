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




class HybridYolo : HybridYoloSpec() {
    private var interpreter: Interpreter? = null
    private val modelLoader = YoloModelLoader()

    override fun sum(num1: Double, num2: Double): Double {
        return num1 + num2
    }

    override fun loadModel(modelPath: String) {
        val context =
                NitroModules.applicationContext ?: throw IllegalStateException("Context is null")

        Log.d("YOLO_TAG", "Trying to load: $modelPath")

        try {
            val modelBuffer = modelLoader.load(modelPath)

            interpreter?.close()
            interpreter = Interpreter(modelBuffer)

            Log.d("YOLO_TAG", "✅ Model loaded successfully!")
        } catch (e: Exception) {
            Log.e("YOLO_TAG", "❌ Failed to load model: ${e.message}", e)
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
            Log.e("YOLO_TAG", "❌ frameToBase64 failed", e)
            ""
        }
    }

}

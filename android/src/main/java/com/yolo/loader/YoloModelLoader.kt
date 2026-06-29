package yolo.com.loader

import android.net.Uri
import android.util.Log
import com.yolo.utils.ContextProvider
import java.io.File
import java.io.RandomAccessFile
import java.net.URL
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel
import org.tensorflow.lite.support.common.FileUtil

import org.tensorflow.lite.DataType
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.roundToInt
import org.tensorflow.lite.Interpreter



/**
 * A utility class for loading YOLO models from various sources, including URLs, file URIs, absolute paths, and APK assets.
 * This class provides methods to load a model into a MappedByteBuffer, which can be used with TensorFlow Lite's Interpreter for inference.
 * It also includes methods to copy raw resources to the cache directory and map files for efficient reading
 */
class YoloModelLoader {
    companion object {
        private const val TAG = "YOLO_TAG_LOADER"
    }

    /**
     * Loads a YOLO model from the specified path. The path can be a URL, a file URI, an absolute
     * path, or an asset name.
     * @param modelPath The path to the YOLO model.
     * @return A MappedByteBuffer containing the model data.
     * @throws IllegalArgumentException if the model cannot be loaded from the specified path.
     */
    fun load(modelPath: String): MappedByteBuffer {
        val context = ContextProvider.context

        return when {
            modelPath.startsWith("http://") || modelPath.startsWith("https://") -> {
                Log.d(TAG, "Loading model from URL")
                val cachedFile = downloadToCache(modelPath)
                mapFile(cachedFile)
            }
            modelPath.startsWith("file://") -> {
                Log.d(TAG, "Loading model from file URI")
                val file = File(Uri.parse(modelPath).path!!)
                mapFile(file)
            }
            modelPath.startsWith("/") -> {
                Log.d(TAG, "Loading model from absolute path")
                mapFile(File(modelPath))
            }
            modelPath.startsWith("assets_") -> {
                Log.d(TAG, "Loading model from RN raw resource")
                val file = copyRawResourceToCache(modelPath)
                mapFile(file)
            }
            else -> {
                Log.d(TAG, "Loading model from APK assets")
                FileUtil.loadMappedFile(context, modelPath)
            }
        }
    }

    /**
     * Copies a raw resource to the cache directory and returns the corresponding File object.
     * @param resourceName The name of the raw resource (without the file extension).
     * @return The File object pointing to the copied resource in the cache directory.
     * @throws IllegalArgumentException if the raw resource is not found.
     */
    private fun copyRawResourceToCache(resourceName: String): File {
        val context = ContextProvider.context

        val resId = context.resources.getIdentifier(resourceName, "raw", context.packageName)

        if (resId == 0) {
            throw IllegalArgumentException("Raw resource not found: $resourceName")
        }

        val file = File(context.cacheDir, "$resourceName.tflite")

        context.resources.openRawResource(resId).use { input ->
            file.outputStream().use { output -> input.copyTo(output) }
        }

        Log.d(TAG, "Copied raw resource to: ${file.absolutePath}")
        Log.d(TAG, "Copied raw resource size: ${file.length()} bytes")

        return file
    }

    /**
     * Maps a file to a MappedByteBuffer for efficient reading.
     * @param file The file to be mapped.
     * @return A MappedByteBuffer containing the file data.
     * @throws IllegalArgumentException if the file does not exist or is empty.
     */
    private fun mapFile(file: File): MappedByteBuffer {
        if (!file.exists()) {
            throw IllegalArgumentException("Model file does not exist: ${file.absolutePath}")
        }

        if (file.length() <= 0) {
            throw IllegalArgumentException("Model file is empty: ${file.absolutePath}")
        }

        val randomAccessFile = RandomAccessFile(file, "r")
        val fileChannel = randomAccessFile.channel

        return fileChannel.map(FileChannel.MapMode.READ_ONLY, 0, fileChannel.size())
    }

    /**
     * Downloads a file from a URL to the cache directory and returns the corresponding File object.
     * @param urlString The URL of the file to download.
     * @return The File object pointing to the downloaded file in the cache directory.
     * @throws IllegalArgumentException if the file cannot be downloaded.
     */
    private fun downloadToCache(urlString: String): File {
        val context = ContextProvider.context

        val file = File(context.cacheDir, "yolo_model.tflite")

        URL(urlString).openStream().use { input ->
            file.outputStream().use { output -> input.copyTo(output) }
        }

        Log.d(TAG, "Downloaded model to: ${file.absolutePath}")
        Log.d(TAG, "Downloaded model size: ${file.length()} bytes")

        return file
    }


    fun makeInputBuffer(interpreter: Interpreter): ByteBuffer {
        val inputTensor = interpreter.getInputTensor(0)
        val shape = inputTensor.shape() // usually [1, 640, 640, 3]
        val dataType = inputTensor.dataType()

        val batch = shape[0]
        val height = shape[1]
        val width = shape[2]
        val channels = shape[3]

        require(batch == 1)
        require(channels == 3)

        val bytesPerValue = when (dataType) {
            DataType.FLOAT32 -> 4
            DataType.UINT8 -> 1
            else -> error("Unsupported input type: $dataType")
        }

        return ByteBuffer
            .allocateDirect(batch * width * height * channels * bytesPerValue)
            .order(ByteOrder.nativeOrder())
    }
}

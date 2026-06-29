package com.yolo.utils

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import com.margelo.nitro.camera.HybridFrameSpec
import java.io.ByteArrayOutputStream



object BitmapOrientationFixer {
  fun fix(
    jpegBytes: ByteArray,
    frame: HybridFrameSpec,
    quality: Int
  ): ByteArray {
    val bitmap = BitmapFactory.decodeByteArray(
      jpegBytes,
      0,
      jpegBytes.size
    ) ?: return jpegBytes

    val rotationDegrees = 90f //TODO: Get the actual rotation degrees from the frame metadata if available

    val matrix = Matrix().apply {
      postRotate(rotationDegrees)

      if (frame.isMirrored) {
        postScale(-1f, 1f)
      }
    }

    val rotatedBitmap = Bitmap.createBitmap(
      bitmap,
      0,
      0,
      bitmap.width,
      bitmap.height,
      matrix,
      true
    )

    val output = ByteArrayOutputStream()

    rotatedBitmap.compress(
      Bitmap.CompressFormat.JPEG,
      quality,
      output
    )

    bitmap.recycle()
    rotatedBitmap.recycle()

    return output.toByteArray()
  }
}
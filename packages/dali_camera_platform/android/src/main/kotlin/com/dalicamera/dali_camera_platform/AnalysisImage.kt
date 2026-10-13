package com.dalicamera.dali_camera_platform

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Matrix
import androidx.camera.core.ImageProxy
import kotlin.math.max
import kotlin.math.min

internal fun analysisImage(proxy: ImageProxy, front: Boolean): Bitmap {
    val scale = min(1.0, 160.0 / max(proxy.width, proxy.height))
    val width = max(1, (proxy.width * scale).toInt()); val height = max(1, (proxy.height * scale).toInt())
    val pixels = IntArray(width * height)
    val planes = proxy.planes; val buffers = planes.map { it.buffer.duplicate() }
    fun sample(plane: Int, x: Int, y: Int): Int {
        val index = y * planes[plane].rowStride + x * planes[plane].pixelStride
        return if (index < buffers[plane].limit()) buffers[plane].get(index).toInt() and 255 else 128
    }
    for (y in 0 until height) for (x in 0 until width) {
        val sx = min(proxy.width - 1, (x / scale).toInt()); val sy = min(proxy.height - 1, (y / scale).toInt())
        val l = sample(0, sx, sy) - 16; val u = sample(1, sx / 2, sy / 2) - 128; val v = sample(2, sx / 2, sy / 2) - 128
        pixels[y * width + x] = Color.rgb(((298 * l + 409 * v + 128) shr 8).coerceIn(0, 255), ((298 * l - 100 * u - 208 * v + 128) shr 8).coerceIn(0, 255), ((298 * l + 516 * u + 128) shr 8).coerceIn(0, 255))
    }
    val source = Bitmap.createBitmap(pixels, width, height, Bitmap.Config.ARGB_8888)
    val matrix = Matrix().apply { setRotate(proxy.imageInfo.rotationDegrees.toFloat()); if (front) postScale(-1f, 1f) }
    val result = Bitmap.createBitmap(source, 0, 0, width, height, matrix, true)
    if (result !== source) source.recycle()
    return result
}

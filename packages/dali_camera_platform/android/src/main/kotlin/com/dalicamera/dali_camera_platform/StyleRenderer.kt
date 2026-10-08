package com.dalicamera.dali_camera_platform

import android.graphics.Bitmap
import android.graphics.Color

/** Small spatial kernel for optional review softness and detail, never the original. */
internal object StyleRenderer {
    fun finish(bitmap: Bitmap, softness: Double, detail: Double) {
        val width = bitmap.width; val height = bitmap.height
        val input = IntArray(width * height)
        val output = IntArray(input.size)
        bitmap.getPixels(input, 0, width, 0, 0, width, height)
        val mix = softness / 5 * 0.45
        val sharpen = detail / 5 * 0.4
        for (y in 0 until height) for (x in 0 until width) {
            var r = 0; var g = 0; var b = 0
            for (dy in -1..1) for (dx in -1..1) {
                val pixel = input[(y+dy).coerceIn(0, height-1)*width + (x+dx).coerceIn(0, width-1)]
                r += Color.red(pixel); g += Color.green(pixel); b += Color.blue(pixel)
            }
            val pixel = input[y*width+x]
            fun channel(value: Int, sum: Int): Int {
                val average = sum / 9.0
                return (value + (average-value)*mix + (value-average)*sharpen).toInt().coerceIn(0, 255)
            }
            output[y*width+x] = Color.rgb(channel(Color.red(pixel), r), channel(Color.green(pixel), g), channel(Color.blue(pixel), b))
        }
        bitmap.setPixels(output, 0, width, 0, 0, width, height)
    }
}

package com.dalicamera.dali_camera_platform

import android.graphics.Bitmap
import android.graphics.Color
import org.json.JSONObject
import kotlin.math.*

/** Image measurements only: device attitude is deliberately never used as a horizon. */
internal object PhotoGeometry {
    fun horizon(image: Bitmap): JSONObject? {
        val w = min(240, image.width); val h = max(3, image.height * w / image.width)
        val small = Bitmap.createScaledBitmap(image, w, h, true)
        try {
            val luma = DoubleArray(w * h) { i -> val c = small.getPixel(i % w, i / w); .2126 * Color.red(c) + .7152 * Color.green(c) + .0722 * Color.blue(c) }
            var bestScore = 0.0; var bestAngle = 0; var bestCoverage = 0.0
            // Weighted near-horizontal edge voting. Require a long, consistent edge;
            // texture, blank scenes and steep lines return unavailable rather than a correction.
            for (angle in -20..20) {
                val slope = tan(Math.toRadians(angle.toDouble()))
                val bins = DoubleArray(h + w); val coverage = IntArray(h + w)
                for (x in 1 until w - 1 step 2) {
                    val column = HashSet<Int>()
                    for (y in 1 until h - 1) {
                        val gy = luma[(y + 1) * w + x] - luma[(y - 1) * w + x]
                        val gx = luma[y * w + x + 1] - luma[y * w + x - 1]
                        if (abs(gy) < 25 || abs(gx + slope * gy) > abs(gy) * .30) continue
                        val bin = (y - slope * x + w / 2).roundToInt()
                        if (bin in bins.indices) { bins[bin] += min(100.0, abs(gy)); column.add(bin) }
                    }
                    for (bin in column) coverage[bin]++
                }
                for (i in 1 until bins.size - 1) {
                    val support = (coverage[i - 1] + coverage[i] + coverage[i + 1]).toDouble() / (w / 2)
                    val score = bins[i - 1] + bins[i] + bins[i + 1]
                    if (support >= .60 && score > bestScore) { bestScore = score; bestAngle = angle; bestCoverage = support }
                }
            }
            if (bestScore < w * 12 || abs(bestAngle) == 20) return null
            return JSONObject().put("angleDegrees", bestAngle).put("confidence", min(.95, .55 + bestCoverage * .20))
                .put("method", "imageGradientLineVoting")
        } finally { if (small !== image) small.recycle() }
    }

    fun reframe(person: JSONObject?, portrait: Boolean): JSONObject? {
        if (person == null || person.optDouble("confidence") <= .35) return null
        val x = person.getDouble("x"); val y = person.getDouble("y"); val w = person.getDouble("width"); val h = person.getDouble("height")
        var left = x - w * .42; var top = min(y - h * .18, max(0.0, y - .08))
        val right = max(x + w * 1.42, x + w * 1.35); val bottom = max(y + h * 1.18, max(0.0, y - .08) + h * 1.24)
        var width = right - left; var height = bottom - top; val target = if (portrait) .75 else 4.0 / 3
        if (width / max(.001, height) < target) { val next = height * target; left -= (next - width) / 2; width = next }
        else { val next = width / target; top -= (next - height) / 2; height = next }
        width = width.coerceIn(.1, 1.0); height = height.coerceIn(.1, 1.0); left = left.coerceIn(0.0, 1 - width); top = top.coerceIn(0.0, 1 - height)
        if (left <= .02 && top <= .02 && 1 - width <= .02 && 1 - height <= .02) return null
        return JSONObject().put("cropRect", JSONObject().put("x", left).put("y", top).put("width", width).put("height", height))
            .put("targetAspectRatio", target).put("confidence", person.optDouble("confidence")).put("instruction", "Suggested reframe")
    }
}

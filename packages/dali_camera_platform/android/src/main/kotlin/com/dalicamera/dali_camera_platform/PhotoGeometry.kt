package com.dalicamera.dali_camera_platform

import android.graphics.Bitmap
import android.graphics.Color
import org.json.JSONObject
import kotlin.math.*

/** Image measurements only: device attitude is deliberately never used as a horizon. */
internal object PhotoGeometry {
    fun personFromFace(face: JSONObject): JSONObject {
        val width = min(.9, face.getDouble("width") * 3)
        val height = min(.95, face.getDouble("height") * 6.2)
        val x = (face.getDouble("x") + face.getDouble("width") / 2 - width / 2).coerceIn(0.0, 1 - width)
        val y = (face.getDouble("y") - face.getDouble("height") * .45).coerceIn(0.0, 1 - height)
        return JSONObject().put("x", x).put("y", y).put("width", width).put("height", height).put("confidence", face.getDouble("confidence") * .72).put("label", "person_estimated")
    }
    fun scenic(image: Bitmap): JSONObject {
        val packet = JSONObject().put("openAreaStatus", "valid").put("saliencyStatus", "valid").put("horizonStatus", "valid").put("luminanceScale", 255)
        val w = min(120, image.width); val h = max(1, image.height * w / image.width)
        val small = Bitmap.createScaledBitmap(image, w, h, true)
        try {
            val colors = IntArray(w * h); small.getPixels(colors, 0, w, 0, 0, w, h)
            val r = colors.map { Color.red(it).toDouble() }; val g = colors.map { Color.green(it).toDouble() }; val b = colors.map { Color.blue(it).toDouble() }
            val meanR = r.average(); val meanG = g.average(); val meanB = b.average()
            packet.put("backgroundLuminance", .2126 * meanR + .7152 * meanG + .0722 * meanB)
            var upper = 0; var open = 0
            for (y in 0 until max(1, h / 3)) for (x in 0 until w) { val i = y * w + x; upper++; if (b[i] > r[i] * 1.08 && b[i] > g[i] * .95 || .2126 * r[i] + .7152 * g[i] + .0722 * b[i] > 170) open++ }
            packet.put("openAreaRatio", open.toDouble() / max(1, upper))
            val scores = DoubleArray(colors.size) { i -> sqrt((r[i] - meanR).pow(2) + (g[i] - meanG).pow(2) + (b[i] - meanB).pow(2)) }
            val mean = scores.average(); val deviation = sqrt(scores.sumOf { (it - mean).pow(2) } / scores.size)
            val visited = BooleanArray(scores.size); var best = emptyList<Int>()
            if (deviation > 12) for (start in scores.indices) {
                if (visited[start] || scores[start] < mean + deviation) continue
                val component = ArrayList<Int>(); val queue = java.util.ArrayDeque<Int>(); queue.add(start); visited[start] = true
                while (queue.isNotEmpty()) {
                    val i = queue.removeFirst(); component.add(i); val x = i % w; val y = i / w
                    for ((nx, ny) in listOf(x - 1 to y, x + 1 to y, x to y - 1, x to y + 1)) {
                        if (nx !in 0 until w || ny !in 0 until h) continue
                        val next = ny * w + nx
                        if (!visited[next] && scores[next] >= mean + deviation) { visited[next] = true; queue.add(next) }
                    }
                }
                if (component.size > best.size) best = component
            }
            if (best.size > colors.size * .015 && best.size < colors.size * .50) {
                val left = best.minOf { it % w }; val right = best.maxOf { it % w } + 1; val top = best.minOf { it / w }; val bottom = best.maxOf { it / w } + 1
                packet.put("salientObject", JSONObject().put("x", left.toDouble() / w).put("y", top.toDouble() / h).put("width", (right - left).toDouble() / w).put("height", (bottom - top).toDouble() / h)
                    .put("confidence", min(.85, .35 + deviation / 255)).put("label", "color-contrast saliency").put("method", "connectedColorContrast"))
            }
        } finally { if (small !== image) small.recycle() }
        horizon(image)?.let { packet.put("horizon", it).put("horizonConfidence", it.getDouble("confidence")) }
        return packet
    }
    fun horizon(image: Bitmap): JSONObject? {
        val w = min(240, image.width); val h = max(3, image.height * w / image.width)
        val small = Bitmap.createScaledBitmap(image, w, h, true)
        try {
            val luma = DoubleArray(w * h) { i -> val c = small.getPixel(i % w, i / w); .2126 * Color.red(c) + .7152 * Color.green(c) + .0722 * Color.blue(c) }
            var bestScore = 0.0; var bestAngle = 0; var bestCoverage = 0.0; var bestY = .5
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
                        if (bin in bins.indices) { bins[bin] += min(100.0, abs(gy)); for (near in bin - 1..bin + 1) if (near in bins.indices) column.add(near) }
                    }
                    for (bin in column) coverage[bin]++
                }
                for (i in 1 until bins.size - 1) {
                    val support = coverage[i].toDouble() / (w / 2)
                    val score = bins[i - 1] + bins[i] + bins[i + 1]
                    if (support >= .60 && score > bestScore) {
                        bestScore = score; bestAngle = angle; bestCoverage = support
                        bestY = ((i - w / 2 + slope * w / 2) / h).coerceIn(0.0, 1.0)
                    }
                }
            }
            if (bestScore < w * 12 || abs(bestAngle) == 20) return null
            return JSONObject().put("angleDegrees", bestAngle).put("normalizedY", bestY).put("confidence", min(.95, .55 + bestCoverage * .20))
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

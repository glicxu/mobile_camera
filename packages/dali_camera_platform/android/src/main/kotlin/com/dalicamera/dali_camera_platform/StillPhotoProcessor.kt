package com.dalicamera.dali_camera_platform

import android.graphics.*
import androidx.exifinterface.media.ExifInterface
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.*
import com.google.mlkit.vision.pose.*
import com.google.mlkit.vision.pose.defaults.PoseDetectorOptions
import org.json.*
import kotlin.math.*
import java.util.concurrent.TimeUnit

/** Full-resolution, file-backed rendering; analysis uses a bounded copy. */
internal class StillPhotoProcessor : AutoCloseable {
    private val faces = FaceDetection.getClient(FaceDetectorOptions.Builder().setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_ACCURATE)
        .setLandmarkMode(FaceDetectorOptions.LANDMARK_MODE_ALL).setClassificationMode(FaceDetectorOptions.CLASSIFICATION_MODE_ALL).build())
    private val contours = FaceDetection.getClient(FaceDetectorOptions.Builder().setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_ACCURATE)
        .setLandmarkMode(FaceDetectorOptions.LANDMARK_MODE_ALL).setContourMode(FaceDetectorOptions.CONTOUR_MODE_ALL).build())
    private val poses = PoseDetection.getClient(PoseDetectorOptions.Builder().setDetectorMode(PoseDetectorOptions.SINGLE_IMAGE_MODE).build())
    override fun close() { faces.close(); contours.close(); poses.close() }
    fun load(path: String, bounded: Boolean = false): Bitmap {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }; BitmapFactory.decodeFile(path, bounds)
        check(bounds.outWidth > 0 && bounds.outHeight > 0) { "Cannot decode photo" }
        val options = BitmapFactory.Options().apply {
            if (bounded) while (max(bounds.outWidth, bounds.outHeight) / inSampleSize > 1400) inSampleSize *= 2
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        if (!bounded) check(bounds.outWidth.toLong() * bounds.outHeight * 12 < Runtime.getRuntime().maxMemory() * 0.65) { "Photo exceeds this phone's full-resolution processing budget. Original retained." }
        val source = BitmapFactory.decodeFile(path, options) ?: error("Cannot decode photo")
        val transform = Matrix()
        when (ExifInterface(path).getAttributeInt(ExifInterface.TAG_ORIENTATION, 1)) {
            2 -> transform.setScale(-1f, 1f); 3 -> transform.setRotate(180f); 4 -> transform.setScale(1f, -1f)
            5 -> { transform.setRotate(90f); transform.postScale(-1f, 1f) }; 6 -> transform.setRotate(90f)
            7 -> { transform.setRotate(270f); transform.postScale(-1f, 1f) }; 8 -> transform.setRotate(270f)
        }
        val upright = Bitmap.createBitmap(source, 0, 0, source.width, source.height, transform, true)
        if (upright !== source) source.recycle()
        return upright
    }
    private fun rect(box: Rect, image: Bitmap, label: String): JSONObject = JSONObject()
        .put("x", (box.left.toDouble() / image.width).coerceIn(0.0, 1.0)).put("y", (box.top.toDouble() / image.height).coerceIn(0.0, 1.0))
        .put("width", (box.width().toDouble() / image.width).coerceIn(0.0, 1.0)).put("height", (box.height().toDouble() / image.height).coerceIn(0.0, 1.0))
        .put("label", label).put("confidence", 1.0).put("confidenceSource", "detectorPresence")
    fun analyze(photo: PhotoHandle): JSONObject {
        val bitmap = load(photo.path, true)
        try { return analyzeBitmap(photo.id, bitmap) } finally { bitmap.recycle() }
    }
    private fun analyzeBitmap(id: String, bitmap: Bitmap): JSONObject {
        val input = InputImage.fromBitmap(bitmap, 0)
        val faceTask = faces.process(input); val poseTask = poses.process(input); val contourTask = contours.process(input)
        val found = runCatching { Tasks.await(faceTask, 15, TimeUnit.SECONDS) }.getOrNull()
        val pose = runCatching { Tasks.await(poseTask, 15, TimeUnit.SECONDS) }.getOrNull()
        val prominent = runCatching { Tasks.await(contourTask, 15, TimeUnit.SECONDS).maxByOrNull { it.boundingBox.width() * it.boundingBox.height() } }.getOrNull()
        val face = found?.maxByOrNull { it.boundingBox.width() * it.boundingBox.height() }
        val points = JSONObject()
        val names = mapOf(PoseLandmark.NOSE to "nose", PoseLandmark.LEFT_SHOULDER to "leftShoulder", PoseLandmark.RIGHT_SHOULDER to "rightShoulder",
            PoseLandmark.LEFT_ELBOW to "leftElbow", PoseLandmark.RIGHT_ELBOW to "rightElbow", PoseLandmark.LEFT_WRIST to "leftWrist", PoseLandmark.RIGHT_WRIST to "rightWrist",
            PoseLandmark.LEFT_HIP to "leftHip", PoseLandmark.RIGHT_HIP to "rightHip", PoseLandmark.LEFT_ANKLE to "leftAnkle", PoseLandmark.RIGHT_ANKLE to "rightAnkle")
        val visible = pose?.allPoseLandmarks?.filter { it.inFrameLikelihood > 0.2f } ?: emptyList()
        for (landmark in visible) names[landmark.landmarkType]?.let { name -> points.put(name, JSONObject().put("x", landmark.position.x / bitmap.width)
            .put("y", landmark.position.y / bitmap.height).put("confidence", landmark.inFrameLikelihood)) }
        val people = JSONArray()
        if (visible.size >= 6) people.put(rect(Rect(visible.minOf { it.position.x }.toInt(), visible.minOf { it.position.y }.toInt(),
            visible.maxOf { it.position.x }.toInt(), visible.maxOf { it.position.y }.toInt()), bitmap, "pose extent"))
        if (people.length() == 0 && face != null) {
            val f = face.boundingBox; people.put(rect(Rect((f.left - f.width() * .75).toInt(), (f.top - f.height() * .15).toInt(),
                (f.right + f.width() * .75).toInt(), (f.top + f.height() * 5.5).toInt()), bitmap, "face-based body estimate"))
        }
        val packet = JSONObject().put("schemaVersion", 1).put("sourceId", id).put("frameId", "still-$id").put("configurationId", "still-$id")
            .put("timestamp", System.currentTimeMillis()).put("imageWidth", bitmap.width).put("imageHeight", bitmap.height).put("displayRotationDegrees", 0).put("front", false)
            .put("people", people).put("peopleScope", "single").put("groupScope", "faces").put("peopleStatus", if (pose != null || found != null) "valid" else "unavailable")
            .put("faces", JSONArray((found ?: emptyList()).sortedByDescending { it.boundingBox.width() * it.boundingBox.height() }.map { rect(it.boundingBox, bitmap, "face") })).put("faceStatus", if (found != null) "valid" else "unavailable")
            .put("poseStatus", if (pose != null) "valid" else "unavailable").put("poseKeypoints", points).put("motionStatus", "unsupported")
            .put("saliencyStatus", "unsupported").put("horizonStatus", "unsupported").put("openAreaStatus", "valid").put("luminanceScale", 255)
        var sum = 0.0; var count = 0; var open = 0; var upper = 0; var faceSum = 0.0; var faceCount = 0
        val step = max(1, min(bitmap.width, bitmap.height) / 90)
        for (y in 0 until bitmap.height step step) for (x in 0 until bitmap.width step step) {
            val color = bitmap.getPixel(x, y); val r = Color.red(color); val g = Color.green(color); val b = Color.blue(color)
            val luma = .2126 * r + .7152 * g + .0722 * b; sum += luma; count++
            if (y < bitmap.height / 3) { upper++; if (b > r * 1.08 && b > g * .95 || luma > 170) open++ }
            if (face?.boundingBox?.contains(x, y) == true) { faceSum += luma; faceCount++ }
        }
        packet.put("backgroundLuminance", if (count > 0) sum / count else JSONObject.NULL).put("faceLuminance", if (faceCount > 0) faceSum / faceCount else JSONObject.NULL)
            .put("openAreaRatio", if (upper > 0) open.toDouble() / upper else 0.0)
        if (prominent != null) {
            val geometry = JSONObject()
            for ((name, type) in mapOf("leftEye" to FaceContour.LEFT_EYE, "rightEye" to FaceContour.RIGHT_EYE, "outerLips" to FaceContour.UPPER_LIP_TOP, "faceContour" to FaceContour.FACE)) {
                geometry.put(name, JSONArray((prominent.getContour(type)?.points ?: emptyList()).map { point -> JSONObject().put("x", point.x / bitmap.width).put("y", point.y / bitmap.height) }))
            }
            packet.put("faceLandmarks", geometry)
            val left = geometry.getJSONArray("leftEye").length(); val right = geometry.getJSONArray("rightEye").length()
            packet.put("faceAnalysis", JSONObject().put("confidence", 1.0).put("landmarkPointCount", left + right + geometry.getJSONArray("outerLips").length())
                .put("eyeVisibilityScore", (if (left >= 3) .5 else 0.0) + (if (right >= 3) .5 else 0.0)).put("occlusionScore", if (left >= 3 && right >= 3) 0.0 else .6)
                .put("yawEstimate", prominent.headEulerAngleY / 90.0).put("pitchEstimate", prominent.headEulerAngleX / 90.0))
        }
        val scene = PhotoGeometry.scenic(bitmap)
        for (key in scene.keys()) packet.put(key, scene.get(key))
        PhotoGeometry.reframe(people.optJSONObject(0), bitmap.width < bitmap.height)?.let { packet.put("reframe", it) }
        return packet
    }
    private fun colorPass(image: Bitmap, brightness: Double = 0.0, saturation: Double = 1.0, contrast: Double = 1.0,
        warmth: Double = 0.0, vibrance: Double = 0.0, blue: Double = 0.0, mask: ((Int, Int) -> Double)? = null) {
        val row = IntArray(image.width)
        for (y in 0 until image.height) {
            image.getPixels(row, 0, image.width, 0, y, image.width, 1)
            for (x in row.indices) {
                val c = row[x]; val r = Color.red(c) / 255.0; val g = Color.green(c) / 255.0; val b = Color.blue(c) / 255.0
                val l = .2126 * r + .7152 * g + .0722 * b
                val spread = max(r, max(g, b)) - min(r, min(g, b)); val sat = saturation + vibrance * (1 - spread)
                val alpha = mask?.invoke(x, y)?.coerceIn(0.0, 1.0) ?: 1.0
                fun channel(value: Double, offset: Double) = ((value + alpha * (((l + (value - l) * sat - .5) * contrast + .5 + brightness + offset) - value)).coerceIn(0.0, 1.0) * 255).roundToInt()
                row[x] = Color.argb(Color.alpha(c), channel(r, .035 * warmth), channel(g, 0.0), channel(b, -.035 * warmth + .10 * blue))
            }
            image.setPixels(row, 0, image.width, 0, y, image.width, 1)
        }
    }
    private fun blur(image: Bitmap, radius: Double): Bitmap {
        // Bounded working image; separable sliding-window blur, enlarged for full-resolution composition.
        val scale = min(1.0, 1400.0 / max(image.width, image.height))
        val small = Bitmap.createScaledBitmap(image, max(1, (image.width * scale).toInt()), max(1, (image.height * scale).toInt()), true)
        val w = small.width; val h = small.height; val pixels = IntArray(w * h); val temp = IntArray(w * h)
        small.getPixels(pixels, 0, w, 0, 0, w, h)
        val r = max(1, (radius * scale).roundToInt()); val n = r * 2 + 1
        repeat(3) {
            for (y in 0 until h) {
                var red = 0; var green = 0; var blue = 0
                for (dx in -r..r) { val c = pixels[y * w + dx.coerceIn(0, w - 1)]; red += Color.red(c); green += Color.green(c); blue += Color.blue(c) }
                for (x in 0 until w) {
                    temp[y * w + x] = Color.rgb(red / n, green / n, blue / n)
                    val add = pixels[y * w + (x + r + 1).coerceIn(0, w - 1)]; val remove = pixels[y * w + (x - r).coerceIn(0, w - 1)]
                    red += Color.red(add) - Color.red(remove); green += Color.green(add) - Color.green(remove); blue += Color.blue(add) - Color.blue(remove)
                }
            }
            for (x in 0 until w) {
                var red = 0; var green = 0; var blue = 0
                for (dy in -r..r) { val c = temp[dy.coerceIn(0, h - 1) * w + x]; red += Color.red(c); green += Color.green(c); blue += Color.blue(c) }
                for (y in 0 until h) {
                    pixels[y * w + x] = Color.rgb(red / n, green / n, blue / n)
                    val add = temp[(y + r + 1).coerceIn(0, h - 1) * w + x]; val remove = temp[(y - r).coerceIn(0, h - 1) * w + x]
                    red += Color.red(add) - Color.red(remove); green += Color.green(add) - Color.green(remove); blue += Color.blue(add) - Color.blue(remove)
                }
            }
        }
        val output = Bitmap.createBitmap(pixels, w, h, Bitmap.Config.ARGB_8888)
        if (small !== image) small.recycle()
        return output
    }
    fun previewBlur(image: Bitmap, level: Int): Bitmap = blur(image, 2.0 + level * .8)
    private fun tonePass(image: Bitmap, shadows: Double, highlights: Double, mask: ((Int, Int) -> Double)? = null) {
        val row = IntArray(image.width)
        for (y in 0 until image.height) {
            image.getPixels(row, 0, image.width, 0, y, image.width, 1)
            for (x in row.indices) {
                val c = row[x]; val l = (.2126 * Color.red(c) + .7152 * Color.green(c) + .0722 * Color.blue(c)) / 255
                val delta = (shadows * (1 - l).pow(2) * .18 + (highlights - 1) * l.pow(4) * .25) * (mask?.invoke(x, y) ?: 1.0)
                fun channel(v: Int) = (v + delta * 255).roundToInt().coerceIn(0, 255)
                row[x] = Color.argb(Color.alpha(c), channel(Color.red(c)), channel(Color.green(c)), channel(Color.blue(c)))
            }
            image.setPixels(row, 0, image.width, 0, y, image.width, 1)
        }
    }
    private fun channelPass(image: Bitmap, red: Double, green: Double, blue: Double, blueOffset: Double, mask: ((Int, Int) -> Double)? = null) {
        val row = IntArray(image.width)
        for (y in 0 until image.height) {
            image.getPixels(row, 0, image.width, 0, y, image.width, 1)
            for (x in row.indices) {
                val c = row[x]; val a = mask?.invoke(x, y) ?: 1.0
                fun channel(v: Int, scale: Double, offset: Double = 0.0) = (v + ((v * scale + offset * 255) - v) * a).roundToInt().coerceIn(0, 255)
                row[x] = Color.argb(Color.alpha(c), channel(Color.red(c), red), channel(Color.green(c), green), channel(Color.blue(c), blue, blueOffset))
            }
            image.setPixels(row, 0, image.width, 0, y, image.width, 1)
        }
    }
    private fun spatial(image: Bitmap, radius: Double, amount: Double, sharpen: Boolean = false, mask: ((Int, Int) -> Double)? = null) {
        val blurred = blur(image, radius)
        val row = IntArray(image.width)
        for (y in 0 until image.height) {
            image.getPixels(row, 0, image.width, 0, y, image.width, 1)
            for (x in row.indices) {
                val c = row[x]; val b = blurred.getPixel(x * blurred.width / image.width, y * blurred.height / image.height)
                val weight = amount * (mask?.invoke(x, y) ?: 1.0)
                fun channel(v: Int, s: Int) = (v + (if (sharpen) v - s else s - v) * weight).roundToInt().coerceIn(0, 255)
                row[x] = Color.argb(Color.alpha(c), channel(Color.red(c), Color.red(b)), channel(Color.green(c), Color.green(b)), channel(Color.blue(c), Color.blue(b)))
            }
            image.setPixels(row, 0, image.width, 0, y, image.width, 1)
        }
        blurred.recycle()
    }
    private fun featureBounds(points: JSONArray?): RectF? {
        if (points == null || points.length() < 3) return null
        val xs = (0 until points.length()).map { points.getJSONObject(it).getDouble("x").toFloat() }
        val ys = (0 until points.length()).map { points.getJSONObject(it).getDouble("y").toFloat() }
        return RectF(xs.min(), ys.min(), xs.max(), ys.max())
    }
    private fun enlargeFeature(image: Bitmap, bounds: RectF, faceWidth: Double, strength: Double, lip: Boolean) {
        val cx = bounds.centerX() * image.width; val cy = bounds.centerY() * image.height
        val radius = max(faceWidth * image.width * (if (lip) .14 else .105), bounds.width() * image.width * (if (lip) .72 else .95))
        val scale = (if (lip) .12 else .18) * strength.pow(if (lip) 1.25 else 1.2)
        val left = max(0, floor(cx - radius).toInt()); val top = max(0, floor(cy - radius).toInt())
        val right = min(image.width, ceil(cx + radius).toInt()); val bottom = min(image.height, ceil(cy + radius).toInt())
        if (right <= left || bottom <= top || radius <= 0) return
        // Local inverse radial mapping; only the feature neighborhood is allocated.
        val region = Bitmap.createBitmap(image, left, top, right - left, bottom - top)
        try {
            val row = IntArray(right - left)
            for (y in top until bottom) {
                for (x in left until right) {
                    val dx = x - cx; val dy = y - cy; val distance = hypot(dx.toDouble(), dy.toDouble()) / radius
                    val factor = if (distance < 1) 1 - scale * (1 - distance * distance).pow(2) else 1.0
                    val sx = (cx + dx * factor - left).coerceIn(0.0, region.width - 1.0); val sy = (cy + dy * factor - top).coerceIn(0.0, region.height - 1.0)
                    val ix = sx.toInt(); val iy = sy.toInt(); val fx = sx - ix; val fy = sy - iy
                    val a = region.getPixel(ix, iy); val b = region.getPixel(min(ix + 1, region.width - 1), iy)
                    val c = region.getPixel(ix, min(iy + 1, region.height - 1)); val d = region.getPixel(min(ix + 1, region.width - 1), min(iy + 1, region.height - 1))
                    fun channel(get: (Int) -> Int) = ((get(a) * (1 - fx) + get(b) * fx) * (1 - fy) + (get(c) * (1 - fx) + get(d) * fx) * fy).roundToInt()
                    row[x - left] = Color.rgb(channel(Color::red), channel(Color::green), channel(Color::blue))
                }
                image.setPixels(row, 0, row.size, left, y, row.size, 1)
            }
        } finally { region.recycle() }
    }
    fun render(original: PhotoHandle, recipe: String): Bitmap {
        check(recipe.length < 16384); val request = JSONObject(recipe); check(request.getInt("version") == 1) { "Unsupported photo recipe" }
        val treatment = request.optString("treatment", "original"); check(treatment in listOf("original", "reframe", "level", "enhance", "portrait", "landscape"))
        val flags = request.optJSONObject("flags") ?: JSONObject(); val strength = request.optInt("strength", 0).coerceIn(0, 5) / 5.0
        val filter = request.optJSONArray("filter") ?: JSONArray(List(7) { 0 })
        check(filter.length() == 7); val p = DoubleArray(7) { index -> filter.getDouble(index).also { check(it.isFinite()) }.coerceIn(if (index in listOf(0, 1, 3)) -5.0 else 0.0, 5.0) / 5 }
        val analysis = if (treatment == "original" && request.optInt("depth", 0) == 0) JSONObject() else analyze(original)
        val source = load(original.path)
        var image = try { source.copy(Bitmap.Config.ARGB_8888, true) ?: error("Cannot allocate photo result") } finally { source.recycle() }
        fun flag(name: String) = flags.optBoolean(name, true)
        try {
            if (p[4] > 0) spatial(image, 1.5 + 3 * p[4], .16 + .28 * p[4])
            if (p[0] != 0.0) tonePass(image, max(0.0, .22 * p[0]), 1 - max(0.0, .10 * p[0]))
            colorPass(image, .055 * p[0], 1 + .30 * p[2], 1 + .13 * p[3] - .04 * p[4])
            if (p[2] > 0) colorPass(image, vibrance = .36 * p[2])
            if (p[1] != 0.0) colorPass(image, warmth = p[1])
            if (p[6] > 0) channelPass(image, 1 - .05 * p[6], 1 + .02 * p[6], 1 + .18 * p[6], .018 * p[6])
            if (p[5] > 0) spatial(image, 1.1 + 1.9 * p[5], .10 + .34 * p[5], true)
            when (treatment) {
                "enhance" -> if (strength > 0) {
                    if (flag("noiseReduction")) spatial(image, 1.2 + strength, .08 + .20 * strength)
                    if (flag("autoTone")) tonePass(image, .08 + .20 * strength, 1 - .16 * strength)
                    val exposure = ((.5 - analysis.optDouble("backgroundLuminance", 127.5) / 255) * .16).coerceIn(-.045, .055)
                    colorPass(image, if (flag("autoTone")) exposure * strength else 0.0, if (flag("vibrance")) 1 + .025 * strength else 1.0,
                        if (flag("autoTone")) 1 + .065 * strength else 1.0, if (flag("warmth")) .20 * strength else 0.0, if (flag("vibrance")) .22 * strength else 0.0)
                    if (flag("clarity")) spatial(image, 1.2 + 1.8 * strength, .12 + .30 * strength, true)
                    if (flag("subjectEmphasis")) colorPass(image, -.14 * strength, mask = { x, y -> (((x.toDouble() / image.width - .5).pow(2) + (y.toDouble() / image.height - .5).pow(2)) * 2).coerceIn(0.0, 1.0) })
                }
                "portrait" -> if (strength > 0) {
                    val face = analysis.getJSONArray("faces").optJSONObject(0)
                    if (face != null) {
                    val cx = face.getDouble("x") + face.getDouble("width") / 2; val cy = face.getDouble("y") + face.getDouble("height") / 2
                    val rx = face.getDouble("width") * .7; val ry = face.getDouble("height") * .74
                    val geometry = analysis.optJSONObject("faceLandmarks")
                    val features = listOf("leftEye", "rightEye", "outerLips").mapNotNull { featureBounds(geometry?.optJSONArray(it)) }
                    val skin: (Int, Int) -> Double = { x, y ->
                        val nx = x.toDouble() / image.width; val ny = y.toDouble() / image.height
                        val base = (1 - ((nx - cx) / rx).pow(2) - ((ny - cy) / ry).pow(2)).coerceIn(0.0, 1.0)
                        val cutout = features.maxOfOrNull { f -> (1 - ((nx - f.centerX()) / max(.001, f.width() * .8)).pow(2) - ((ny - f.centerY()) / max(.001, f.height() * 1.1)).pow(2)).coerceIn(0.0, 1.0) } ?: 0.0
                        base * (1 - cutout)
                    }
                    if (flag("faceBrightness")) colorPass(image, (.015 + .10 * strength.pow(1.2)) * (.35 + .55 * strength), 1 - .045 * strength, 1 + .025 * strength, mask = skin)
                    if (flag("blemishReduction")) spatial(image, 1.5 + 3 * strength, .10 + .40 * strength, mask = skin)
                    if (flag("skinSmoothing")) spatial(image, (face.getDouble("width") * image.width * (.008 + .024 * strength.pow(1.15))).coerceIn(1.2, 34.0), .08 + .52 * strength.pow(1.15), mask = skin)
                    val reshape = ((strength - .2) / .8).coerceIn(0.0, 1.0)
                    val faceAnalysis = analysis.optJSONObject("faceAnalysis")
                    if (reshape > 0 && abs(faceAnalysis?.optDouble("yawEstimate") ?: 0.0) < .38 && (faceAnalysis?.optDouble("occlusionScore") ?: 0.0) < .55) {
                        if (flag("eyeEnlargement") && (faceAnalysis?.optDouble("eyeVisibilityScore") ?: 0.0) >= .9) for (name in listOf("leftEye", "rightEye")) {
                            featureBounds(geometry?.optJSONArray(name))?.let { enlargeFeature(image, it, face.getDouble("width"), reshape, false) }
                        }
                        if (flags.optBoolean("lipPlumping", false)) featureBounds(geometry?.optJSONArray("outerLips"))?.let { enlargeFeature(image, it, face.getDouble("width"), reshape, true) }
                    }
                    }
                }
                "landscape" -> if (strength > 0) {
                    val s = if (strength <= .6) strength / .6 else 1 + (strength - .6) * .875
                    if (flag("landscapeColor") && analysis.optDouble("openAreaRatio") >= .08) { colorPass(image, vibrance = .16 + .42 * s); colorPass(image, saturation = 1 + .08 * s, contrast = 1 + .07 * s) }
                    if (flag("sky") && analysis.optDouble("openAreaRatio") >= .08) {
                        val curve = s.pow(1.3); val high = s.pow(4); val confidence = ((analysis.optDouble("openAreaRatio") - .08) / .42).coerceIn(.25, 1.0)
                        val maskCopy = Bitmap.createScaledBitmap(image, max(1, image.width / 8), max(1, image.height / 8), true)
                        try {
                            val sky: (Int, Int) -> Double = { x, y -> val c = maskCopy.getPixel(x * maskCopy.width / image.width, y * maskCopy.height / image.height); val chroma = ((1.05 * Color.blue(c) - .45 * Color.red(c) - .10 * Color.green(c)) / 255.0 - .08).coerceIn(0.0, 1.0); chroma * ((.72 - y.toDouble() / image.height) / .38).coerceIn(0.0, 1.0) * min(1.0, (.50 + .50 * curve) * confidence) }
                            channelPass(image, max(.15, 1 - .18 * curve - .20 * high), max(.55, 1 - .03 * curve - .08 * high), min(3.2, 1 + .35 * curve + .55 * high), min(.25, .02 * curve + .10 * high), sky)
                            colorPass(image, vibrance = min(1.8, .28 + .55 * curve + .45 * high), mask = sky)
                            colorPass(image, saturation = min(2.2, 1 + .28 * curve + .35 * high), contrast = min(1.5, 1 + .10 * curve + .12 * high), mask = sky)
                            tonePass(image, .08 * curve, max(.20, 1 - .30 * curve - .18 * high), sky)
                            spatial(image, 1.1 + 1.8 * curve, .12 + .35 * curve + .20 * high, true, sky)
                        } finally { if (maskCopy !== image) maskCopy.recycle() }
                    }
                }
                "reframe" -> {
                    val crop = analysis.optJSONObject("reframe")?.getJSONObject("cropRect") ?: error("No confident reframe is available")
                    val x = crop.getDouble("x"); val y = crop.getDouble("y"); val w = crop.getDouble("width"); val h = crop.getDouble("height")
                    val cropped = Bitmap.createBitmap(image, (x * image.width).toInt(), (y * image.height).toInt(), max(1, (w * image.width).toInt()), max(1, (h * image.height).toInt()))
                    if (cropped !== image) image.recycle(); image = cropped
                }
                "level" -> {
                    val horizon = analysis.optJSONObject("horizon") ?: error("No confident horizon correction is available")
                    val angle = horizon.getDouble("angleDegrees")
                    check(horizon.getDouble("confidence") > .55 && abs(angle) > 3) { "No horizon correction is needed" }
                    val matrix = Matrix().apply { setRotate((-angle).toFloat()) }
                    val rotated = Bitmap.createBitmap(image, 0, 0, image.width, image.height, matrix, true)
                    if (rotated !== image) image.recycle(); image = rotated
                }
            }
            val depth = request.optInt("depth", 0).coerceIn(0, 5)
            if (depth > 0) {
                val person = analysis.getJSONArray("people").optJSONObject(0)
                val face = analysis.getJSONArray("faces").optJSONObject(0)
                val focus = request.optJSONObject("focus")
                val fx = focus?.getDouble("x")?.also { check(it.isFinite()) }?.coerceIn(0.0, 1.0)
                val fy = focus?.getDouble("y")?.also { check(it.isFinite()) }?.coerceIn(0.0, 1.0)
                val selected = if (fx != null && fy != null) listOfNotNull(person, analysis.optJSONObject("salientObject"), face).firstOrNull {
                    fx >= it.getDouble("x") - .04 && fx <= it.getDouble("x") + it.getDouble("width") + .04 && fy >= it.getDouble("y") - .04 && fy <= it.getDouble("y") + it.getDouble("height") + .04
                } else null
                val subject = selected ?: person ?: face
                if (subject != null || fx != null && fy != null) {
                    val x = subject?.getDouble("x") ?: fx!! - .18; val y = subject?.getDouble("y") ?: fy!! - .24
                    val w = subject?.getDouble("width") ?: .36; val h = subject?.getDouble("height") ?: .48
                    val dx = if (selected != null) .22 else if (person != null) .16 else if (face != null) 1.1 else 0.0
                    val dy = if (selected != null) .18 else if (person != null) .10 else if (face != null) .45 else 0.0
                    val rightFactor = if (selected == null && person == null && face != null) 2.1 else 1 + dx
                    val bottomFactor = if (selected == null && person == null && face != null) 4.25 else 1 + dy
                    val left = (x - w * dx).coerceIn(0.0, 1.0) * image.width; val top = (y - h * dy).coerceIn(0.0, 1.0) * image.height
                    val right = (x + w * rightFactor).coerceIn(0.0, 1.0) * image.width; val bottom = (y + h * bottomFactor).coerceIn(0.0, 1.0) * image.height
                    val cx = (left + right) / 2; val cy = (top + bottom) / 2; val rx = (right - left) / 2; val ry = (bottom - top) / 2
                    val radius = min(rx, ry) * .56; val feather = max(image.width, image.height) * .018
                    if (rx > 0 && ry > 0) spatial(image, (3 + depth * 4).toDouble(), 1.0, mask = { px, py ->
                        val qx = abs(px - cx) - rx + radius; val qy = abs(py - cy) - ry + radius
                        val distance = hypot(max(qx, 0.0), max(qy, 0.0)) + min(max(qx, qy), 0.0) - radius
                        ((distance / feather + 1) / 2).coerceIn(0.0, 1.0)
                    })
                }
            }
            return image
        } catch (error: Throwable) { image.recycle(); throw error }
    }
}

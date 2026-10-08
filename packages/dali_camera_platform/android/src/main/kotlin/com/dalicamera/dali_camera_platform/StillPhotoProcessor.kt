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
            .put("faces", JSONArray((found ?: emptyList()).map { rect(it.boundingBox, bitmap, "face") })).put("faceStatus", if (found != null) "valid" else "unavailable")
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
    fun render(original: PhotoHandle, recipe: String): Bitmap {
        check(recipe.length < 16384); val request = JSONObject(recipe); check(request.getInt("version") == 1) { "Unsupported photo recipe" }
        val treatment = request.optString("treatment", "original"); check(treatment in listOf("original", "reframe", "level", "enhance", "portrait", "landscape"))
        val flags = request.optJSONObject("flags") ?: JSONObject(); val strength = request.optInt("strength", 0).coerceIn(0, 5) / 5.0
        val filter = request.optJSONArray("filter") ?: JSONArray(List(7) { 0 })
        check(filter.length() == 7); val p = DoubleArray(7) { index -> filter.getDouble(index).also { check(it.isFinite()) }.coerceIn(if (index in listOf(0, 1, 3)) -5.0 else 0.0, 5.0) / 5 }
        val analysis = analyze(original)
        val source = load(original.path); var image = source.copy(Bitmap.Config.ARGB_8888, true); source.recycle()
        fun flag(name: String) = flags.optBoolean(name, true)
        try {
            if (p[4] > 0) spatial(image, 1.5 + 3 * p[4], .16 + .28 * p[4])
            colorPass(image, .055 * p[0], 1 + .30 * p[2], 1 + .13 * p[3] - .04 * p[4], p[1], .20 * p[2], p[6])
            if (p[5] > 0) spatial(image, .8 + 1.8 * p[5], .12 + .45 * p[5], true)
            when (treatment) {
                "enhance" -> if (strength > 0) {
                    if (flag("noiseReduction")) spatial(image, 1.2 + strength, .08 + .20 * strength)
                    val exposure = ((.5 - analysis.optDouble("backgroundLuminance", 127.5) / 255) * .16).coerceIn(-.045, .055)
                    colorPass(image, if (flag("autoTone")) exposure * strength else 0.0, if (flag("vibrance")) 1 + .025 * strength else 1.0,
                        if (flag("autoTone")) 1 + .065 * strength else 1.0, if (flag("warmth")) .20 * strength else 0.0, if (flag("vibrance")) .22 * strength else 0.0)
                    if (flag("clarity")) spatial(image, 1.2 + 1.8 * strength, .12 + .30 * strength, true)
                    if (flag("subjectEmphasis")) colorPass(image, -.14 * strength, mask = { x, y -> (((x.toDouble() / image.width - .5).pow(2) + (y.toDouble() / image.height - .5).pow(2)) * 2).coerceIn(0.0, 1.0) })
                }
                "portrait" -> if (strength > 0) {
                    val face = analysis.getJSONArray("faces").optJSONObject(0) ?: error("No face is available for Portrait Polish")
                    val cx = face.getDouble("x") + face.getDouble("width") / 2; val cy = face.getDouble("y") + face.getDouble("height") / 2
                    val rx = face.getDouble("width") * .7; val ry = face.getDouble("height") * .74
                    val skin: (Int, Int) -> Double = { x, y -> (1 - ((x.toDouble() / image.width - cx) / rx).pow(2) - ((y.toDouble() / image.height - cy) / ry).pow(2)).coerceIn(0.0, 1.0) }
                    if (flag("faceBrightness")) colorPass(image, (.015 + .10 * strength.pow(1.2)) * (.35 + .55 * strength), 1 - .045 * strength, 1 + .025 * strength, mask = skin)
                    if (flag("blemishReduction")) spatial(image, 1.5 + 3 * strength, .10 + .40 * strength, mask = skin)
                    if (flag("skinSmoothing")) spatial(image, (face.getDouble("width") * image.width * (.008 + .024 * strength.pow(1.15))).coerceIn(1.2, 34.0), .08 + .52 * strength.pow(1.15), mask = skin)
                }
                "landscape" -> if (strength > 0) {
                    val s = if (strength <= .6) strength / .6 else 1 + (strength - .6) * .875
                    if (flag("landscapeColor")) colorPass(image, saturation = 1 + .08 * s, contrast = 1 + .07 * s, vibrance = .16 + .42 * s)
                    if (flag("sky") && analysis.optDouble("openAreaRatio") >= .08) {
                        val sky: (Int, Int) -> Double = { x, y -> val c = image.getPixel(x, y); val chroma = ((Color.blue(c) - .45 * Color.red(c) - .10 * Color.green(c)) / 255.0 - .08).coerceIn(0.0, 1.0); chroma * ((.72 - y.toDouble() / image.height) / .38).coerceIn(0.0, 1.0) }
                        colorPass(image, -.018 * s.pow(1.3), 1 + .16 * s, 1 + .06 * s, vibrance = .28 + .55 * s.pow(1.3), blue = s.pow(1.3), mask = sky)
                    }
                }
                "reframe" -> {
                    val subject = analysis.getJSONArray("people").optJSONObject(0) ?: error("No confident reframe is available")
                    val x = (subject.getDouble("x") - subject.getDouble("width") * .42).coerceIn(0.0, .9)
                    val y = (subject.getDouble("y") - subject.getDouble("height") * .18).coerceIn(0.0, .9)
                    val w = (subject.getDouble("width") * 1.84).coerceIn(.1, 1 - x); val h = (subject.getDouble("height") * 1.36).coerceIn(.1, 1 - y)
                    val cropped = Bitmap.createBitmap(image, (x * image.width).toInt(), (y * image.height).toInt(), max(1, (w * image.width).toInt()), max(1, (h * image.height).toInt()))
                    if (cropped !== image) image.recycle(); image = cropped
                }
                "level" -> error("No calibrated optical horizon is available on this phone")
            }
            val depth = request.optInt("depth", 0).coerceIn(0, 5)
            if (depth > 0) {
                val subject = analysis.getJSONArray("people").optJSONObject(0) ?: analysis.getJSONArray("faces").optJSONObject(0)
                val focus = request.optJSONObject("focus")
                if (subject != null || focus != null) {
                    val cx = focus?.optDouble("x") ?: (subject!!.getDouble("x") + subject.getDouble("width") / 2)
                    val cy = focus?.optDouble("y") ?: (subject!!.getDouble("y") + subject.getDouble("height") / 2)
                    val rx = subject?.getDouble("width")?.times(.66) ?: .18; val ry = subject?.getDouble("height")?.times(.60) ?: .24
                    spatial(image, (3 + depth * 4).toDouble(), 1.0, mask = { x, y -> (((x.toDouble() / image.width - cx).absoluteValue / rx - .8).coerceAtLeast(0.0) + ((y.toDouble() / image.height - cy).absoluteValue / ry - .8).coerceAtLeast(0.0)).times(5).coerceIn(0.0, 1.0) })
                }
            }
            return image
        } catch (error: Throwable) { image.recycle(); throw error }
    }
}

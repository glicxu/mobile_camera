package com.dalicamera.dali_camera_platform

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.Matrix
import android.graphics.Paint
import android.util.Log
import android.util.Base64
import androidx.exifinterface.media.ExifInterface
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.ByteArrayOutputStream
import java.io.File
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

@RunWith(AndroidJUnit4::class)
class HiddenWatermarkPhase0Test {
    private val width = 320
    private val height = 240
    private val sceneCount = 32

    @Test
    fun reportsTransformationBaseline() {
        val transformations = linkedMapOf<String, (Bitmap) -> Bitmap>(
            "original" to { it.copy(Bitmap.Config.ARGB_8888, true) },
            "jpeg_90" to { jpeg(it, 90) },
            "jpeg_75" to { jpeg(it, 75) },
            "jpeg_60" to { jpeg(it, 60) },
            "resize_75_percent" to { resize(it, 0.75) },
            "resize_50_percent" to { resize(it, 0.50) },
            "center_crop_80_percent" to { centerCrop(it, 0.80) },
            "center_crop_79_percent_unaligned" to { centerCrop(it, 0.79) },
            "rotate_90" to { rotate(it, 90f) },
            "rotate_180" to { rotate(it, 180f) },
            "blur_3x3" to { convolve(it, sharpen = false) },
            "sharpen_3x3" to { convolve(it, sharpen = true) },
            "grayscale_filter" to { grayscale(it) },
            "screenshot_simulation" to { screenshotSimulation(it) },
            "social_export_simulation" to { socialExportSimulation(it) },
        )
        val report = JSONObject()
            .put("schema", "dali.watermark.android-phase4.v1")
            .put("format", HiddenWatermark.robustFormatVersion)
            .put("minimumDimension", HiddenWatermark.minimumDimension)
            .put("sourceSize", "${width}x$height")
            .put("scenes", sceneCount)
        val outcomes = JSONArray()

        for ((name, transform) in transformations) {
            var detectedPositives = 0
            var falsePositives = 0
            var positiveScore = 0.0
            var negativeScore = 0.0
            repeat(sceneCount) { seed ->
                val clean = scene(seed)
                val marked = clean.copy(Bitmap.Config.ARGB_8888, true)
                HiddenWatermark.embed(marked)
                val transformedClean = transform(clean)
                val transformedMarked = transform(marked)
                val cleanResult = HiddenWatermark.inspect(transformedClean)
                val markedResult = HiddenWatermark.inspect(transformedMarked)
                if (cleanResult.detected) {
                    falsePositives++
                    Log.i(
                        "DaliWatermarkPhase0",
                        "FALSE_POSITIVE transform=$name seed=$seed legacy=${cleanResult.score} robust=${cleanResult.robustScore} axis=${cleanResult.robustAxis}",
                    )
                }
                if (markedResult.detected) detectedPositives++
                negativeScore += cleanResult.score
                positiveScore += markedResult.score
                transformedClean.recycle()
                transformedMarked.recycle()
                marked.recycle()
                clean.recycle()
            }
            val outcome = JSONObject()
                .put("transformation", name)
                .put("detected", detectedPositives)
                .put("positiveTotal", sceneCount)
                .put("falsePositives", falsePositives)
                .put("negativeTotal", sceneCount)
                .put("meanPositiveScore", positiveScore / sceneCount)
                .put("meanNegativeScore", negativeScore / sceneCount)
            outcomes.put(outcome)
            Log.i("DaliWatermarkPhase0", outcome.toString())
            assertEquals(
                "Clean transformed scenes must not trigger detection for $name",
                0,
                falsePositives,
            )
            if (name == "original") {
                assertEquals("Every directly embedded scene must be detected", sceneCount, detectedPositives)
            }
        }
        report.put("outcomes", outcomes)
        val reportFile = File(
            InstrumentationRegistry.getInstrumentation().context.getExternalFilesDir(null),
            "watermark-phase4-report.json",
        )
        reportFile.writeText(report.toString(2))
        Log.i("DaliWatermarkPhase0", "REPORT_PATH=${reportFile.path}")
    }

    @Test
    fun metadataIdentifierIsAddedPreservedAndRemoved() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val directory = File(context.cacheDir, "watermark-phase0").apply { mkdirs() }
        val source = File(directory, "source.jpg")
        val copied = File(directory, "copied.jpg")
        val edited = File(directory, "edited.jpg")
        writeJpeg(scene(2), source)
        writeJpeg(scene(3), copied)
        val identifier = "DALI1-phase0-android"
        PhotoMetadata.capture(
            source,
            java.util.Date(0),
            JSONObject()
                .put("schema", "dali.capture-debug.v1")
                .put("hiddenWatermark", identifier)
                .toString(),
            "Dali Camera Phase 0",
        )
        assertEquals(identifier, ExifInterface(source).getAttribute("ImageUniqueID"))

        PhotoMetadata.copy(source.path, copied, "Dali Camera Phase 0")
        assertEquals(identifier, ExifInterface(copied).getAttribute("ImageUniqueID"))

        PhotoMetadata.edit(copied.path, edited, JSONObject().put("hiddenWatermark", ""))
        assertNull(ExifInterface(edited).getAttribute("ImageUniqueID"))
        val pixelOnly = File(directory, "pixel-only.jpg")
        writeJpeg(scene(4), pixelOnly)
        PhotoMetadata.capture(
            pixelOnly,
            java.util.Date(0),
            JSONObject()
                .put("schema", "dali.capture-debug.v1")
                .put("hiddenWatermarkPixels", true)
                .put("pixelWatermarkPayload", "DALI2-private-pixel-payload")
                .toString(),
            "Dali Camera Phase 2",
        )
        val pixelOnlyExif = ExifInterface(pixelOnly)
        assertNull(pixelOnlyExif.getAttribute("ImageUniqueID"))
        assertFalse(pixelOnlyExif.getAttribute("UserComment")?.contains("DALI2-private-pixel-payload") == true)
        source.delete()
        copied.delete()
        edited.delete()
        pixelOnly.delete()
        directory.delete()
    }

    @Test
    fun imagesBelowMinimumDimensionAreNotDetected() {
        val image = Bitmap.createBitmap(63, 63, Bitmap.Config.ARGB_8888)
        image.eraseColor(Color.GRAY)
        HiddenWatermark.embed(image)
        val result = HiddenWatermark.inspect(image)
        assertFalse(result.detected)
        assertEquals(0, result.samples)
        image.recycle()
    }

    @Test
    fun identityPayloadRoundTripsFromPixels() {
        val owner = "owner-phase2-android"
        val photo = "photo-phase2-android"
        val encoded = Base64.encodeToString(
            JSONObject().put("v", 2).put("owner", owner).put("photo", photo).toString().toByteArray(),
            Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING,
        )
        val marked = scene(5)
        HiddenWatermark.embed(marked, "DALI2-$encoded")
        val result = HiddenWatermark.inspect(marked)
        assertTrue(result.detected)
        assertEquals(HiddenWatermark.robustFormatVersion, result.formatVersion)
        assertEquals(compactReference(owner), result.ownerReference)
        assertEquals(compactReference(photo), result.photoReference)
        assertTrue((result.payloadConfidence ?: 0.0) > 0.5)
        val recompressed = jpeg(marked, 90)
        val recompressedResult = HiddenWatermark.inspect(recompressed)
        assertTrue(recompressedResult.detected)
        assertEquals(compactReference(owner), recompressedResult.ownerReference)
        assertEquals(compactReference(photo), recompressedResult.photoReference)
        recompressed.recycle()
        marked.recycle()
    }

    @Test
    fun robustSignalSurvivesUnalignedCropAndQuarterTurnRotation() {
        val owner = "owner-phase4-crop"
        val photo = "photo-phase4-rotate"
        val marked = scene(6)
        HiddenWatermark.embed(marked, identity(owner, photo))
        assertEquals(HiddenWatermark.robustFormatVersion, HiddenWatermark.inspect(marked).formatVersion)

        val cropped = Bitmap.createBitmap(marked, 23, 17, marked.width - 47, marked.height - 39)
        val cropResult = HiddenWatermark.inspect(cropped)
        assertTrue("Unaligned crop should retain the robust signal", cropResult.detected)
        assertEquals(HiddenWatermark.robustFormatVersion, cropResult.formatVersion)
        assertEquals(compactReference(owner), cropResult.ownerReference)
        assertEquals(compactReference(photo), cropResult.photoReference)
        assertEquals("tiled", cropResult.payloadRecoveryMode)

        for (degrees in listOf(90f, 180f, 270f)) {
            val rotated = rotate(marked, degrees)
            val rotationResult = HiddenWatermark.inspect(rotated)
            assertTrue("$degrees degree rotation should retain the robust signal", rotationResult.detected)
            assertEquals(HiddenWatermark.robustFormatVersion, rotationResult.formatVersion)
            assertEquals(compactReference(owner), rotationResult.ownerReference)
            assertEquals(compactReference(photo), rotationResult.photoReference)
            assertEquals("tiled", rotationResult.payloadRecoveryMode)
            rotated.recycle()
        }
        cropped.recycle()
        marked.recycle()
    }

    private fun identity(owner: String, photo: String): String {
        val encoded = Base64.encodeToString(
            JSONObject().put("v", 2).put("owner", owner).put("photo", photo).toString().toByteArray(),
            Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING,
        )
        return "DALI2-$encoded"
    }

    @Test
    fun legacyPresenceSignalRemainsDetectableAsV1() {
        val marked = scene(7)
        embedLegacyPresence(marked)
        val result = HiddenWatermark.inspect(marked)
        assertTrue(result.detected)
        assertEquals(HiddenWatermark.formatVersion, result.formatVersion)
        marked.recycle()
    }

    @Test
    fun robustIdentityRecoveryCorpusCoversJpegCropAndRotation() {
        repeat(4) { seed ->
            val owner = "phase4-corpus-owner-$seed"
            val photo = "phase4-corpus-photo-$seed"
            val marked = scene(seed)
            HiddenWatermark.embed(marked, identity(owner, photo))

            val recompressed = jpeg(marked, 90)
            val cropX = 17 + seed
            val cropY = 13 + seed * 2
            val cropped = Bitmap.createBitmap(
                recompressed,
                cropX,
                cropY,
                recompressed.width - cropX - 19,
                recompressed.height - cropY - 15,
            )
            assertRecoveredIdentity(cropped, owner, photo, "JPEG crop scene $seed")

            val degrees = listOf(90f, 180f, 270f)[seed % 3]
            val rotated = rotate(recompressed, degrees)
            assertRecoveredIdentity(rotated, owner, photo, "$degrees degree scene $seed")

            rotated.recycle()
            cropped.recycle()
            recompressed.recycle()
            marked.recycle()
        }
    }

    private fun assertRecoveredIdentity(
        bitmap: Bitmap,
        owner: String,
        photo: String,
        message: String,
    ) {
        val result = HiddenWatermark.inspect(bitmap)
        assertEquals(message, HiddenWatermark.robustFormatVersion, result.formatVersion)
        assertEquals(message, compactReference(owner), result.ownerReference)
        assertEquals(message, compactReference(photo), result.photoReference)
        assertEquals(message, "tiled", result.payloadRecoveryMode)
    }

    private fun embedLegacyPresence(bitmap: Bitmap) {
        val row = IntArray(bitmap.width)
        for (y in 0 until bitmap.height step 4) {
            bitmap.getPixels(row, 0, bitmap.width, 0, y, bitmap.width, 1)
            for (x in 0 until bitmap.width - 1 step 4) {
                val value = ((x / 4) * 73_856_093) xor ((y / 4) * 19_349_663) xor 0x5A17
                val delta = 4 * if ((value and 1) == 0) -1 else 1
                row[x] = shift(row[x], delta)
                row[x + 1] = shift(row[x + 1], -delta)
            }
            bitmap.setPixels(row, 0, bitmap.width, 0, y, bitmap.width, 1)
        }
    }

    private fun shift(color: Int, delta: Int): Int = Color.argb(
        Color.alpha(color),
        (Color.red(color) + delta).coerceIn(0, 255),
        (Color.green(color) + delta).coerceIn(0, 255),
        (Color.blue(color) + delta).coerceIn(0, 255),
    )

    private fun compactReference(value: String): String {
        var hash = 0x811c9dc5L
        for (byte in value.toByteArray()) {
            hash = ((hash xor (byte.toInt() and 0xff).toLong()) * 0x01000193L) and 0xffffffffL
        }
        return hash.toString(16).padStart(8, '0')
    }

    private fun scene(seed: Int): Bitmap {
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val pixels = IntArray(width * height)
        for (row in 0 until height) {
            for (column in 0 until width) {
                val noise = pseudoRandom(column, row, seed)
                val red: Int
                val green: Int
                val blue: Int
                when (seed % 8) {
                    0 -> {
                        red = column * 255 / width
                        green = row * 255 / height
                        blue = (column + row) * 255 / (width + height)
                    }
                    1 -> {
                        red = noise
                        green = pseudoRandom(column + 17, row + 29, seed)
                        blue = pseudoRandom(column + 43, row + 7, seed)
                    }
                    2 -> {
                        val value = if (((column / 12) + (row / 12)) % 2 == 0) 220 else 35
                        red = value
                        green = 255 - value
                        blue = 128
                    }
                    3 -> {
                        red = 12 + noise / 12
                        green = 16 + noise / 14
                        blue = 20 + noise / 10
                    }
                    4 -> {
                        red = 225 + noise / 9
                        green = 220 + noise / 8
                        blue = 215 + noise / 7
                    }
                    5 -> {
                        red = 110 + noise / 10
                        green = 115 + noise / 12
                        blue = 120 + noise / 14
                    }
                    6 -> {
                        red = (column / 20 % 3) * 100 + noise / 5
                        green = (row / 20 % 3) * 100 + noise / 6
                        blue = ((column + row) / 30 % 3) * 100 + noise / 7
                    }
                    else -> {
                        val distance = abs(column - width / 2) + abs(row - height / 2)
                        red = 255 - min(255, distance)
                        green = min(255, distance + noise / 5)
                        blue = 80 + noise / 2
                    }
                }
                pixels[row * width + column] = Color.rgb(
                    red.coerceIn(0, 255),
                    green.coerceIn(0, 255),
                    blue.coerceIn(0, 255),
                )
            }
        }
        bitmap.setPixels(pixels, 0, width, 0, 0, width, height)
        return bitmap
    }

    private fun pseudoRandom(column: Int, row: Int, seed: Int): Int {
        var value = column * 73_856_093 xor row * 19_349_663 xor seed * 83_492_791
        value = value xor (value ushr 13)
        return value and 0xff
    }

    private fun jpeg(source: Bitmap, quality: Int): Bitmap {
        val output = ByteArrayOutputStream()
        assertTrue(source.compress(Bitmap.CompressFormat.JPEG, quality, output))
        return android.graphics.BitmapFactory.decodeByteArray(output.toByteArray(), 0, output.size())
    }

    private fun resize(source: Bitmap, scale: Double): Bitmap = Bitmap.createScaledBitmap(
        source,
        max(HiddenWatermark.minimumDimension, (source.width * scale).toInt()),
        max(HiddenWatermark.minimumDimension, (source.height * scale).toInt()),
        true,
    )

    private fun centerCrop(source: Bitmap, scale: Double): Bitmap {
        val cropWidth = (source.width * scale).toInt().coerceAtLeast(HiddenWatermark.minimumDimension)
        val cropHeight = (source.height * scale).toInt().coerceAtLeast(HiddenWatermark.minimumDimension)
        return Bitmap.createBitmap(
            source,
            (source.width - cropWidth) / 2,
            (source.height - cropHeight) / 2,
            cropWidth,
            cropHeight,
        )
    }

    private fun rotate(source: Bitmap, degrees: Float): Bitmap = Bitmap.createBitmap(
        source,
        0,
        0,
        source.width,
        source.height,
        Matrix().apply { postRotate(degrees) },
        true,
    )

    private fun grayscale(source: Bitmap): Bitmap {
        val output = Bitmap.createBitmap(source.width, source.height, Bitmap.Config.ARGB_8888)
        Canvas(output).drawBitmap(
            source,
            0f,
            0f,
            Paint().apply {
                colorFilter = ColorMatrixColorFilter(ColorMatrix().apply { setSaturation(0f) })
            },
        )
        return output
    }

    private fun convolve(source: Bitmap, sharpen: Boolean): Bitmap {
        val sourcePixels = IntArray(source.width * source.height)
        val outputPixels = IntArray(sourcePixels.size)
        source.getPixels(sourcePixels, 0, source.width, 0, 0, source.width, source.height)
        sourcePixels.copyInto(outputPixels)
        for (row in 1 until source.height - 1) {
            for (column in 1 until source.width - 1) {
                val center = row * source.width + column
                for (channelShift in listOf(16, 8, 0)) {
                    val centerValue = sourcePixels[center] shr channelShift and 0xff
                    val neighbors = listOf(
                        sourcePixels[center - source.width],
                        sourcePixels[center - 1],
                        sourcePixels[center + 1],
                        sourcePixels[center + source.width],
                    ).sumOf { it shr channelShift and 0xff }
                    val value = if (sharpen) centerValue * 5 - neighbors else (centerValue * 4 + neighbors) / 8
                    val mask = 0xff shl channelShift
                    outputPixels[center] = (outputPixels[center] and mask.inv()) or (value.coerceIn(0, 255) shl channelShift)
                }
            }
        }
        return Bitmap.createBitmap(source.width, source.height, Bitmap.Config.ARGB_8888).apply {
            setPixels(outputPixels, 0, source.width, 0, 0, source.width, source.height)
        }
    }

    private fun screenshotSimulation(source: Bitmap): Bitmap {
        val output = Bitmap.createBitmap(source.width, source.height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        canvas.drawColor(Color.BLACK)
        val inset = source.width / 16
        canvas.drawBitmap(
            source,
            null,
            android.graphics.Rect(inset, inset, source.width - inset, source.height - inset),
            Paint(Paint.FILTER_BITMAP_FLAG),
        )
        return jpeg(output, 90).also { output.recycle() }
    }

    private fun socialExportSimulation(source: Bitmap): Bitmap {
        val resized = Bitmap.createScaledBitmap(source, 192, 144, true)
        return jpeg(resized, 75).also { resized.recycle() }
    }

    private fun writeJpeg(bitmap: Bitmap, file: File) {
        file.outputStream().use { assertTrue(bitmap.compress(Bitmap.CompressFormat.JPEG, 98, it)) }
        bitmap.recycle()
    }
}

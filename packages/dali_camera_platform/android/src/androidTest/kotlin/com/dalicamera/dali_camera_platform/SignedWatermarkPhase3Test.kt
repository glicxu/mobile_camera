package com.dalicamera.dali_camera_platform

import android.graphics.Bitmap
import android.graphics.Color
import android.util.Base64
import androidx.exifinterface.media.ExifInterface
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.util.Date

@RunWith(AndroidJUnit4::class)
class SignedWatermarkPhase3Test {
    @Test
    fun signsVerifiesAndDetectsImageOrMetadataTampering() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val directory = File(context.cacheDir, "watermark-phase3").apply { mkdirs() }
        val owner = "phase3-owner-android"
        val photo = "phase3-photo-android"
        val identity = identity(owner, photo, "PHASE3-PHOTO")
        val source = File(directory, "signed.jpg")
        writeJpeg(scene(Color.rgb(80, 130, 190)), source)
        PhotoMetadata.capture(
            source,
            Date(0),
            JSONObject()
                .put("schema", "dali.capture-debug.v1")
                .put("hiddenWatermark", identity)
                .put("hiddenWatermarkPixels", true)
                .put("pixelWatermarkPayload", identity)
                .toString(),
            "Dali Camera Phase 3",
        )

        val sourceExif = ExifInterface(source)
        val comment = PhotoMetadata.rawComment(sourceExif)
        val verified = SignedWatermark.inspect(source.path, comment, identity)
        assertEquals("verified", verified?.status)
        assertTrue(verified?.signatureValid == true)
        assertTrue(verified?.imageDigestMatches == true)
        assertTrue(verified?.metadataMatches == true)
        assertEquals(
            "dali.capture-debug.v1",
            JSONObject(PhotoMetadata.read(sourceExif).getString("debug")).getString("schema"),
        )

        val rendered = File(directory, "rendered.jpg")
        writeJpeg(scene(Color.rgb(95, 145, 205)), rendered)
        PhotoMetadata.copy(source.path, rendered, "Dali Camera Phase 3", captureEffectsApplied = true)
        val renderedExif = ExifInterface(rendered)
        assertEquals(
            "verified",
            SignedWatermark.inspect(
                rendered.path,
                PhotoMetadata.rawComment(renderedExif),
                renderedExif.getAttribute("ImageUniqueID"),
            )?.status,
        )

        val tampered = File(directory, "tampered.jpg")
        writeJpeg(scene(Color.rgb(190, 70, 90)), tampered)
        ExifInterface(tampered).apply {
            setAttribute("ImageUniqueID", identity)
            setAttribute("UserComment", comment)
            saveAttributes()
        }
        assertEquals(
            "image_modified",
            SignedWatermark.inspect(tampered.path, comment, identity)?.status,
        )

        val conflictingIdentity = identity("different-owner", "different-photo")
        assertEquals(
            "metadata_conflict",
            SignedWatermark.inspect(source.path, comment, conflictingIdentity)?.status,
        )
        assertEquals(
            "metadata_conflict",
            SignedWatermark.inspect(
                source.path,
                comment,
                identity(owner, photo, "FORGED-LABEL"),
            )?.status,
        )
        assertEquals(
            "metadata_missing",
            SignedWatermark.inspect(source.path, comment, null)?.status,
        )
        val invalidWrapper = JSONObject(checkNotNull(comment))
        val originalSignature = invalidWrapper.getString("signature")
        invalidWrapper.put(
            "signature",
            (if (originalSignature.first() == 'A') "B" else "A") + originalSignature.substring(1),
        )
        assertEquals(
            "invalid_signature",
            SignedWatermark.inspect(source.path, invalidWrapper.toString(), identity)?.status,
        )

        source.delete()
        rendered.delete()
        tampered.delete()
        directory.delete()
    }

    private fun identity(owner: String, photo: String, publicId: String? = null): String {
        val json = JSONObject().put("v", 2).put("owner", owner).put("photo", photo)
        publicId?.let { json.put("public", it) }
        val payload = json.toString()
        val encoded = Base64.encodeToString(
            payload.toByteArray(),
            Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING,
        )
        return "DALI2-$encoded"
    }

    private fun scene(base: Int): Bitmap {
        val bitmap = Bitmap.createBitmap(320, 240, Bitmap.Config.ARGB_8888)
        val pixels = IntArray(bitmap.width * bitmap.height)
        for (y in 0 until bitmap.height) {
            for (x in 0 until bitmap.width) {
                val red = (Color.red(base) + x / 5 + y / 9).coerceIn(0, 255)
                val green = (Color.green(base) + x / 11 + y / 4).coerceIn(0, 255)
                val blue = (Color.blue(base) + x / 7 + y / 13).coerceIn(0, 255)
                pixels[y * bitmap.width + x] = Color.rgb(red, green, blue)
            }
        }
        bitmap.setPixels(pixels, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
        return bitmap
    }

    private fun writeJpeg(bitmap: Bitmap, file: File) {
        file.outputStream().use { assertTrue(bitmap.compress(Bitmap.CompressFormat.JPEG, 95, it)) }
        bitmap.recycle()
    }
}

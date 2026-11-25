package com.dalicamera.dali_camera_platform

import android.content.Context
import android.graphics.BitmapFactory
import androidx.exifinterface.media.ExifInterface
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

internal object PhotoMetadata {
    private fun isDaliWatermark(value: String): Boolean =
        value.startsWith("DALI1-") || value.startsWith("DALI2-")

    // EXIF writers commonly encode UserComment as ASCII. JSON escapes preserve
    // every UTF-16 code unit, including surrogate pairs, without losing text.
    private fun asciiJson(value: String): String = buildString {
        for (char in value) if (char.code > 127) append(String.format(Locale.US, "\\u%04x", char.code)) else append(char)
    }

    private fun comment(exif: ExifInterface): String? {
        val bytes = exif.getAttributeBytes("UserComment")
        if (bytes != null && bytes.size >= 8 && String(bytes, 0, 7, Charsets.US_ASCII) == "UNICODE") {
            val text = bytes.copyOfRange(8, bytes.size)
            val charset = if (text.size >= 2 && text[0] == 0xff.toByte() && text[1] == 0xfe.toByte()) Charsets.UTF_16LE else Charsets.UTF_16BE
            return String(text, charset).trimStart('\uFEFF').trimEnd('\u0000')
        }
        return exif.getAttribute("UserComment")
    }

    fun rawComment(exif: ExifInterface): String? = comment(exif)
    // Deliberately exclude MakerNote, serial numbers, thumbnails, and geometry
    // tied to the old pixels. Copy documented photographic fields only.
    private val fields = linkedMapOf(
        "dateOriginal" to "DateTimeOriginal", "timeZone" to "OffsetTimeOriginal",
        "subsecond" to "SubSecTimeOriginal", "make" to "Make", "model" to "Model",
        "lensMake" to "LensMake", "lensModel" to "LensModel", "exposureSeconds" to "ExposureTime",
        "aperture" to "FNumber", "iso" to "PhotographicSensitivity", "exposureBias" to "ExposureBiasValue",
        "exposureProgram" to "ExposureProgram", "exposureMode" to "ExposureMode",
        "meteringMode" to "MeteringMode", "flash" to "Flash", "focalLength" to "FocalLength",
        "focalLength35mm" to "FocalLengthIn35mmFilm", "digitalZoom" to "DigitalZoomRatio",
        "whiteBalance" to "WhiteBalance", "colorSpace" to "ColorSpace", "software" to "Software",
        "artist" to "Artist", "copyright" to "Copyright", "description" to "ImageDescription",
        "debug" to "UserComment", "hiddenWatermark" to "ImageUniqueID"
    )

    private val editableFields = linkedMapOf(
        "description" to "ImageDescription", "artist" to "Artist", "copyright" to "Copyright",
        "software" to "Software", "dateOriginal" to "DateTimeOriginal", "timeZone" to "OffsetTimeOriginal",
        "subsecond" to "SubSecTimeOriginal", "make" to "Make", "model" to "Model",
        "lensMake" to "LensMake", "lensModel" to "LensModel", "exposureSeconds" to "ExposureTime",
        "aperture" to "FNumber", "iso" to "PhotographicSensitivity", "exposureBias" to "ExposureBiasValue",
        "exposureProgram" to "ExposureProgram", "exposureMode" to "ExposureMode", "meteringMode" to "MeteringMode",
        "flash" to "Flash", "focalLength" to "FocalLength", "focalLength35mm" to "FocalLengthIn35mmFilm",
        "digitalZoom" to "DigitalZoomRatio", "whiteBalance" to "WhiteBalance", "colorSpace" to "ColorSpace"
    )

    fun software(context: Context): String {
        val info = context.packageManager.getPackageInfo(context.packageName, 0)
        val build = if (android.os.Build.VERSION.SDK_INT >= 28) info.longVersionCode else @Suppress("DEPRECATION") info.versionCode.toLong()
        return "Dali Camera ${info.versionName} ($build)"
    }

    fun capture(file: File, at: Date, debug: String?, software: String) {
        val exif = ExifInterface(file)
        val payload = debug?.let { runCatching { JSONObject(it) }.getOrNull() }
        val hiddenWatermark = payload?.optString("hiddenWatermark")?.takeIf(::isDaliWatermark)
        val debugComment = payload?.takeIf { it.optString("schema") == "dali.capture-debug.v1" }?.apply {
            remove("hiddenWatermark")
            remove("hiddenWatermarkPixels")
            remove("pixelWatermarkPayload")
        }?.toString()
        val date = exif.getAttribute("DateTimeOriginal") ?: SimpleDateFormat("yyyy:MM:dd HH:mm:ss", Locale.US).format(at)
        exif.setAttribute("DateTimeOriginal", date)
        exif.setAttribute("DateTimeDigitized", exif.getAttribute("DateTimeDigitized") ?: date)
        val minutes = TimeZone.getDefault().getOffset(at.time) / 60000
        val zone = String.format(Locale.US, "%s%02d:%02d", if (minutes < 0) "-" else "+", kotlin.math.abs(minutes) / 60, kotlin.math.abs(minutes) % 60)
        exif.setAttribute("OffsetTimeOriginal", exif.getAttribute("OffsetTimeOriginal") ?: zone)
        exif.setAttribute("OffsetTimeDigitized", exif.getAttribute("OffsetTimeDigitized") ?: zone)
        exif.setAttribute("SubSecTimeOriginal", exif.getAttribute("SubSecTimeOriginal") ?: String.format(Locale.US, "%03d", at.time % 1000))
        exif.setAttribute("Software", software)
        exif.setAttribute("ImageUniqueID", hiddenWatermark)
        val signedComment = SignedWatermark.sign(file, hiddenWatermark, debugComment, createKey = true)
        exif.setAttribute("UserComment", (signedComment ?: debugComment)?.let { asciiJson(it) })
        exif.saveAttributes()
    }

    fun copy(source: String, destination: File, software: String, captureEffectsApplied: Boolean = false) {
        val input = ExifInterface(source)
        val sourceComment = comment(input)
        var debugComment = SignedWatermark.captureDebug(sourceComment)
        PhotoLocation.copyGps(source, destination)
        val output = ExifInterface(destination)
        for (tag in fields.values + listOf("DateTimeDigitized", "OffsetTimeDigitized", "SubSecTimeDigitized")) {
            if (tag != "ColorSpace") output.setAttribute(tag, input.getAttribute(tag))
        }
        if (captureEffectsApplied) debugComment?.let { comment ->
            runCatching { JSONObject(comment) }.getOrNull()?.takeIf { it.optString("schema") == "dali.capture-debug.v1" }?.let {
                debugComment = it.put("captureEffectsApplied", true).toString()
            }
        }
        // Pixels have already been rotated/cropped by the renderer.
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(destination.path, bounds)
        output.setAttribute("Orientation", "1")
        output.setAttribute("PixelXDimension", bounds.outWidth.toString())
        output.setAttribute("PixelYDimension", bounds.outHeight.toString())
        output.setAttribute("Software", software)
        val hiddenWatermark = input.getAttribute("ImageUniqueID")?.takeIf(::isDaliWatermark)
        val signedComment = SignedWatermark.sign(destination, hiddenWatermark, debugComment, createKey = false)
        output.setAttribute("UserComment", (signedComment ?: debugComment)?.let { asciiJson(it) })
        output.saveAttributes()
    }

    fun edit(source: String, destination: File, metadata: JSONObject) {
        File(source).copyTo(destination, overwrite = true)
        val exif = ExifInterface(destination)
        for ((name, tag) in editableFields) {
            if (metadata.has(name)) {
                val value = metadata.optString(name).trim().ifEmpty { null }
                exif.setAttribute(tag, value)
                when (name) {
                    "dateOriginal" -> exif.setAttribute("DateTimeDigitized", value)
                    "timeZone" -> exif.setAttribute("OffsetTimeDigitized", value)
                    "subsecond" -> exif.setAttribute("SubSecTimeDigitized", value)
                }
            }
        }
        if (metadata.has("latitude") || metadata.has("longitude")) {
            val latitude = metadata.optString("latitude").trim()
            val longitude = metadata.optString("longitude").trim()
            if (latitude.isEmpty() && longitude.isEmpty()) {
                for (tag in listOf("GPSLatitude", "GPSLatitudeRef", "GPSLongitude", "GPSLongitudeRef")) {
                    exif.setAttribute(tag, null)
                }
            } else {
                require(latitude.isNotEmpty() && longitude.isNotEmpty()) { "Latitude and longitude must be provided together" }
                exif.setLatLong(latitude.toDouble(), longitude.toDouble())
            }
        }
        if (metadata.has("altitude")) {
            val altitude = metadata.optString("altitude").trim()
            if (altitude.isEmpty()) {
                exif.setAttribute("GPSAltitude", null)
                exif.setAttribute("GPSAltitudeRef", null)
            } else {
                exif.setAltitude(altitude.toDouble())
            }
        }
        if (metadata.has("hiddenWatermark")) {
            val value = metadata.optString("hiddenWatermark").trim()
                .takeIf(::isDaliWatermark)
            exif.setAttribute("ImageUniqueID", value)
        }
        exif.saveAttributes()
    }

    fun read(exif: ExifInterface): JSONObject {
        val result = JSONObject()
        for ((name, tag) in fields) exif.getAttribute(tag)?.let { result.put(name, it) }
        SignedWatermark.captureDebug(comment(exif))?.let { result.put("debug", it) }
        result.put("width", exif.getAttributeInt("ImageWidth", 0))
        result.put("height", exif.getAttributeInt("ImageLength", 0))
        result.put("orientation", exif.getAttributeInt("Orientation", 1))
        for ((name, tag) in listOf("exposureSeconds" to "ExposureTime", "aperture" to "FNumber", "exposureBias" to "ExposureBiasValue", "focalLength" to "FocalLength", "digitalZoom" to "DigitalZoomRatio")) {
            val number = exif.getAttributeDouble(tag, Double.NaN)
            if (number.isFinite()) result.put(name, number)
        }
        exif.latLong?.let { result.put("latitude", it[0]).put("longitude", it[1]) }
        val altitude = exif.getAltitude(Double.NaN)
        if (altitude.isFinite()) result.put("altitude", altitude)
        return result
    }

    fun capturedMillis(file: File): Long? = runCatching {
        val exif = ExifInterface(file)
        val date = exif.getAttribute("DateTimeOriginal") ?: return null
        val offset = exif.getAttribute("OffsetTimeOriginal")
        val format = SimpleDateFormat("yyyy:MM:dd HH:mm:ss", Locale.US)
        if (offset != null) format.timeZone = TimeZone.getTimeZone("GMT$offset")
        format.parse(date)?.time
    }.getOrNull()
}

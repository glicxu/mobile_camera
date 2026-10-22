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
        "debug" to "UserComment"
    )

    fun software(context: Context): String {
        val info = context.packageManager.getPackageInfo(context.packageName, 0)
        val build = if (android.os.Build.VERSION.SDK_INT >= 28) info.longVersionCode else @Suppress("DEPRECATION") info.versionCode.toLong()
        return "Dali Camera ${info.versionName} ($build)"
    }

    fun capture(file: File, at: Date, debug: String?, software: String) {
        val exif = ExifInterface(file)
        val date = exif.getAttribute("DateTimeOriginal") ?: SimpleDateFormat("yyyy:MM:dd HH:mm:ss", Locale.US).format(at)
        exif.setAttribute("DateTimeOriginal", date)
        exif.setAttribute("DateTimeDigitized", exif.getAttribute("DateTimeDigitized") ?: date)
        val minutes = TimeZone.getDefault().getOffset(at.time) / 60000
        val zone = String.format(Locale.US, "%s%02d:%02d", if (minutes < 0) "-" else "+", kotlin.math.abs(minutes) / 60, kotlin.math.abs(minutes) % 60)
        exif.setAttribute("OffsetTimeOriginal", exif.getAttribute("OffsetTimeOriginal") ?: zone)
        exif.setAttribute("OffsetTimeDigitized", exif.getAttribute("OffsetTimeDigitized") ?: zone)
        exif.setAttribute("SubSecTimeOriginal", exif.getAttribute("SubSecTimeOriginal") ?: String.format(Locale.US, "%03d", at.time % 1000))
        exif.setAttribute("Software", software)
        exif.setAttribute("UserComment", debug?.let { asciiJson(it) })
        exif.saveAttributes()
    }

    fun copy(source: String, destination: File, software: String, captureEffectsApplied: Boolean = false) {
        val input = ExifInterface(source)
        PhotoLocation.copyGps(source, destination)
        val output = ExifInterface(destination)
        for (tag in fields.values + listOf("DateTimeDigitized", "OffsetTimeDigitized", "SubSecTimeDigitized")) {
            if (tag != "ColorSpace") output.setAttribute(tag, input.getAttribute(tag))
        }
        output.setAttribute("UserComment", comment(input)?.let { asciiJson(it) })
        if (captureEffectsApplied) comment(input)?.let { comment ->
            runCatching { JSONObject(comment) }.getOrNull()?.takeIf { it.optString("schema") == "dali.capture-debug.v1" }?.let {
                output.setAttribute("UserComment", asciiJson(it.put("captureEffectsApplied", true).toString()))
            }
        }
        // Pixels have already been rotated/cropped by the renderer.
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(destination.path, bounds)
        output.setAttribute("Orientation", "1")
        output.setAttribute("PixelXDimension", bounds.outWidth.toString())
        output.setAttribute("PixelYDimension", bounds.outHeight.toString())
        output.setAttribute("Software", software)
        output.saveAttributes()
    }

    fun read(exif: ExifInterface): JSONObject {
        val result = JSONObject()
        for ((name, tag) in fields) exif.getAttribute(tag)?.let { result.put(name, it) }
        comment(exif)?.let { result.put("debug", it) }
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

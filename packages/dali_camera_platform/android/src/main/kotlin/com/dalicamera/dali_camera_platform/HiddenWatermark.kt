package com.dalicamera.dali_camera_platform

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.SystemClock
import android.util.Base64
import org.json.JSONObject
import java.io.File
import kotlin.math.abs
import kotlin.math.min

internal object HiddenWatermark {
    const val formatVersion = "DALI_PIXEL_V1"
    const val payloadFormatVersion = "DALI_PIXEL_V2"
    const val robustFormatVersion = "DALI_PIXEL_V3"
    const val minimumDimension = 64
    private const val stride = 4
    private const val presenceStrength = 4
    private const val payloadStrength = 6
    private const val robustStrength = 4
    private const val robustPayloadStrength = 8
    private const val detectionThreshold = 0.75
    private const val robustDetectionThreshold = 5.0
    private const val robustPeriod = 8
    private const val robustPayloadPeriod = 16
    private const val payloadBytes = 13
    private const val payloadBits = payloadBytes * 8

    data class Detection(
        val detected: Boolean,
        val score: Double,
        val samples: Int,
        val formatVersion: String = HiddenWatermark.formatVersion,
        val ownerReference: String? = null,
        val photoReference: String? = null,
        val payloadConfidence: Double? = null,
        val payloadRecoveryMode: String? = null,
        val robustScore: Double? = null,
        val robustAxis: String? = null,
        val robustQuarterTurns: Int? = null,
        val elapsedMillis: Long? = null,
    )

    private data class Payload(
        val bytes: ByteArray,
        val ownerReference: String,
        val photoReference: String,
    )

    private fun sign(column: Int, row: Int): Int {
        val value = (column * 73_856_093) xor (row * 19_349_663) xor 0x5A17
        return if ((value and 1) == 0) -1 else 1
    }

    private fun mixedPeriodicSign(column: Int, row: Int, period: Int, seed: Int): Int {
        var value = Math.floorMod(column, period) * 73_856_093 xor
            (Math.floorMod(row, period) * 19_349_663) xor seed
        value = value xor (value ushr 13)
        value *= 1_274_126_177
        value = value xor (value ushr 16)
        return if ((value and 0x100) == 0) -1 else 1
    }

    private fun robustSign(column: Int, row: Int): Int =
        mixedPeriodicSign(column, row, robustPeriod, 0x13579BDF)

    private fun robustSecondarySign(column: Int, row: Int): Int =
        mixedPeriodicSign(column, row, robustPeriod, 0x2468ACE)

    private fun robustPayloadSign(column: Int, row: Int): Int =
        mixedPeriodicSign(column, row, robustPayloadPeriod, 0x5A71C3E)

    private fun shifted(color: Int, delta: Int): Int {
        val red = ((color shr 16) and 0xff) + delta
        val green = ((color shr 8) and 0xff) + delta
        val blue = (color and 0xff) + delta
        return (color and -0x1000000) or
            (red.coerceIn(0, 255) shl 16) or
            (green.coerceIn(0, 255) shl 8) or
            blue.coerceIn(0, 255)
    }

    private fun luminance(color: Int): Int =
        (((color shr 16) and 0xff) * 77 + ((color shr 8) and 0xff) * 150 + (color and 0xff) * 29) / 256

    private fun compactReference(value: String): Long {
        var hash = 0x811c9dc5L
        for (byte in value.toByteArray(Charsets.UTF_8)) {
            hash = ((hash xor (byte.toInt() and 0xff).toLong()) * 0x01000193L) and 0xffffffffL
        }
        return hash
    }

    private fun hexReference(value: Long): String = value.toString(16).padStart(8, '0')

    internal fun reference(value: String): String = hexReference(compactReference(value))

    private fun writeUInt32(bytes: ByteArray, offset: Int, value: Long) {
        for (index in 0 until 4) bytes[offset + index] = (value shr (24 - index * 8)).toByte()
    }

    private fun readUInt32(bytes: ByteArray, offset: Int): Long {
        var value = 0L
        for (index in 0 until 4) value = (value shl 8) or (bytes[offset + index].toInt() and 0xff).toLong()
        return value
    }

    private fun crc16(bytes: ByteArray, length: Int): Int {
        var crc = 0xffff
        for (index in 0 until length) {
            crc = crc xor ((bytes[index].toInt() and 0xff) shl 8)
            repeat(8) { crc = if ((crc and 0x8000) != 0) ((crc shl 1) xor 0x1021) and 0xffff else (crc shl 1) and 0xffff }
        }
        return crc
    }

    private fun payload(identity: String?): Payload? {
        if (identity == null || !identity.startsWith("DALI2-")) return null
        return runCatching {
            val encoded = identity.substring(6)
            val decoded = Base64.decode(encoded, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
            val json = JSONObject(String(decoded, Charsets.UTF_8))
            if (json.optInt("v") != 2) return null
            val owner = json.getString("owner").takeIf { it.isNotEmpty() } ?: return null
            val photo = json.getString("photo").takeIf { it.isNotEmpty() } ?: return null
            val ownerHash = compactReference(owner)
            val photoHash = compactReference(photo)
            val bytes = ByteArray(payloadBytes)
            bytes[0] = 0xD2.toByte()
            bytes[1] = 0xA7.toByte()
            bytes[2] = 2
            writeUInt32(bytes, 3, ownerHash)
            writeUInt32(bytes, 7, photoHash)
            val crc = crc16(bytes, 11)
            bytes[11] = (crc shr 8).toByte()
            bytes[12] = crc.toByte()
            Payload(bytes, hexReference(ownerHash), hexReference(photoHash))
        }.getOrNull()
    }

    fun embed(bitmap: Bitmap, identity: String? = null) {
        if (!bitmap.isMutable || bitmap.width < minimumDimension || bitmap.height < minimumDimension) return
        val row = IntArray(bitmap.width)
        for (y in 0 until bitmap.height step stride) {
            bitmap.getPixels(row, 0, bitmap.width, 0, y, bitmap.width, 1)
            for (x in 0 until bitmap.width - 1 step stride) {
                val delta = presenceStrength * sign(x / stride, y / stride)
                row[x] = shifted(row[x], delta)
                row[x + 1] = shifted(row[x + 1], -delta)
            }
            bitmap.setPixels(row, 0, bitmap.width, 0, y, bitmap.width, 1)
        }
        for (y in 1 until bitmap.height step stride) {
            bitmap.getPixels(row, 0, bitmap.width, 0, y, bitmap.width, 1)
            for (x in 0 until bitmap.width - 1 step stride) {
                val delta = robustStrength * (
                    robustSign(x / stride, y / stride) +
                        robustSecondarySign(x / stride, y / stride)
                    )
                row[x] = shifted(row[x], delta)
                row[x + 1] = shifted(row[x + 1], -delta)
            }
            bitmap.setPixels(row, 0, bitmap.width, 0, y, bitmap.width, 1)
        }
        val payload = payload(identity) ?: return
        var sample = 0
        for (y in 2 until bitmap.height step stride) {
            bitmap.getPixels(row, 0, bitmap.width, 0, y, bitmap.width, 1)
            for (x in 0 until bitmap.width - 1 step stride) {
                val bitIndex = sample % payloadBits
                val bit = (payload.bytes[bitIndex / 8].toInt() shr (7 - bitIndex % 8)) and 1
                val delta = payloadStrength * sign(x / stride + 911, y / stride + 353) * if (bit == 1) 1 else -1
                row[x] = shifted(row[x], delta)
                row[x + 1] = shifted(row[x + 1], -delta)
                sample++
            }
            bitmap.setPixels(row, 0, bitmap.width, 0, y, bitmap.width, 1)
        }
        for (y in 3 until bitmap.height step stride) {
            bitmap.getPixels(row, 0, bitmap.width, 0, y, bitmap.width, 1)
            for (x in 0 until bitmap.width - 1 step stride) {
                val column = x / stride
                val gridRow = y / stride
                val cell = Math.floorMod(gridRow, robustPayloadPeriod) * robustPayloadPeriod +
                    Math.floorMod(column, robustPayloadPeriod)
                val bitIndex = cell % payloadBits
                val bit = (payload.bytes[bitIndex / 8].toInt() shr (7 - bitIndex % 8)) and 1
                val delta = robustPayloadStrength * robustPayloadSign(column, gridRow) *
                    if (bit == 1) 1 else -1
                row[x] = shifted(row[x], delta)
                row[x + 1] = shifted(row[x + 1], -delta)
            }
            bitmap.setPixels(row, 0, bitmap.width, 0, y, bitmap.width, 1)
        }
    }

    fun embed(file: File, identity: String? = null) {
        val decoded = BitmapFactory.decodeFile(file.path) ?: return
        val bitmap = if (decoded.isMutable) decoded else decoded.copy(Bitmap.Config.ARGB_8888, true)
        try {
            embed(bitmap, identity)
            file.outputStream().use { check(bitmap.compress(Bitmap.CompressFormat.JPEG, 98, it)) }
        } finally {
            if (bitmap !== decoded) bitmap.recycle()
            decoded.recycle()
        }
    }

    fun detect(path: String): Boolean = inspect(path).detected

    fun inspect(path: String): Detection {
        val started = SystemClock.elapsedRealtime()
        val bitmap = BitmapFactory.decodeFile(path)
            ?: return Detection(false, 0.0, 0, elapsedMillis = SystemClock.elapsedRealtime() - started)
        return try {
            inspect(bitmap).copy(elapsedMillis = SystemClock.elapsedRealtime() - started)
        } finally { bitmap.recycle() }
    }

    fun detect(bytes: ByteArray): Boolean = inspect(bytes).detected

    fun inspect(bytes: ByteArray): Detection {
        val started = SystemClock.elapsedRealtime()
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            ?: return Detection(false, 0.0, 0, elapsedMillis = SystemClock.elapsedRealtime() - started)
        return try {
            inspect(bitmap).copy(elapsedMillis = SystemClock.elapsedRealtime() - started)
        } finally { bitmap.recycle() }
    }

    fun inspect(bitmap: Bitmap): Detection {
        if (bitmap.width < minimumDimension || bitmap.height < minimumDimension) return Detection(false, 0.0, 0)
        val row = IntArray(bitmap.width)
        var score = 0.0
        var samples = 0
        for (y in 0 until bitmap.height step stride) {
            bitmap.getPixels(row, 0, bitmap.width, 0, y, bitmap.width, 1)
            for (x in 0 until bitmap.width - 1 step stride) {
                score += sign(x / stride, y / stride) * (luminance(row[x]) - luminance(row[x + 1]))
                samples++
            }
        }
        val normalizedScore = if (samples == 0) 0.0 else score / samples
        val payload = inspectPayload(bitmap)
        val robustCandidate = inspectRobustAligned(bitmap) ?: if (payload == null) inspectRobust(bitmap) else null
        val robustPayload = if (payload == null && robustCandidate != null) {
            inspectRobustPayload(bitmap, robustCandidate)
        } else null
        val robust = robustCandidate?.takeIf {
            it.score > robustDetectionThreshold || robustPayload != null
        }
        val recoveredPayload = robustPayload ?: payload
        return Detection(
            detected = recoveredPayload != null || robust != null || (samples > 0 && normalizedScore > detectionThreshold),
            score = normalizedScore,
            samples = samples,
            formatVersion = when {
                robust != null -> robustFormatVersion
                recoveredPayload != null -> payloadFormatVersion
                else -> formatVersion
            },
            ownerReference = recoveredPayload?.ownerReference,
            photoReference = recoveredPayload?.photoReference,
            payloadConfidence = recoveredPayload?.confidence,
            payloadRecoveryMode = when {
                robustPayload != null -> "tiled"
                payload != null -> "aligned"
                else -> null
            },
            robustScore = robust?.score,
            robustAxis = robust?.axis,
            robustQuarterTurns = robust?.quarterTurns,
        )
    }

    private data class RobustDetection(
        val score: Double,
        val axis: String,
        val quarterTurns: Int,
        val offsetX: Int,
        val offsetY: Int,
        val shiftX: Int,
        val shiftY: Int,
    )

    private fun inspectRobustAligned(bitmap: Bitmap): RobustDetection? {
        val row = IntArray(bitmap.width)
        var primaryCorrelation = 0.0
        var secondaryCorrelation = 0.0
        var samples = 0
        for (y in 1 until bitmap.height step stride) {
            bitmap.getPixels(row, 0, bitmap.width, 0, y, bitmap.width, 1)
            for (x in 0 until bitmap.width - 1 step stride) {
                val difference = luminance(row[x]) - luminance(row[x + 1])
                primaryCorrelation += robustSign(x / stride, y / stride) * difference
                secondaryCorrelation += robustSecondarySign(x / stride, y / stride) * difference
                samples++
            }
        }
        if (samples < 128) return null
        val score = min(
            abs(primaryCorrelation / samples),
            abs(secondaryCorrelation / samples),
        )
        return if (score > robustDetectionThreshold) {
            RobustDetection(score, "horizontal", 0, 0, 1, 0, 0)
        } else null
    }

    private fun inspectRobust(bitmap: Bitmap): RobustDetection? {
        var best: RobustDetection? = null
        val row = IntArray(bitmap.width)
        val nextRow = IntArray(bitmap.width)
        for (axis in 0..1) {
            for (offsetY in 0 until stride) {
                for (offsetX in 0 until stride) {
                    val totals = DoubleArray(robustPeriod * robustPeriod)
                    val counts = IntArray(totals.size)
                    var rowIndex = 0
                    var y = offsetY
                    while (y < bitmap.height - (if (axis == 1) 1 else 0)) {
                        bitmap.getPixels(row, 0, bitmap.width, 0, y, bitmap.width, 1)
                        if (axis == 1) {
                            bitmap.getPixels(nextRow, 0, bitmap.width, 0, y + 1, bitmap.width, 1)
                        }
                        var columnIndex = 0
                        var x = offsetX
                        while (x < bitmap.width - (if (axis == 0) 1 else 0)) {
                            val difference = if (axis == 0) {
                                luminance(row[x]) - luminance(row[x + 1])
                            } else {
                                luminance(row[x]) - luminance(nextRow[x])
                            }
                            val cell = (rowIndex % robustPeriod) * robustPeriod + (columnIndex % robustPeriod)
                            totals[cell] += difference.toDouble()
                            counts[cell]++
                            columnIndex++
                            x += stride
                        }
                        rowIndex++
                        y += stride
                    }
                    val sampleCount = counts.sum()
                    if (sampleCount < 128) continue
                    for (quarterTurns in 0..3) {
                        for (shiftY in 0 until robustPeriod) {
                            for (shiftX in 0 until robustPeriod) {
                                var primaryCorrelation = 0.0
                                var secondaryCorrelation = 0.0
                                for (localRow in 0 until robustPeriod) {
                                    for (localColumn in 0 until robustPeriod) {
                                        val mappedColumn: Int
                                        val mappedRow: Int
                                        when (quarterTurns) {
                                            1 -> {
                                                mappedColumn = localRow
                                                mappedRow = -localColumn
                                            }
                                            2 -> {
                                                mappedColumn = -localColumn
                                                mappedRow = -localRow
                                            }
                                            3 -> {
                                                mappedColumn = -localRow
                                                mappedRow = localColumn
                                            }
                                            else -> {
                                                mappedColumn = localColumn
                                                mappedRow = localRow
                                            }
                                        }
                                        val cell = localRow * robustPeriod + localColumn
                                        primaryCorrelation += robustSign(
                                            mappedColumn + shiftX,
                                            mappedRow + shiftY,
                                        ) * totals[cell]
                                        secondaryCorrelation += robustSecondarySign(
                                            mappedColumn + shiftX,
                                            mappedRow + shiftY,
                                        ) * totals[cell]
                                    }
                                }
                                val score = min(
                                    abs(primaryCorrelation / sampleCount),
                                    abs(secondaryCorrelation / sampleCount),
                                )
                                if (best == null || score > best.score) {
                                    best = RobustDetection(
                                        score,
                                        if (axis == 0) "horizontal" else "vertical",
                                        quarterTurns,
                                        offsetX,
                                        offsetY,
                                        shiftX,
                                        shiftY,
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
        return best
    }

    private data class RecoveredPayload(
        val ownerReference: String,
        val photoReference: String,
        val confidence: Double,
    )

    private fun inspectRobustPayload(
        bitmap: Bitmap,
        robust: RobustDetection,
    ): RecoveredPayload? {
        val row = IntArray(bitmap.width)
        val nextRow = IntArray(bitmap.width)
        val axis = if (robust.axis == "horizontal") 0 else 1
        val shiftXs = nearbyPayloadShifts(robust.shiftX)
        val shiftYs = nearbyPayloadShifts(robust.shiftY)
        run {
            for (offsetY in 0 until stride) {
                for (offsetX in 0 until stride) {
                    val cells = robustPayloadPeriod * robustPayloadPeriod
                    val totals = DoubleArray(cells)
                    val counts = IntArray(cells)
                    var rowIndex = 0
                    var y = offsetY
                    while (y < bitmap.height - (if (axis == 1) 1 else 0)) {
                        bitmap.getPixels(row, 0, bitmap.width, 0, y, bitmap.width, 1)
                        if (axis == 1) {
                            bitmap.getPixels(nextRow, 0, bitmap.width, 0, y + 1, bitmap.width, 1)
                        }
                        var columnIndex = 0
                        var x = offsetX
                        while (x < bitmap.width - (if (axis == 0) 1 else 0)) {
                            val difference = if (axis == 0) {
                                luminance(row[x]) - luminance(row[x + 1])
                            } else {
                                luminance(row[x]) - luminance(nextRow[x])
                            }
                            val cell = (rowIndex % robustPayloadPeriod) * robustPayloadPeriod +
                                (columnIndex % robustPayloadPeriod)
                            totals[cell] += difference.toDouble()
                            counts[cell]++
                            columnIndex++
                            x += stride
                        }
                        rowIndex++
                        y += stride
                    }
                    val quarterTurns = robust.quarterTurns
                    for (shiftY in shiftYs) {
                        for (shiftX in shiftXs) {
                                val bitTotals = DoubleArray(payloadBits)
                                val bitCounts = IntArray(payloadBits)
                                for (localRow in 0 until robustPayloadPeriod) {
                                    for (localColumn in 0 until robustPayloadPeriod) {
                                        val mapped = mapQuarterTurn(
                                            localColumn,
                                            localRow,
                                            quarterTurns,
                                        )
                                        val mappedColumn = Math.floorMod(
                                            mapped.first + shiftX,
                                            robustPayloadPeriod,
                                        )
                                        val mappedRow = Math.floorMod(
                                            mapped.second + shiftY,
                                            robustPayloadPeriod,
                                        )
                                        val bitIndex = (
                                            mappedRow * robustPayloadPeriod + mappedColumn
                                            ) % payloadBits
                                        val cell = localRow * robustPayloadPeriod + localColumn
                                        bitTotals[bitIndex] += robustPayloadSign(
                                            mappedColumn,
                                            mappedRow,
                                        ) * totals[cell]
                                        bitCounts[bitIndex] += counts[cell]
                                    }
                                }
                                if (bitCounts.minOrNull() == null || bitCounts.minOrNull()!! < 2) continue
                                for (polarity in intArrayOf(1, -1)) {
                                    val bytes = ByteArray(payloadBytes)
                                    var confidence = 0.0
                                    for (bitIndex in 0 until payloadBits) {
                                        val value = polarity * bitTotals[bitIndex]
                                        if (value > 0) {
                                            bytes[bitIndex / 8] = (
                                                bytes[bitIndex / 8].toInt() or
                                                    (1 shl (7 - bitIndex % 8))
                                                ).toByte()
                                        }
                                        confidence += (
                                            abs(value) / bitCounts[bitIndex] /
                                                (2.0 * robustPayloadStrength)
                                            ).coerceIn(0.0, 1.0)
                                    }
                                    decodePayload(bytes, confidence / payloadBits)?.let { return it }
                                }
                        }
                    }
                }
            }
        }
        return null
    }

    private fun nearbyPayloadShifts(robustShift: Int): IntArray =
        intArrayOf(-1, 0, 1, 7, 8, 9)
            .map { Math.floorMod(robustShift + it, robustPayloadPeriod) }
            .distinct()
            .toIntArray()

    private fun mapQuarterTurn(column: Int, row: Int, quarterTurns: Int): Pair<Int, Int> =
        when (quarterTurns) {
            1 -> row to -column
            2 -> -column to -row
            3 -> -row to column
            else -> column to row
        }

    private fun decodePayload(bytes: ByteArray, confidence: Double): RecoveredPayload? {
        if (bytes[0] != 0xD2.toByte() || bytes[1] != 0xA7.toByte() || bytes[2].toInt() != 2) return null
        val expectedCrc = ((bytes[11].toInt() and 0xff) shl 8) or (bytes[12].toInt() and 0xff)
        if (crc16(bytes, 11) != expectedCrc) return null
        return RecoveredPayload(
            ownerReference = hexReference(readUInt32(bytes, 3)),
            photoReference = hexReference(readUInt32(bytes, 7)),
            confidence = confidence,
        )
    }

    private fun inspectPayload(bitmap: Bitmap): RecoveredPayload? {
        val totals = DoubleArray(payloadBits)
        val positiveVotes = IntArray(payloadBits)
        val counts = IntArray(payloadBits)
        val row = IntArray(bitmap.width)
        var sample = 0
        for (y in 2 until bitmap.height step stride) {
            bitmap.getPixels(row, 0, bitmap.width, 0, y, bitmap.width, 1)
            for (x in 0 until bitmap.width - 1 step stride) {
                val bitIndex = sample % payloadBits
                val value = sign(x / stride + 911, y / stride + 353) * (luminance(row[x]) - luminance(row[x + 1]))
                totals[bitIndex] += value
                if (value >= 0) positiveVotes[bitIndex]++
                counts[bitIndex]++
                sample++
            }
        }
        if (counts.minOrNull() == null || counts.minOrNull()!! < 2) return null
        val bytes = ByteArray(payloadBytes)
        var confidence = 0.0
        for (bitIndex in 0 until payloadBits) {
            if (totals[bitIndex] > 0) {
                bytes[bitIndex / 8] =
                    (bytes[bitIndex / 8].toInt() or (1 shl (7 - bitIndex % 8))).toByte()
            }
            confidence += maxOf(positiveVotes[bitIndex], counts[bitIndex] - positiveVotes[bitIndex]).toDouble() / counts[bitIndex]
        }
        return decodePayload(bytes, confidence / payloadBits)
    }
}

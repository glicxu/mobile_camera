package com.dalicamera.dali_camera_platform

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyInfo
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONObject
import java.io.File
import java.nio.ByteBuffer
import java.security.KeyFactory
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.MessageDigest
import java.security.PrivateKey
import java.security.Signature
import java.security.spec.ECGenParameterSpec
import java.security.spec.X509EncodedKeySpec

internal object SignedWatermark {
    private const val schema = "dali.signed-watermark.v1"
    private const val algorithm = "SHA256withECDSA"
    private const val keyStoreName = "AndroidKeyStore"
    private const val aliasPrefix = "dali.watermark.ec.v1."

    data class Inspection(
        val status: String,
        val ownerReference: String,
        val photoReference: String,
        val keyFingerprint: String,
        val imageSha256: String,
        val keyProtection: String,
        val signatureValid: Boolean,
        val imageDigestMatches: Boolean,
        val metadataMatches: Boolean?,
    ) {
        fun addTo(json: JSONObject) {
            json.put("signedWatermarkStatus", status)
            json.put("signedWatermarkAlgorithm", algorithm)
            json.put("signedWatermarkOwnerReference", ownerReference)
            json.put("signedWatermarkPhotoReference", photoReference)
            json.put("signedWatermarkKeyFingerprint", keyFingerprint)
            json.put("signedWatermarkImageSha256", imageSha256)
            json.put("signedWatermarkKeyProtection", keyProtection)
            json.put("signedWatermarkSignatureValid", signatureValid)
            json.put("signedWatermarkImageDigestMatches", imageDigestMatches)
            metadataMatches?.let { json.put("signedWatermarkMetadataMatches", it) }
        }
    }

    private data class Identity(
        val ownerReference: String,
        val photoReference: String,
        val ownerSha256: String,
        val photoSha256: String,
        val identitySha256: String,
    )

    fun sign(file: File, metadataIdentity: String?, captureDebug: String?, createKey: Boolean): String? {
        val identity = identity(metadataIdentity) ?: return null
        val alias = aliasPrefix + identity.ownerSha256
        val keyStore = KeyStore.getInstance(keyStoreName).apply { load(null) }
        if (!keyStore.containsAlias(alias) && !createKey) return null
        if (!keyStore.containsAlias(alias)) {
            KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, keyStoreName).apply {
                initialize(
                    KeyGenParameterSpec.Builder(
                        alias,
                        KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY,
                    )
                        .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
                        .setDigests(KeyProperties.DIGEST_SHA256)
                        .build(),
                )
                generateKeyPair()
            }
        }
        val privateKey = keyStore.getKey(alias, null) as PrivateKey
        val publicKey = keyStore.getCertificate(alias).publicKey
        val image = imageDigest(file.path)
        val manifest = JSONObject()
            .put("v", 1)
            .put("owner", identity.ownerReference)
            .put("photo", identity.photoReference)
            .put("ownerSha256", identity.ownerSha256)
            .put("photoSha256", identity.photoSha256)
            .put("identitySha256", identity.identitySha256)
            .put("width", image.width)
            .put("height", image.height)
            .put("imageSha256", image.sha256)
        val signature = Signature.getInstance(algorithm).apply {
            initSign(privateKey)
            update(canonical(manifest))
        }.sign()
        val publicBytes = publicKey.encoded
        val wrapper = JSONObject()
            .put("schema", schema)
            .put("algorithm", algorithm)
            .put("manifest", manifest)
            .put("publicKey", encode(publicBytes))
            .put("keyFingerprint", fingerprint(publicBytes))
            .put("signature", encode(signature))
            .put("keyProtection", keyProtection(privateKey))
        parseObject(captureDebug)?.let { wrapper.put("captureDebug", it) }
        return wrapper.toString()
    }

    fun captureDebug(rawComment: String?): String? {
        if (rawComment == null) return null
        val wrapper = parseObject(rawComment)
        return if (wrapper?.optString("schema") == schema) {
            wrapper.optJSONObject("captureDebug")?.toString()
        } else {
            rawComment
        }
    }

    fun inspect(path: String, rawComment: String?, metadataIdentity: String?): Inspection? {
        val image = imageDigest(path)
        return inspect(image, rawComment, metadataIdentity)
    }

    fun inspect(bytes: ByteArray, rawComment: String?, metadataIdentity: String?): Inspection? {
        val image = imageDigest(bytes)
        return inspect(image, rawComment, metadataIdentity)
    }

    private fun inspect(image: ImageDigest, rawComment: String?, metadataIdentity: String?): Inspection? {
        val wrapper = parseObject(rawComment)?.takeIf { it.optString("schema") == schema } ?: return null
        val manifest = wrapper.optJSONObject("manifest") ?: return null
        val ownerReference = manifest.optString("owner")
        val photoReference = manifest.optString("photo")
        val expectedDigest = manifest.optString("imageSha256")
        val publicBytes = runCatching { decode(wrapper.getString("publicKey")) }.getOrNull() ?: return null
        val signatureBytes = runCatching { decode(wrapper.getString("signature")) }.getOrNull() ?: return null
        val publicKey = runCatching {
            KeyFactory.getInstance("EC").generatePublic(X509EncodedKeySpec(publicBytes))
        }.getOrNull() ?: return null
        val signatureValid = runCatching {
            Signature.getInstance(algorithm).run {
                initVerify(publicKey)
                update(canonical(manifest))
                verify(signatureBytes)
            }
        }.getOrDefault(false)
        val imageMatches =
            manifest.optInt("width") == image.width &&
                manifest.optInt("height") == image.height &&
                expectedDigest == image.sha256
        val metadata = identity(metadataIdentity)
        val metadataMatches = metadata?.let {
            it.ownerReference == ownerReference &&
                it.photoReference == photoReference &&
                it.ownerSha256 == manifest.optString("ownerSha256") &&
                it.photoSha256 == manifest.optString("photoSha256") &&
                it.identitySha256 == manifest.optString("identitySha256")
        }
        val status = when {
            !signatureValid -> "invalid_signature"
            !imageMatches -> "image_modified"
            metadataMatches == false -> "metadata_conflict"
            metadataMatches == null -> "metadata_missing"
            else -> "verified"
        }
        return Inspection(
            status = status,
            ownerReference = ownerReference,
            photoReference = photoReference,
            keyFingerprint = fingerprint(publicBytes),
            imageSha256 = expectedDigest,
            keyProtection = wrapper.optString("keyProtection", "unknown"),
            signatureValid = signatureValid,
            imageDigestMatches = imageMatches,
            metadataMatches = metadataMatches,
        )
    }

    private data class ImageDigest(val width: Int, val height: Int, val sha256: String)

    private fun imageDigest(path: String): ImageDigest {
        val bitmap = BitmapFactory.decodeFile(path) ?: error("Cannot decode signed image")
        return try { imageDigest(bitmap) } finally { bitmap.recycle() }
    }

    private fun imageDigest(bytes: ByteArray): ImageDigest {
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: error("Cannot decode signed image")
        return try { imageDigest(bitmap) } finally { bitmap.recycle() }
    }

    private fun imageDigest(bitmap: Bitmap): ImageDigest {
        val digest = MessageDigest.getInstance("SHA-256")
        digest.update(ByteBuffer.allocate(8).putInt(bitmap.width).putInt(bitmap.height).array())
        val row = IntArray(bitmap.width)
        val bytes = ByteArray(bitmap.width * 4)
        for (y in 0 until bitmap.height) {
            bitmap.getPixels(row, 0, bitmap.width, 0, y, bitmap.width, 1)
            var offset = 0
            for (color in row) {
                bytes[offset++] = (color shr 24).toByte()
                bytes[offset++] = (color shr 16).toByte()
                bytes[offset++] = (color shr 8).toByte()
                bytes[offset++] = color.toByte()
            }
            digest.update(bytes)
        }
        return ImageDigest(bitmap.width, bitmap.height, digest.digest().toHex())
    }

    private fun identity(value: String?): Identity? {
        if (value == null || !value.startsWith("DALI2-")) return null
        return runCatching {
            val json = JSONObject(String(decode(value.substring(6)), Charsets.UTF_8))
            if (json.optInt("v") != 2) return null
            val owner = json.getString("owner").takeIf { it.isNotEmpty() } ?: return null
            val photo = json.getString("photo").takeIf { it.isNotEmpty() } ?: return null
            Identity(
                ownerReference = HiddenWatermark.reference(owner),
                photoReference = HiddenWatermark.reference(photo),
                ownerSha256 = sha256(owner),
                photoSha256 = sha256(photo),
                identitySha256 = sha256(value),
            )
        }.getOrNull()
    }

    private fun canonical(manifest: JSONObject): ByteArray = buildString {
        append("DALI-SIGNED-WATERMARK-V1\n")
        append("owner=").append(manifest.getString("owner")).append('\n')
        append("photo=").append(manifest.getString("photo")).append('\n')
        append("ownerSha256=").append(manifest.getString("ownerSha256")).append('\n')
        append("photoSha256=").append(manifest.getString("photoSha256")).append('\n')
        append("identitySha256=").append(manifest.getString("identitySha256")).append('\n')
        append("width=").append(manifest.getInt("width")).append('\n')
        append("height=").append(manifest.getInt("height")).append('\n')
        append("imageSha256=").append(manifest.getString("imageSha256")).append('\n')
    }.toByteArray(Charsets.UTF_8)

    private fun keyProtection(privateKey: java.security.Key): String = runCatching {
        val info = KeyFactory.getInstance(privateKey.algorithm, keyStoreName)
            .getKeySpec(privateKey, KeyInfo::class.java)
        val hardwareBacked = if (Build.VERSION.SDK_INT >= 31) {
            info.securityLevel != KeyProperties.SECURITY_LEVEL_SOFTWARE
        } else {
            @Suppress("DEPRECATION")
            info.isInsideSecureHardware
        }
        if (hardwareBacked) "hardware-backed Android Keystore" else "Android Keystore"
    }.getOrDefault("Android Keystore")

    private fun fingerprint(publicKey: ByteArray): String =
        MessageDigest.getInstance("SHA-256").digest(publicKey).copyOfRange(0, 16).toHex()

    private fun sha256(value: String): String =
        MessageDigest.getInstance("SHA-256").digest(value.toByteArray(Charsets.UTF_8)).toHex()

    private fun parseObject(value: String?): JSONObject? =
        value?.let { runCatching { JSONObject(it) }.getOrNull() }

    private fun encode(value: ByteArray): String =
        Base64.encodeToString(value, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)

    private fun decode(value: String): ByteArray =
        Base64.decode(value, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)

    private fun ByteArray.toHex(): String = joinToString("") { "%02x".format(it.toInt() and 0xff) }
}

package com.dalicamera.dali_camera_platform

import android.Manifest
import android.app.Activity
import android.content.*
import android.content.pm.PackageManager
import android.graphics.*
import android.hardware.*
import android.net.Uri
import android.os.*
import android.provider.MediaStore
import android.provider.Settings
import android.util.Size
import android.view.View
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.exifinterface.media.ExifInterface
import androidx.lifecycle.LifecycleOwner
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.*
import com.google.mlkit.vision.pose.*
import com.google.mlkit.vision.pose.defaults.PoseDetectorOptions
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.*
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.platform.*
import org.json.*
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors
import kotlin.math.*

class DaliCameraPlatformPlugin : FlutterPlugin, ActivityAware, CameraHostApi,
    PluginRegistry.RequestPermissionsResultListener, PluginRegistry.ActivityResultListener, SensorEventListener {
    private lateinit var context: Context
    private lateinit var events: CameraEvents
    private var activity: Activity? = null
    private var binding: ActivityPluginBinding? = null
    private var provider: ProcessCameraProvider? = null
    private var previewView: PreviewView? = null
    private var camera: androidx.camera.core.Camera? = null
    private var captureUseCase: ImageCapture? = null
    private var front = false
    private var active = false
    private var generation = 0L
    private var config = ""
    private var aspect = 0.75
    private var capturing = false
    private var pendingStart: ((Result<CameraSnapshot>) -> Unit)? = null
    private var pendingPicker: ((Result<PhotoHandle?>) -> Unit)? = null
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var lastAnalysis = 0L
    private var roll = 0.0
    private var motion = 0.0
    private var lastGravity: FloatArray? = null
    private val faceDetector = FaceDetection.getClient(FaceDetectorOptions.Builder()
        .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_FAST)
        .setLandmarkMode(FaceDetectorOptions.LANDMARK_MODE_ALL).enableTracking().build())
    private val poseDetector = PoseDetection.getClient(PoseDetectorOptions.Builder()
        .setDetectorMode(PoseDetectorOptions.STREAM_MODE).build())

    override fun onAttachedToEngine(b: FlutterPlugin.FlutterPluginBinding) {
        context = b.applicationContext; events = CameraEvents(b.binaryMessenger)
        CameraHostApi.setUp(b.binaryMessenger, this)
        b.platformViewRegistry.registerViewFactory("dali/camera", object : PlatformViewFactory(null) {
            override fun create(ctx: Context, id: Int, args: Any?): PlatformView {
                val view = PreviewView(ctx).apply { scaleType = PreviewView.ScaleType.FIT_CENTER
                    implementationMode = PreviewView.ImplementationMode.COMPATIBLE }
                previewView = view
                if (active) start(front) {}
                return object : PlatformView {
                    override fun getView(): View = view
                    override fun dispose() { if (previewView === view) previewView = null }
                }
            }
        })
    }
    override fun onDetachedFromEngine(b: FlutterPlugin.FlutterPluginBinding) {
        stop(); CameraHostApi.setUp(b.binaryMessenger, null)
        faceDetector.close(); poseDetector.close(); executor.shutdown()
    }
    override fun onAttachedToActivity(b: ActivityPluginBinding) {
        binding = b; activity = b.activity
        b.addRequestPermissionsResultListener(this); b.addActivityResultListener(this)
    }
    override fun onDetachedFromActivityForConfigChanges() { detach() }
    override fun onReattachedToActivityForConfigChanges(b: ActivityPluginBinding) { onAttachedToActivity(b) }
    override fun onDetachedFromActivity() { detach() }
    private fun detach() {
        stop(); binding?.removeRequestPermissionsResultListener(this); binding?.removeActivityResultListener(this)
        pendingStart?.invoke(Result.failure(IllegalStateException("Activity detached"))); pendingStart = null
        pendingPicker?.invoke(Result.failure(IllegalStateException("Picker interrupted"))); pendingPicker = null
        binding = null; activity = null
    }
    override fun start(front: Boolean, callback: (Result<CameraSnapshot>) -> Unit) {
        val host = activity ?: return callback(Result.failure(IllegalStateException("No activity")))
        this.front = front
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            pendingStart = callback; host.requestPermissions(arrayOf(Manifest.permission.CAMERA), 701); return
        }
        val epoch = ++generation
        val future = ProcessCameraProvider.getInstance(context)
        future.addListener({
            try {
                if (epoch != generation) throw IllegalStateException("Session superseded")
                provider = future.get(); provider!!.unbindAll()
                val rotation = previewView?.display?.rotation ?: android.view.Surface.ROTATION_0
                val preview = Preview.Builder().setTargetAspectRatio(AspectRatio.RATIO_4_3).setTargetRotation(rotation).build()
                previewView?.let { preview.setSurfaceProvider(it.surfaceProvider) }
                captureUseCase = ImageCapture.Builder().setTargetAspectRatio(AspectRatio.RATIO_4_3)
                    .setTargetRotation(rotation).setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY).build()
                val analysis = ImageAnalysis.Builder().setTargetResolution(Size(640, 480)).setTargetRotation(rotation)
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST).build()
                analysis.setAnalyzer(executor) { image -> analyze(image, epoch) }
                camera = provider!!.bindToLifecycle(host as LifecycleOwner,
                    if (front) CameraSelector.DEFAULT_FRONT_CAMERA else CameraSelector.DEFAULT_BACK_CAMERA,
                    preview, captureUseCase, analysis)
                active = true; config = UUID.randomUUID().toString()
                val sensors = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
                sensors.getDefaultSensor(Sensor.TYPE_GRAVITY)?.let { sensors.registerListener(this, it, SensorManager.SENSOR_DELAY_UI) }
                callback(Result.success(snapshot())); events.state(snapshot()) {}
            } catch (e: Exception) { active = false; callback(Result.failure(e)) }
        }, ContextCompat.getMainExecutor(context))
    }
    override fun stop() {
        generation++; active = false; provider?.unbindAll(); camera = null; captureUseCase = null
        (context.getSystemService(Context.SENSOR_SERVICE) as SensorManager).unregisterListener(this)
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, results: IntArray): Boolean {
        if (requestCode != 701) return false
        val completion = pendingStart; pendingStart = null
        if (results.firstOrNull() == PackageManager.PERMISSION_GRANTED) completion?.let { start(front, it) }
        else completion?.invoke(Result.failure(SecurityException("Camera permission denied. Enable Camera in Settings.")))
        return true
    }
    private fun snapshot(): CameraSnapshot {
        val exposure = camera?.cameraInfo?.exposureState
        val step = exposure?.exposureCompensationStep?.toDouble() ?: 0.0
        return CameraSnapshot(active, front, config, aspect,
            (exposure?.exposureCompensationRange?.lower ?: 0) * step,
            (exposure?.exposureCompensationRange?.upper ?: 0) * step,
            (exposure?.exposureCompensationIndex ?: 0) * step, false, false)
    }
    override fun setControls(configurationId: String, ev: Double, locked: Boolean): CameraSnapshot {
        check(config == configurationId && active) { "Camera changed; refresh controls" }
        check(!locked) { "Focus/exposure lock unavailable" }
        val cam = camera!!; val state = cam.cameraInfo.exposureState
        if (state.isExposureCompensationSupported) cam.cameraControl.setExposureCompensationIndex(
            (ev / state.exposureCompensationStep.toDouble()).roundToInt().coerceIn(state.exposureCompensationRange.lower, state.exposureCompensationRange.upper))
        return snapshot()
    }
    @androidx.annotation.OptIn(ExperimentalGetImage::class)
    private fun analyze(proxy: ImageProxy, epoch: Long) {
        val now = SystemClock.elapsedRealtime()
        if (!active || epoch != generation || now - lastAnalysis < 150) { proxy.close(); return }
        val media = proxy.image ?: run { proxy.close(); return }
        lastAnalysis = now
        val rotation = proxy.imageInfo.rotationDegrees
        val width = if (rotation % 180 == 0) proxy.width else proxy.height
        val height = if (rotation % 180 == 0) proxy.height else proxy.width
        if (aspect != width.toDouble() / height) android.util.Log.i("DaliCamera", "Analysis image ${width}x${height}, rotation=$rotation, preview=${previewView?.width}x${previewView?.height}")
        aspect = width.toDouble() / height
        val image = InputImage.fromMediaImage(media, rotation)
        val faceTask = faceDetector.process(image); val poseTask = poseDetector.process(image)
        com.google.android.gms.tasks.Tasks.whenAllComplete(faceTask, poseTask).addOnCompleteListener(executor) {
            try {
                if (epoch != generation || !active) return@addOnCompleteListener
                fun rect(box: Rect, label: String): JSONObject {
                    val left = (box.left.toDouble() / width).coerceIn(0.0, 1.0)
                    val right = (box.right.toDouble() / width).coerceIn(left, 1.0)
                    val top = (box.top.toDouble() / height).coerceIn(0.0, 1.0)
                    val bottom = (box.bottom.toDouble() / height).coerceIn(top, 1.0)
                    return JSONObject().put("x", if (front) 1 - right else left).put("y", top)
                        .put("width", right - left).put("height", bottom - top).put("confidence", 0.8).put("label", label)
                }
                val faces = if (faceTask.isSuccessful) faceTask.result else emptyList()
                val landmarks = if (poseTask.isSuccessful) poseTask.result.allPoseLandmarks.filter { it.inFrameLikelihood > 0.65 } else emptyList()
                val people = JSONArray()
                if (landmarks.size >= 6) people.put(rect(Rect(landmarks.minOf { it.position.x }.toInt(), landmarks.minOf { it.position.y }.toInt(),
                    landmarks.maxOf { it.position.x }.toInt(), landmarks.maxOf { it.position.y }.toInt()), "pose extent"))
                val faceBoxes = JSONArray(); faces.forEach { faceBoxes.put(rect(it.boundingBox, "face")) }
                val y = proxy.planes[0]; val buf = y.buffer.duplicate(); var sum = 0.0; var count = 0
                for (row in 0 until proxy.height step 16) for (col in 0 until proxy.width step 16) {
                    val index = row * y.rowStride + col * y.pixelStride
                    if (index < buf.limit()) { sum += (buf.get(index).toInt() and 255) / 255.0; count++ }
                }
                val payload = JSONObject().put("configurationId", config).put("aspectRatio", aspect).put("people", people).put("faces", faceBoxes)
                    .put("roll", roll).put("motion", motion).put("stable", motion < 0.08)
                    .put("backgroundLuminance", if (count > 0) sum / count else JSONObject.NULL)
                    .put("peopleStatus", if (poseTask.isSuccessful) "valid" else "unavailable")
                    .put("faceStatus", if (faceTask.isSuccessful) "valid" else "unavailable")
                    .put("horizonStatus", "unsupported").put("openAreaStatus", "unsupported").put("timestamp", System.currentTimeMillis())
                main.post { if (epoch == generation && active) events.analysis(payload.toString()) {} }
            } finally { proxy.close() }
        }
    }
    override fun onSensorChanged(event: SensorEvent) {
        val values = event.values
        val adjustment = when (previewView?.display?.rotation ?: 0) { 1 -> 90; 2 -> 180; 3 -> -90; else -> 0 }
        var degrees = atan2(-values[0].toDouble(), values[1].toDouble()) * 180 / PI - adjustment
        while (degrees > 180) degrees -= 360
        while (degrees < -180) degrees += 360
        roll = if (hypot(values[0].toDouble(), values[1].toDouble()) < 1.5) 0.0 else if (front) -degrees else degrees
        lastGravity?.let { old -> motion = motion * 0.7 + sqrt(values.indices.sumOf { (values[it] - old[it]).toDouble().pow(2) }) / 9.81 * 0.3 }
        lastGravity = values.clone()
    }
    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
    private val pendingFile get() = File(context.filesDir, "pending.json")
    private fun photoFile() = File(context.filesDir, "photo-${UUID.randomUUID()}.jpg")
    private fun retain(photo: PhotoHandle) {
        val atomic = android.util.AtomicFile(pendingFile); val stream = atomic.startWrite()
        try { stream.write(JSONObject().put("path", photo.path).put("id", photo.id).toString().toByteArray()); atomic.finishWrite(stream) }
        catch (e: Exception) { atomic.failWrite(stream); throw e }
    }
    override fun recover(): PhotoHandle? {
        if (!pendingFile.exists()) return null
        val json = JSONObject(pendingFile.readText()); val path = json.getString("path")
        check(File(path).exists()) { "Recovery original missing" }
        return PhotoHandle(path, json.getString("id"), true)
    }
    override fun capture(callback: (Result<PhotoHandle>) -> Unit) {
        if (capturing || recover() != null) return callback(Result.failure(IllegalStateException("Save or discard the previous original first")))
        val capture = captureUseCase ?: return callback(Result.failure(IllegalStateException("Camera not ready")))
        capturing = true; val file = photoFile()
        val metadata = ImageCapture.Metadata().apply { isReversedHorizontal = front }
        capture.takePicture(ImageCapture.OutputFileOptions.Builder(file).setMetadata(metadata).build(), ContextCompat.getMainExecutor(context), object : ImageCapture.OnImageSavedCallback {
            override fun onImageSaved(result: ImageCapture.OutputFileResults) {
                capturing = false
                try {
                    val photo = PhotoHandle(file.absolutePath, file.nameWithoutExtension, true)
                    try { retain(photo) } catch (e: Exception) { events.error("recovery", "Original captured but relaunch recovery unavailable: ${e.message}") {} }
                    callback(Result.success(photo))
                }
                catch (e: Exception) { callback(Result.failure(e)) }
            }
            override fun onError(e: ImageCaptureException) { capturing = false; callback(Result.failure(e)) }
        })
    }
    override fun save(photo: PhotoHandle, callback: (Result<Unit>) -> Unit) {
        executor.execute {
            var inserted: Uri? = null
            try {
                val name = "Dali-${photo.id}.jpg"; val collection = MediaStore.Images.Media.EXTERNAL_CONTENT_URI
                val existing = context.contentResolver.query(collection, arrayOf(MediaStore.Images.Media._ID),
                    "${MediaStore.Images.Media.DISPLAY_NAME} = ?", arrayOf(name), null)?.use { cursor ->
                    if (cursor.moveToFirst()) ContentUris.withAppendedId(collection, cursor.getLong(0)) else null }
                val values = ContentValues().apply {
                    put(MediaStore.Images.Media.DISPLAY_NAME, name); put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
                    if (Build.VERSION.SDK_INT >= 29) { put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/Dali"); put(MediaStore.Images.Media.IS_PENDING, 1) }
                }
                val uri = existing ?: (context.contentResolver.insert(collection, values) ?: error("Gallery insert failed")).also { inserted = it }
                context.contentResolver.openOutputStream(uri, "w")?.use { output -> File(photo.path).inputStream().use { it.copyTo(output) } } ?: error("Cannot write photo")
                if (Build.VERSION.SDK_INT >= 29) context.contentResolver.update(uri, ContentValues().apply { put(MediaStore.Images.Media.IS_PENDING, 0) }, null, null)
                if (recover()?.id == photo.id) check(pendingFile.delete()) { "Saved, but recovery cleanup failed" }
                main.post { callback(Result.success(Unit)) }
            } catch (e: Exception) { inserted?.let { context.contentResolver.delete(it, null, null) }; main.post { callback(Result.failure(e)) } }
        }
    }
    override fun discard(photo: PhotoHandle) {
        if (recover()?.id == photo.id) { check(pendingFile.delete()) { "Cannot remove recovery manifest" }; File(photo.path).delete() }
    }
    override fun share(photo: PhotoHandle, callback: (Result<Unit>) -> Unit) {
        try {
            val uri = FileProvider.getUriForFile(context, "${context.packageName}.dali.files", File(photo.path))
            activity!!.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply {
                type = "image/jpeg"; putExtra(Intent.EXTRA_STREAM, uri); addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION); clipData = ClipData.newRawUri("Dali photo", uri)
            }, "Share photo")); callback(Result.success(Unit))
        } catch (e: Exception) { callback(Result.failure(e)) }
    }
    override fun pickPhoto(callback: (Result<PhotoHandle?>) -> Unit) {
        if (pendingPicker != null) return callback(Result.failure(IllegalStateException("Picker busy")))
        pendingPicker = callback; activity!!.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply { type = "image/*"; addCategory(Intent.CATEGORY_OPENABLE) }, 702)
    }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != 702) return false
        val completion = pendingPicker; pendingPicker = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) { completion?.invoke(Result.success(null)); return true }
        try {
            val file = photoFile(); context.contentResolver.openInputStream(data.data!!)?.use { input -> file.outputStream().use { input.copyTo(it) } } ?: error("Cannot read selected photo")
            completion?.invoke(Result.success(PhotoHandle(file.path, file.nameWithoutExtension, false)))
        } catch (e: Exception) { completion?.invoke(Result.failure(e)) }
        return true
    }
    override fun render(original: PhotoHandle, rotationDegrees: Double, crop: Boolean, strength: Double, callback: (Result<PhotoHandle>) -> Unit) {
        executor.execute {
            try {
                val bitmap = BitmapFactory.decodeFile(original.path) ?: error("Cannot decode photo")
                val orientation = ExifInterface(original.path).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
                val matrix = Matrix()
                when (orientation) {
                    2 -> matrix.setScale(-1f, 1f); 3 -> matrix.setRotate(180f); 4 -> matrix.setScale(1f, -1f)
                    5 -> { matrix.setRotate(90f); matrix.postScale(-1f, 1f) }; 6 -> matrix.setRotate(90f)
                    7 -> { matrix.setRotate(270f); matrix.postScale(-1f, 1f) }; 8 -> matrix.setRotate(270f)
                }
                matrix.postRotate(rotationDegrees.toFloat())
                var output = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
                if (crop) { val x = (output.width * 0.08).toInt(); val y = (output.height * 0.08).toInt(); output = Bitmap.createBitmap(output, x, y, output.width - 2*x, output.height - 2*y) }
                if (strength > 0) {
                    val processed = Bitmap.createBitmap(output.width, output.height, Bitmap.Config.ARGB_8888)
                    val paint = Paint().apply { colorFilter = ColorMatrixColorFilter(ColorMatrix().apply { setSaturation(1f + strength.toFloat() * 0.12f) }) }
                    Canvas(processed).drawBitmap(output, 0f, 0f, paint); output = processed
                }
                val file = photoFile(); file.outputStream().use { check(output.compress(Bitmap.CompressFormat.JPEG, 95, it)) }
                main.post { callback(Result.success(PhotoHandle(file.path, file.nameWithoutExtension, false))) }
            } catch (e: Exception) { main.post { callback(Result.failure(e)) } }
        }
    }
    override fun openSettings() { activity!!.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}"))) }
    override fun setVoiceEnabled(enabled: Boolean, callback: (Result<Boolean>) -> Unit) { callback(Result.success(false)) }
}

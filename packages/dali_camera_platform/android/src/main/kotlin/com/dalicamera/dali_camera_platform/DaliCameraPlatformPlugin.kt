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
import android.provider.DocumentsContract
import android.speech.*
import android.util.Size
import android.view.View
import android.view.OrientationEventListener
import android.widget.FrameLayout
import androidx.camera.core.*
import androidx.camera.camera2.interop.*
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CaptureRequest
import android.hardware.camera2.CaptureResult
import android.hardware.camera2.TotalCaptureResult
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

@androidx.annotation.OptIn(ExperimentalCamera2Interop::class)
class DaliCameraPlatformPlugin : FlutterPlugin, ActivityAware, CameraHostApi,
    PluginRegistry.RequestPermissionsResultListener, PluginRegistry.ActivityResultListener, SensorEventListener {
    private lateinit var context: Context
    private lateinit var events: CameraEvents
    private var activity: Activity? = null
    private var binding: ActivityPluginBinding? = null
    private var provider: ProcessCameraProvider? = null
    private var previewView: PreviewView? = null
    private var depthView: DepthPreviewView? = null
    private val depthExecutor = Executors.newSingleThreadExecutor()
    private var depthPending = false
    private var lastDepth = 0L
    private var camera: androidx.camera.core.Camera? = null
    private var captureUseCase: ImageCapture? = null
    private var analysisUseCase: ImageAnalysis? = null
    private var previewUseCase: Preview? = null
    private var orientationListener: OrientationEventListener? = null
    private var displayRotation = 0
    private var front = false
    private var active = false
    private var generation = 0L
    private var config = ""
    private var aspect = 0.75
    private var capturing = false
    @Volatile private var focusDistance: Float? = null
    private var lockedState = false
    private var manualExposure = false
    @Volatile private var meteredISO = 100.0
    @Volatile private var meteredSeconds = 1.0 / 125.0
    @Volatile private var meteredAperture: Double? = null
    private var pendingStart: ((Result<CameraSnapshot>) -> Unit)? = null
    private var pendingPicker: ((Result<PhotoHandle?>) -> Unit)? = null
    private var pendingBatchPicker: ((Result<PhotoImport>) -> Unit)? = null
    private var pickerIsFolder = false
    private var pendingSave: Pair<PhotoHandle, (Result<Unit>) -> Unit>? = null
    private var speech: SpeechRecognizer? = null
    private var listening = false
    private var customVoicePhrase = ""
    private var lastVoice = 0L
    private var speechEpoch = 0L
    private val executor = Executors.newSingleThreadExecutor()
    private val stillProcessor = StillPhotoProcessor()
    private val main = Handler(Looper.getMainLooper())
    private var lastAnalysis = 0L
    private var lastState = 0L
    private var roll = 0.0
    private var motion = 0.0
    private var lastGravity: FloatArray? = null
    private var motionAvailable = false
    private val faceDetector = FaceDetection.getClient(FaceDetectorOptions.Builder()
        .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_FAST)
        .setLandmarkMode(FaceDetectorOptions.LANDMARK_MODE_ALL).enableTracking().build())
    private val poseDetector = PoseDetection.getClient(PoseDetectorOptions.Builder()
        .setDetectorMode(PoseDetectorOptions.STREAM_MODE).build())

    override fun onAttachedToEngine(b: FlutterPlugin.FlutterPluginBinding) {
        context = b.applicationContext; events = CameraEvents(b.binaryMessenger)
        CameraHostApi.setUp(b.binaryMessenger, this)
        orientationListener = object : OrientationEventListener(context) {
            override fun onOrientationChanged(orientation: Int) {
                val current = previewView?.display?.rotation ?: return
                if (!active || current == displayRotation) return
                displayRotation = current
                captureUseCase?.targetRotation = current
                analysisUseCase?.targetRotation = current
                previewUseCase?.targetRotation = current
            }
        }
        b.platformViewRegistry.registerViewFactory("dali/camera", object : PlatformViewFactory(null) {
            override fun create(ctx: Context, id: Int, args: Any?): PlatformView {
                val view = PreviewView(ctx).apply { scaleType = PreviewView.ScaleType.FIT_CENTER
                    implementationMode = PreviewView.ImplementationMode.COMPATIBLE }
                previewView = view
                val overlay = DepthPreviewView(ctx); depthView = overlay
                val container = FrameLayout(ctx).apply { addView(view, FrameLayout.LayoutParams(-1, -1)); addView(overlay, FrameLayout.LayoutParams(-1, -1)) }
                previewUseCase?.setSurfaceProvider(view.surfaceProvider)
                return object : PlatformView {
                    override fun getView(): View = container
                    override fun dispose() { if (previewView === view) { previewView = null; depthView = null }; overlay.replace(null) }
                }
            }
        })
    }
    override fun onDetachedFromEngine(b: FlutterPlugin.FlutterPluginBinding) {
        stop(); CameraHostApi.setUp(b.binaryMessenger, null)
        faceDetector.close(); poseDetector.close(); stillProcessor.close(); executor.shutdown(); depthExecutor.shutdown()
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
        pendingBatchPicker?.invoke(Result.failure(IllegalStateException("Picker interrupted"))); pendingBatchPicker = null
        pendingSave?.second?.invoke(Result.failure(IllegalStateException("Save interrupted; original retained"))); pendingSave = null
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
                displayRotation = rotation
                focusDistance = null; lockedState = false; manualExposure = false
                val previewBuilder = Preview.Builder().setTargetAspectRatio(AspectRatio.RATIO_4_3).setTargetRotation(rotation)
                Camera2Interop.Extender(previewBuilder).setSessionCaptureCallback(object : CameraCaptureSession.CaptureCallback() {
                    override fun onCaptureCompleted(session: CameraCaptureSession, request: CaptureRequest, result: TotalCaptureResult) {
                        focusDistance = result.get(CaptureResult.LENS_FOCUS_DISTANCE)
                        result.get(CaptureResult.SENSOR_SENSITIVITY)?.let { meteredISO = it.toDouble() }
                        result.get(CaptureResult.SENSOR_EXPOSURE_TIME)?.let { meteredSeconds = it / 1e9 }
                        meteredAperture = result.get(CaptureResult.LENS_APERTURE)?.toDouble()
                    }
                })
                val preview = previewBuilder.build()
                previewUseCase = preview
                previewView?.let { preview.setSurfaceProvider(it.surfaceProvider) }
                captureUseCase = ImageCapture.Builder().setTargetAspectRatio(AspectRatio.RATIO_4_3)
                    .setTargetRotation(rotation).setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY).build()
                // Match preview's sensor-space ratio. A fixed 640x480 target is
                // interpreted after target rotation and selected a portrait sensor
                // buffer on the tablet, unlike the preview's landscape sensor buffer.
                val analysis = ImageAnalysis.Builder().setTargetAspectRatio(AspectRatio.RATIO_4_3).setTargetRotation(rotation)
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST).build()
                analysisUseCase = analysis
                analysis.setAnalyzer(executor) { image -> analyze(image, epoch) }
                camera = provider!!.bindToLifecycle(host as LifecycleOwner,
                    if (front) CameraSelector.DEFAULT_FRONT_CAMERA else CameraSelector.DEFAULT_BACK_CAMERA,
                    preview, captureUseCase, analysis)
                active = true; config = UUID.randomUUID().toString()
                orientationListener?.enable()
                val sensors = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
                val gravityAvailable = sensors.getDefaultSensor(Sensor.TYPE_GRAVITY)?.let { sensors.registerListener(this, it, SensorManager.SENSOR_DELAY_UI) } ?: false
                val accelerationAvailable = sensors.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION)?.let { sensors.registerListener(this, it, SensorManager.SENSOR_DELAY_UI) } ?: false
                motionAvailable = gravityAvailable && accelerationAvailable
                callback(Result.success(snapshot())); events.state(snapshot()) {}
            } catch (e: Exception) { active = false; callback(Result.failure(e)) }
        }, ContextCompat.getMainExecutor(context))
    }
    override fun stop() {
        generation++; active = false; provider?.unbindAll(); camera = null; captureUseCase = null
        analysisUseCase = null; previewUseCase = null; orientationListener?.disable()
        speechEpoch++; listening = false; speech?.destroy(); speech = null
        depthView?.level = 0; depthView?.replace(null)
        events.voiceState(false, "Paused") {}
        (context.getSystemService(Context.SENSOR_SERVICE) as SensorManager).unregisterListener(this)
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, results: IntArray): Boolean {
        if (requestCode == 704) {
            val request = pendingSave; pendingSave = null
            if (results.firstOrNull() == PackageManager.PERMISSION_GRANTED) request?.let { save(it.first, it.second) }
            else request?.second?.invoke(Result.failure(SecurityException("Photos storage permission denied; original retained")))
            return true
        }
        if (requestCode == 703) return true
        if (requestCode != 701) return false
        val completion = pendingStart; pendingStart = null
        if (results.firstOrNull() == PackageManager.PERMISSION_GRANTED) completion?.let { start(front, it) }
        else completion?.invoke(Result.failure(SecurityException("Camera permission denied. Enable Camera in Settings.")))
        return true
    }
    private fun snapshot(): CameraSnapshot {
        val exposure = camera?.cameraInfo?.exposureState
        val step = exposure?.exposureCompensationStep?.toDouble() ?: 0.0
        val camera2 = camera?.let { Camera2CameraInfo.from(it.cameraInfo) }
        val lockSupported = camera2?.getCameraCharacteristic(CameraCharacteristics.CONTROL_AE_LOCK_AVAILABLE) == true &&
            camera2.getCameraCharacteristic(CameraCharacteristics.CONTROL_AF_AVAILABLE_MODES)?.contains(CaptureRequest.CONTROL_AF_MODE_OFF) == true && focusDistance != null
        val zoom = camera?.cameraInfo?.zoomState?.value
        val manual = camera2?.getCameraCharacteristic(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES)?.contains(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES_MANUAL_SENSOR) == true
        val iso = if (manual) camera2?.getCameraCharacteristic(CameraCharacteristics.SENSOR_INFO_SENSITIVITY_RANGE) else null
        val time = if (manual) camera2?.getCameraCharacteristic(CameraCharacteristics.SENSOR_INFO_EXPOSURE_TIME_RANGE) else null
        return CameraSnapshot(active, front, config, aspect,
            (exposure?.exposureCompensationRange?.lower ?: 0) * step,
            (exposure?.exposureCompensationRange?.upper ?: 0) * step,
            (exposure?.exposureCompensationIndex ?: 0) * step, lockSupported, lockedState,
            minimumZoom = zoom?.minZoomRatio?.toDouble(), maximumZoom = zoom?.maxZoomRatio?.toDouble(), currentZoom = zoom?.zoomRatio?.toDouble(),
            supportsTap = camera2?.getCameraCharacteristic(CameraCharacteristics.CONTROL_MAX_REGIONS_AF)?.let { it > 0 } == true,
            minimumISO = iso?.lower?.toDouble(), maximumISO = iso?.upper?.toDouble(),
            minimumShutter = time?.lower?.let { it / 1e9 }, maximumShutter = time?.upper?.let { min(it / 1e9, 0.5) },
            currentISO = meteredISO, currentShutter = meteredSeconds, manualExposure = manualExposure,
            currentAperture = meteredAperture, exposureOffset = null)
    }
    override fun setControls(configurationId: String, ev: Double, locked: Boolean, callback: (Result<CameraSnapshot>) -> Unit) {
        try {
            check(config == configurationId && active && !manualExposure) { "Camera changed or manual exposure active; refresh controls" }
            check(!locked || snapshot().supportsLock) { "Focus/exposure lock unavailable" }
            val cam = camera!!; val state = cam.cameraInfo.exposureState
            val index = if (state.isExposureCompensationSupported) (ev / state.exposureCompensationStep.toDouble()).roundToInt()
                .coerceIn(state.exposureCompensationRange.lower, state.exposureCompensationRange.upper) else 0
            val options = CaptureRequestOptions.Builder().setCaptureRequestOption(CaptureRequest.CONTROL_AE_LOCK, locked)
                .setCaptureRequestOption(CaptureRequest.CONTROL_AF_MODE, if (locked) CaptureRequest.CONTROL_AF_MODE_OFF else CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
            if (locked) options.setCaptureRequestOption(CaptureRequest.LENS_FOCUS_DISTANCE, focusDistance!!)
            val controlFuture = Camera2CameraControl.from(cam.cameraControl).setCaptureRequestOptions(options.build())
            controlFuture.addListener({
                try {
                    controlFuture.get()
                    if (state.isExposureCompensationSupported) {
                        val exposureFuture = cam.cameraControl.setExposureCompensationIndex(index)
                        exposureFuture.addListener({
                            try { exposureFuture.get(); check(config == configurationId) { "Camera changed" }; lockedState = locked; callback(Result.success(snapshot())) }
                            catch (e: Exception) { callback(Result.failure(e)) }
                        }, ContextCompat.getMainExecutor(context))
                    } else { lockedState = locked; callback(Result.success(snapshot())) }
                } catch (e: Exception) { callback(Result.failure(e)) }
            }, ContextCompat.getMainExecutor(context))
        } catch (e: Exception) { callback(Result.failure(e)) }
    }
    @androidx.annotation.OptIn(ExperimentalGetImage::class)
    private fun analyze(proxy: ImageProxy, epoch: Long) {
        val now = SystemClock.elapsedRealtime()
        if (!active || epoch != generation || now - lastAnalysis < 150) { proxy.close(); return }
        val media = proxy.image ?: run { proxy.close(); return }
        lastAnalysis = now
        val rotation = proxy.imageInfo.rotationDegrees
        if (camera?.cameraInfo?.getSensorRotationDegrees(displayRotation) != rotation) { proxy.close(); return }
        val width = if (rotation % 180 == 0) proxy.width else proxy.height
        val height = if (rotation % 180 == 0) proxy.height else proxy.width
        if (aspect != width.toDouble() / height) android.util.Log.i("DaliCamera", "Analysis image ${width}x${height}, rotation=$rotation, preview=${previewView?.width}x${previewView?.height}")
        aspect = width.toDouble() / height
        val previewInfo = previewUseCase?.resolutionInfo
        val previewAspect = previewInfo?.let {
            if (it.rotationDegrees % 180 == 0) it.resolution.width.toDouble() / it.resolution.height
            else it.resolution.height.toDouble() / it.resolution.width
        }
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
                if (landmarks.count { it.landmarkType in setOf(0, 11, 12, 13, 14, 15, 16, 23, 24, 27, 28) } >= 6) people.put(rect(Rect(landmarks.minOf { it.position.x }.toInt(), landmarks.minOf { it.position.y }.toInt(),
                    landmarks.maxOf { it.position.x }.toInt(), landmarks.maxOf { it.position.y }.toInt()), "pose extent"))
                val faceBoxes = JSONArray(); faces.forEach { faceBoxes.put(rect(it.boundingBox, "face")) }
                if (people.length() == 0 && faces.isNotEmpty()) {
                    val face = faces.maxByOrNull { it.boundingBox.width() * it.boundingBox.height() }!!
                    people.put(PhotoGeometry.personFromFace(rect(face.boundingBox, "face")))
                }
                val posePoints = JSONObject()
                val jointNames = mapOf(0 to "nose", 11 to "leftShoulder", 12 to "rightShoulder", 13 to "leftElbow", 14 to "rightElbow", 15 to "leftWrist", 16 to "rightWrist", 23 to "leftHip", 24 to "rightHip", 27 to "leftAnkle", 28 to "rightAnkle")
                for (landmark in landmarks) jointNames[landmark.landmarkType]?.let { name ->
                    val x = landmark.position.x.toDouble() / width
                    posePoints.put(name, JSONObject().put("x", if (front) 1 - x else x).put("y", landmark.position.y / height).put("confidence", landmark.inFrameLikelihood))
                }
                val y = proxy.planes[0]; val buf = y.buffer.duplicate(); var sum = 0.0; var count = 0
                for (row in 0 until proxy.height step 16) for (col in 0 until proxy.width step 16) {
                    val index = row * y.rowStride + col * y.pixelStride
                    if (index < buf.limit()) { sum += (buf.get(index).toInt() and 255) / 255.0; count++ }
                }
                val payload = JSONObject().put("schemaVersion", 1).put("frameId", "$epoch:$now")
                    .put("imageWidth", width).put("imageHeight", height).put("displayRotationDegrees", rotation).put("front", front)
                    .put("motionStatus", if (motionAvailable) "valid" else "unsupported")
                    .put("configurationId", config).put("aspectRatio", aspect).put("previewAspectRatio", previewAspect ?: JSONObject.NULL).put("people", people).put("faces", faceBoxes)
                    .put("roll", roll).put("motion", motion).put("stable", motion < 0.22)
                    .put("backgroundLuminance", if (count > 0) sum / count else JSONObject.NULL)
                    .put("peopleScope", "single").put("groupScope", "faces").put("saliencyStatus", "unsupported").put("luminanceScale", 1)
                    .put("poseStatus", if (poseTask.isSuccessful) "valid" else "unavailable").put("poseKeypoints", posePoints)
                    .put("peopleStatus", if (poseTask.isSuccessful || faceTask.isSuccessful) "valid" else "unavailable")
                    .put("faceStatus", if (faceTask.isSuccessful) "valid" else "unavailable")
                    .put("horizonStatus", "unsupported").put("openAreaStatus", "unsupported").put("timestamp", System.currentTimeMillis())
                val bitmap = analysisImage(proxy, front)
                try {
                    val scene = PhotoGeometry.scenic(bitmap)
                    for (key in scene.keys()) payload.put(key, scene.get(key))
                    val face = faces.maxByOrNull { it.boundingBox.width() * it.boundingBox.height() }
                    if (face != null) {
                        val box = rect(face.boundingBox, "face")
                        var faceSum = 0.0; var samples = 0
                        val left = (box.getDouble("x") * bitmap.width).toInt().coerceIn(0, bitmap.width - 1)
                        val right = ((box.getDouble("x") + box.getDouble("width")) * bitmap.width).toInt().coerceIn(left + 1, bitmap.width)
                        val top = (box.getDouble("y") * bitmap.height).toInt().coerceIn(0, bitmap.height - 1)
                        val bottom = ((box.getDouble("y") + box.getDouble("height")) * bitmap.height).toInt().coerceIn(top + 1, bitmap.height)
                        for (y in top until bottom) for (x in left until right) { val c = bitmap.getPixel(x, y); faceSum += .2126 * Color.red(c) + .7152 * Color.green(c) + .0722 * Color.blue(c); samples++ }
                        if (samples > 0) payload.put("faceLuminance", faceSum / samples)
                        val eyeCount = listOf(FaceLandmark.LEFT_EYE, FaceLandmark.RIGHT_EYE).count { face.getLandmark(it) != null }
                        payload.put("faceAnalysis", JSONObject().put("confidence", 1.0).put("eyeVisibilityScore", eyeCount / 2.0).put("occlusionScore", if (eyeCount == 2) 0.0 else .6)
                            .put("yawEstimate", face.headEulerAngleY / 90.0 * if (front) -1 else 1).put("pitchEstimate", face.headEulerAngleX / 90.0).put("landmarkPointCount", face.allLandmarks.size))
                    }
                } finally { bitmap.recycle() }
                main.post {
                    if (epoch == generation && active) {
                        events.analysis(payload.toString()) {}
                        if (now - lastState > 1000) { lastState = now; events.state(snapshot()) {} }
                    }
                }
            } finally { proxy.close() }
        }
    }
    override fun onSensorChanged(event: SensorEvent) {
        val values = event.values
        if (event.sensor.type == Sensor.TYPE_LINEAR_ACCELERATION) {
            motion = sqrt(values.sumOf { it.toDouble().pow(2) }) / 9.81
            return
        }
        val adjustment = when (previewView?.display?.rotation ?: 0) { 1 -> 90; 2 -> 180; 3 -> -90; else -> 0 }
        var degrees = atan2(-values[0].toDouble(), values[1].toDouble()) * 180 / PI - adjustment
        while (degrees > 180) degrees -= 360
        while (degrees < -180) degrees += 360
        roll = if (hypot(values[0].toDouble(), values[1].toDouble()) < 1.5) 0.0 else if (front) -degrees else degrees
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
        if (!pendingFile.exists() && !File(pendingFile.path + ".bak").exists()) return null
        val json = JSONObject(String(android.util.AtomicFile(pendingFile).readFully())); val path = json.getString("path")
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
        if (Build.VERSION.SDK_INT < 29 && ContextCompat.checkSelfPermission(context, Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
            if (pendingSave != null) return callback(Result.failure(IllegalStateException("Save request busy")))
            pendingSave = Pair(photo, callback); activity!!.requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), 704); return
        }
        executor.execute {
            var inserted: Uri? = null
            try {
                val extension = File(photo.path).extension.ifEmpty { "jpg" }
                val name = "Dali-${photo.id}${if (photo.unsaved) "" else "-${UUID.randomUUID()}"}.$extension"; val collection = MediaStore.Images.Media.EXTERNAL_CONTENT_URI
                val existing = context.contentResolver.query(collection, arrayOf(MediaStore.Images.Media._ID),
                    "${MediaStore.Images.Media.DISPLAY_NAME} = ?", arrayOf(name), null)?.use { cursor ->
                    if (cursor.moveToFirst()) ContentUris.withAppendedId(collection, cursor.getLong(0)) else null }
                val values = ContentValues().apply {
                    put(MediaStore.Images.Media.DISPLAY_NAME, name); put(MediaStore.Images.Media.MIME_TYPE, photo.mimeType ?: "image/jpeg")
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
        executor.execute {
            var destination: File? = null
            try {
                val folder = File(context.cacheDir, "DaliShares").apply { check(isDirectory || mkdirs()) }
                for (old in folder.listFiles() ?: emptyArray()) if (old.isFile && System.currentTimeMillis() - old.lastModified() > 24 * 60 * 60 * 1000L) old.delete()
                val source = File(photo.path)
                val copy = File(folder, "share-${UUID.randomUUID()}.${source.extension.ifEmpty { "jpg" }}"); destination = copy
                source.inputStream().use { input -> copy.outputStream().use { input.copyTo(it) } }
                val uri = FileProvider.getUriForFile(context, "${context.packageName}.dali.files", copy)
                main.post {
                    try {
                        activity!!.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply {
                            type = photo.mimeType ?: "image/jpeg"; putExtra(Intent.EXTRA_STREAM, uri); addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION); clipData = ClipData.newRawUri("Dali photo", uri)
                        }, "Share photo")); callback(Result.success(Unit))
                    } catch (error: Exception) { copy.delete(); callback(Result.failure(error)) }
                }
            } catch (error: Exception) { destination?.delete(); main.post { callback(Result.failure(error)) } }
        }
    }
    override fun pickPhoto(callback: (Result<PhotoHandle?>) -> Unit) {
        launchPicker(false, false, callback, null)
    }
    override fun pickPhotos(folder: Boolean, callback: (Result<PhotoImport>) -> Unit) {
        launchPicker(folder, true, null, callback)
    }
    private fun launchPicker(folder: Boolean, multiple: Boolean, single: ((Result<PhotoHandle?>) -> Unit)?, batch: ((Result<PhotoImport>) -> Unit)?) {
        if (pendingPicker != null || pendingBatchPicker != null || activity == null) {
            val error = IllegalStateException("Photo picker unavailable")
            single?.invoke(Result.failure(error)); batch?.invoke(Result.failure(error)); return
        }
        pendingPicker = single; pendingBatchPicker = batch; pickerIsFolder = folder
        try {
            activity!!.startActivityForResult(Intent(if (folder) Intent.ACTION_OPEN_DOCUMENT_TREE else Intent.ACTION_OPEN_DOCUMENT).apply {
                if (!folder) { type = "image/*"; addCategory(Intent.CATEGORY_OPENABLE); putExtra(Intent.EXTRA_ALLOW_MULTIPLE, multiple) }
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }, 702)
        } catch (error: Exception) {
            pendingPicker = null; pendingBatchPicker = null
            single?.invoke(Result.failure(error)); batch?.invoke(Result.failure(error))
        }
    }
    private fun folderPhotos(tree: Uri): List<Uri> {
        val photos = mutableListOf<Pair<String, Uri>>()
        val folders = java.util.ArrayDeque<Pair<String, Int>>()
        folders.add(DocumentsContract.getTreeDocumentId(tree) to 0)
        var visited = 0
        while (folders.isNotEmpty() && visited < 4096) {
            val (id, depth) = folders.removeFirst()
            val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, id)
            context.contentResolver.query(children, arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME, DocumentsContract.Document.COLUMN_MIME_TYPE), null, null, null)?.use { cursor ->
                val entries = mutableListOf<Triple<String, String, String>>()
                while (cursor.moveToNext() && visited++ < 4096) {
                    entries.add(Triple(cursor.getString(0), cursor.getString(1) ?: "", cursor.getString(2) ?: ""))
                }
                for ((child, name, mime) in entries.sortedBy { it.second.lowercase() }) {
                    if (mime == DocumentsContract.Document.MIME_TYPE_DIR && depth < 16) folders.add(child to depth + 1)
                    else if (mime.startsWith("image/") && !name.startsWith(".") ) {
                        photos.add(name to DocumentsContract.buildDocumentUriUsingTree(tree, child))
                    }
                }
            }
        }
        return photos.sortedBy { it.first.lowercase() }.map { it.second }
    }
    private fun copyImportedPhoto(uri: Uri): PhotoHandle {
        val mime = context.contentResolver.getType(uri) ?: "image/jpeg"
        val extension = when (mime) { "image/png" -> "png"; "image/heic" -> "heic"; "image/heif" -> "heif"; "image/webp" -> "webp"; else -> "jpg" }
        val file = File(context.filesDir, "import-${UUID.randomUUID()}.$extension")
        try {
            context.contentResolver.openInputStream(uri)?.use { input -> file.outputStream().use { input.copyTo(it) } } ?: error("Cannot read selected photo")
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(file.path, bounds)
            check(bounds.outWidth > 0 && bounds.outHeight > 0) { "Cannot decode selected photo" }
            return PhotoHandle(file.path, file.nameWithoutExtension, false, mime)
        } catch (error: Exception) { file.delete(); throw error }
    }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != 702) return false
        val single = pendingPicker; val batch = pendingBatchPicker; val folder = pickerIsFolder
        if (single == null && batch == null) return true
        // Keep the request busy until copying finishes; no full-resolution bitmap is decoded.
        executor.execute {
            val photos = mutableListOf<PhotoHandle>()
            var skipped = 0
            try {
                val uris = if (resultCode != Activity.RESULT_OK || data == null) emptyList() else if (folder) {
                    data.data?.let { folderPhotos(it) } ?: emptyList()
                } else {
                    val clip = data.clipData
                    if (clip != null) (0 until clip.itemCount).map { clip.getItemAt(it).uri }.distinct()
                    else listOfNotNull(data.data)
                }
                val limit = if (batch == null) 1 else if (folder) 50 else 20
                skipped = (uris.size - limit).coerceAtLeast(0)
                for (uri in uris.take(limit)) {
                    try { photos.add(copyImportedPhoto(uri)) } catch (_: Exception) { skipped++ }
                }
                if ((uris.isNotEmpty() || (folder && resultCode == Activity.RESULT_OK)) && photos.isEmpty()) error("No readable images were found")
                main.post {
                    if (pendingPicker !== single || pendingBatchPicker !== batch) { photos.forEach { File(it.path).delete() }; return@post }
                    pendingPicker = null; pendingBatchPicker = null
                    single?.invoke(Result.success(photos.firstOrNull())); batch?.invoke(Result.success(PhotoImport(photos, skipped.toLong())))
                }
            } catch (error: Exception) {
                photos.forEach { File(it.path).delete() }
                main.post {
                    if (pendingPicker !== single || pendingBatchPicker !== batch) return@post
                    pendingPicker = null; pendingBatchPicker = null
                    single?.invoke(Result.failure(error)); batch?.invoke(Result.failure(error))
                }
            }
        }
        return true
    }
    override fun analyzePhoto(photo: PhotoHandle, callback: (Result<String>) -> Unit) {
        executor.execute {
            try { val packet = stillProcessor.analyze(photo).toString(); main.post { callback(Result.success(packet)) } }
            catch (error: Exception) { main.post { callback(Result.failure(error)) } }
        }
    }
    override fun renderEffects(original: PhotoHandle, recipe: String, callback: (Result<PhotoHandle>) -> Unit) {
        executor.execute {
            var output: Bitmap? = null
            var destination: File? = null
            try {
                val image = stillProcessor.render(original, recipe); output = image
                val markPath = JSONObject(recipe).optString("watermarkPath", "")
                if (markPath.isNotEmpty()) {
                    val mark = BitmapFactory.decodeFile(markPath) ?: error("Cannot decode watermark")
                    val width = image.width * .23f; val height = width * mark.height / mark.width; val margin = image.width * .025f
                    Canvas(image).drawBitmap(mark, null, RectF(image.width - width - margin, image.height - height - margin,
                        image.width - margin, image.height - margin), Paint(Paint.ANTI_ALIAS_FLAG).apply { alpha = 219 })
                    mark.recycle()
                }
                val file = photoFile(); destination = file
                file.outputStream().use { check(image.compress(Bitmap.CompressFormat.JPEG, 95, it)) }
                main.post { callback(Result.success(PhotoHandle(file.path, file.nameWithoutExtension, false, "image/jpeg"))) }
            } catch (error: Throwable) {
                destination?.delete()
                main.post { callback(Result.failure(if (error is OutOfMemoryError) IllegalStateException("Not enough memory to process this photo. Original retained.") else error)) }
            } finally { output?.recycle() }
        }
    }
    override fun render(original: PhotoHandle, rotationDegrees: Double, crop: Boolean, strength: Double, callback: (Result<PhotoHandle>) -> Unit) {
        executor.execute {
            var bitmap: Bitmap? = null
            var destination: File? = null
            try {
                check(rotationDegrees.isFinite() && strength.isFinite()) { "Invalid rendering settings" }
                var output = stillProcessor.load(original.path); bitmap = output
                fun replace(result: Bitmap) { if (result !== output) output.recycle(); output = result; bitmap = result }
                if (rotationDegrees != 0.0) replace(Bitmap.createBitmap(output, 0, 0, output.width, output.height, Matrix().apply { setRotate(rotationDegrees.toFloat()) }, true))
                if (crop) { val x = (output.width * 0.08).toInt(); val y = (output.height * 0.08).toInt(); replace(Bitmap.createBitmap(output, x, y, output.width - 2*x, output.height - 2*y)) }
                if (strength > 0) {
                    val processed = Bitmap.createBitmap(output.width, output.height, Bitmap.Config.ARGB_8888)
                    val paint = Paint().apply { colorFilter = ColorMatrixColorFilter(ColorMatrix().apply { setSaturation(1f + strength.toFloat() * 0.12f) }) }
                    Canvas(processed).drawBitmap(output, 0f, 0f, paint); replace(processed)
                }
                val file = photoFile(); destination = file; file.outputStream().use { check(output.compress(Bitmap.CompressFormat.JPEG, 95, it)) }
                main.post { callback(Result.success(PhotoHandle(file.path, file.nameWithoutExtension, false))) }
            } catch (e: Throwable) { destination?.delete(); main.post { callback(Result.failure(if (e is OutOfMemoryError) IllegalStateException("Not enough memory to process this photo. Original retained.") else e)) } }
            finally { bitmap?.recycle() }
        }
    }
    override fun setZoom(configurationId: String, zoom: Double, callback: (Result<CameraSnapshot>) -> Unit) {
        try {
            check(config == configurationId && active && zoom.isFinite()) { "Camera changed or invalid zoom" }
            val cam = camera!!; val state = cam.cameraInfo.zoomState.value!!
            val future = cam.cameraControl.setZoomRatio(zoom.toFloat().coerceIn(state.minZoomRatio, state.maxZoomRatio))
            future.addListener({ try { future.get(); check(config == configurationId && active); callback(Result.success(snapshot())) } catch (e: Exception) { callback(Result.failure(e)) } }, ContextCompat.getMainExecutor(context))
        } catch (e: Exception) { callback(Result.failure(e)) }
    }
    override fun meter(configurationId: String, x: Double, y: Double, callback: (Result<CameraSnapshot>) -> Unit) {
        try {
            check(config == configurationId && active && x.isFinite() && y.isFinite()) { "Camera changed or invalid focus point" }
            val cam = camera!!; val view = previewView ?: error("No preview")
            val point = view.meteringPointFactory.createPoint(x.coerceIn(0.0, 1.0).toFloat() * view.width, y.coerceIn(0.0, 1.0).toFloat() * view.height)
            val action = FocusMeteringAction.Builder(point, if (manualExposure) FocusMeteringAction.FLAG_AF else FocusMeteringAction.FLAG_AF or FocusMeteringAction.FLAG_AE).disableAutoCancel().build()
            check(cam.cameraInfo.isFocusMeteringSupported(action)) { "Focus point unavailable" }
            val future = cam.cameraControl.startFocusAndMetering(action)
            future.addListener({ try { future.get(); check(config == configurationId && active); callback(Result.success(snapshot())) } catch (e: Exception) { callback(Result.failure(e)) } }, ContextCompat.getMainExecutor(context))
        } catch (e: Exception) { callback(Result.failure(e)) }
    }
    override fun setManualExposure(configurationId: String, seconds: Double?, iso: Double?, callback: (Result<CameraSnapshot>) -> Unit) {
        try {
            check(config == configurationId && active) { "Camera changed; refresh controls" }
            val cam = camera!!; val state = snapshot()
            val enabling = seconds != null && iso != null
            val options = CaptureRequestOptions.Builder()
            if (enabling) {
                check(seconds!!.isFinite() && iso!!.isFinite() && state.minimumISO != null && state.minimumShutter != null) { "Manual exposure unavailable" }
                val duration = (seconds.coerceIn(state.minimumShutter!!, state.maximumShutter!!) * 1e9).toLong()
                options.setCaptureRequestOption(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_OFF)
                    .setCaptureRequestOption(CaptureRequest.SENSOR_EXPOSURE_TIME, duration)
                    .setCaptureRequestOption(CaptureRequest.SENSOR_SENSITIVITY, iso.toInt().coerceIn(state.minimumISO!!.toInt(), state.maximumISO!!.toInt()))
                    .setCaptureRequestOption(CaptureRequest.SENSOR_FRAME_DURATION, max(duration, 33333333L))
            } else {
                options.setCaptureRequestOption(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON)
                    .setCaptureRequestOption(CaptureRequest.CONTROL_AE_LOCK, false)
                    .setCaptureRequestOption(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
                    .setCaptureRequestOption(CaptureRequest.CONTROL_AWB_MODE, CaptureRequest.CONTROL_AWB_MODE_AUTO)
            }
            val future = Camera2CameraControl.from(cam.cameraControl).setCaptureRequestOptions(options.build())
            future.addListener({
                try {
                    future.get(); check(config == configurationId && active)
                    manualExposure = enabling; lockedState = false
                    if (!enabling) {
                        cam.cameraControl.cancelFocusAndMetering()
                        val reset = cam.cameraControl.setExposureCompensationIndex(0)
                        reset.addListener({ try { reset.get(); check(config == configurationId && active); callback(Result.success(snapshot())) } catch (e: Exception) { callback(Result.failure(e)) } }, ContextCompat.getMainExecutor(context))
                    } else callback(Result.success(snapshot()))
                } catch (e: Exception) { callback(Result.failure(e)) }
            }, ContextCompat.getMainExecutor(context))
        } catch (e: Exception) { callback(Result.failure(e)) }
    }
    override fun setVoicePhrase(phrase: String) { customVoicePhrase = phrase.take(120) }
    override fun reconcilePrivatePhotos(retainedPaths: List<String>, callback: (Result<Unit>) -> Unit) {
        executor.execute {
            try {
                val keep = retainedPaths.map { File(it).canonicalPath }.toMutableSet()
                recover()?.let { keep.add(File(it.path).canonicalPath) }
                val root = context.filesDir.canonicalFile
                for (file in root.listFiles() ?: emptyArray()) {
                    if (file.canonicalFile.parentFile != root || !file.isFile || file.canonicalPath in keep) continue
                    if (file.name.startsWith("photo-") && file.extension == "jpg" || file.name.startsWith("import-")) check(file.delete()) { "Cannot clean an unused private copy" }
                }
                main.post { callback(Result.success(Unit)) }
            } catch (error: Exception) { main.post { callback(Result.failure(error)) } }
        }
    }
    override fun releasePhoto(photo: PhotoHandle) {
        val file = File(photo.path).canonicalFile
        if (file.parentFile == photoFile().parentFile?.canonicalFile && (file.extension in listOf("jpg", "jpeg", "png", "heic", "heif", "webp") || file.name.startsWith("import-")) && recover()?.id != photo.id) {
            if (file.exists()) check(file.delete()) { "Cannot release private copy" }
        }
    }
    override fun renderFilter(original: PhotoHandle, matrix: List<Double>, parameters: List<Double>, watermarkPath: String?, callback: (Result<PhotoHandle>) -> Unit) {
        if (parameters.size != 7 || !parameters.all { it.isFinite() }) {
            callback(Result.failure(IllegalArgumentException("Invalid filter parameters"))); return
        }
        // Android spatial/color parity remains subject to visual calibration.
        val recipe = JSONObject().put("version", 1).put("treatment", "original").put("filter", JSONArray(parameters))
        if (watermarkPath != null) recipe.put("watermarkPath", watermarkPath)
        renderEffects(original, recipe.toString(), callback)
    }
    override fun renderStyle(original: PhotoHandle, matrix: List<Double>, softness: Double, detail: Double, watermarkPath: String?, callback: (Result<PhotoHandle>) -> Unit) {
        executor.execute {
            try {
                check(matrix.size == 20 && matrix.all { it.isFinite() } && softness.isFinite() && detail.isFinite()) { "Invalid style" }
                val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeFile(original.path, options)
                options.inSampleSize = 1
                while (max(options.outWidth, options.outHeight) / options.inSampleSize > 3200) options.inSampleSize *= 2
                options.inJustDecodeBounds = false
                val source = BitmapFactory.decodeFile(original.path, options) ?: error("Cannot decode photo")
                val orientation = ExifInterface(original.path).getAttributeInt(ExifInterface.TAG_ORIENTATION, 1)
                val transform = Matrix()
                when (orientation) {
                    2 -> transform.setScale(-1f, 1f); 3 -> transform.setRotate(180f); 4 -> transform.setScale(1f, -1f)
                    5 -> { transform.setRotate(90f); transform.postScale(-1f, 1f) }; 6 -> transform.setRotate(90f)
                    7 -> { transform.setRotate(270f); transform.postScale(-1f, 1f) }; 8 -> transform.setRotate(270f)
                }
                val upright = Bitmap.createBitmap(source, 0, 0, source.width, source.height, transform, true)
                val output = Bitmap.createBitmap(upright.width, upright.height, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(output)
                canvas.drawBitmap(upright, 0f, 0f, Paint().apply { colorFilter = ColorMatrixColorFilter(matrix.map { it.toFloat() }.toFloatArray()) })
                if (softness > 0 || detail > 0) StyleRenderer.finish(output, softness.coerceIn(0.0, 5.0), detail.coerceIn(0.0, 5.0))
                if (watermarkPath != null) {
                    val mark = BitmapFactory.decodeFile(watermarkPath) ?: error("Cannot load watermark")
                    val width = output.width * 0.28f; val height = width * mark.height / mark.width
                    val margin = max(18f, output.width * 0.025f)
                    canvas.drawBitmap(mark, null, RectF(output.width-width-margin, output.height-height-margin, output.width-margin, output.height-margin), Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply { alpha = 219 })
                    mark.recycle()
                }
                val file = photoFile(); file.outputStream().use { check(output.compress(Bitmap.CompressFormat.JPEG, 95, it)) }
                if (upright !== source) upright.recycle(); source.recycle(); output.recycle()
                main.post { callback(Result.success(PhotoHandle(file.path, file.nameWithoutExtension, false))) }
            } catch (e: Exception) { main.post { callback(Result.failure(e)) } }
        }
    }
    override fun openSettings() { activity!!.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}"))) }
    override fun setVoiceEnabled(enabled: Boolean, callback: (Result<Boolean>) -> Unit) {
        val epoch = ++speechEpoch
        listening = false; speech?.destroy(); speech = null
        if (!enabled || Build.VERSION.SDK_INT < 31 || !SpeechRecognizer.isOnDeviceRecognitionAvailable(context)) { callback(Result.success(false)); return }
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            activity!!.requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 703)
            callback(Result.failure(SecurityException("Allow microphone access, then enable voice shutter again"))); return
        }
        speech = SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
        speech!!.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) { if (epoch == speechEpoch && listening) events.voiceState(true, "Listening on device") {} }
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() { if (epoch == speechEpoch) events.voiceState(false, "Processing voice command") {} }
            override fun onPartialResults(partialResults: Bundle?) {}
            override fun onEvent(eventType: Int, params: Bundle?) {}
            override fun onError(error: Int) {
                if (epoch != speechEpoch || !listening) return
                if (error == SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS || error == SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED) {
                    listening = false; events.error("speech", "Voice shutter unavailable for this permission or language") {}
                    events.voiceState(false, "Voice shutter unavailable for this permission or language") {}
                } else if (listening && active) { events.voiceState(false, "Waiting to listen") {}; main.postDelayed({ if (epoch == speechEpoch) listen() }, 1000) }
            }
            override fun onResults(results: Bundle?) {
                if (epoch != speechEpoch || !listening || !active) return
                val text = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()?.lowercase() ?: ""
                val words = text.split(Regex("[^\\p{L}]+" )).filter { it.isNotEmpty() }
                val custom = customVoicePhrase.lowercase().split(Regex("[^\\p{L}]+" )).filter { it.isNotEmpty() }
                val command = words.contains("cheese") || Regex("\\b(take|capture|snap) (a )?(photo|picture)\\b").containsMatchIn(text) ||
                    (custom.isNotEmpty() && (" " + words.joinToString(" ") + " ").contains(" " + custom.joinToString(" ") + " "))
                if (command && SystemClock.elapsedRealtime() - lastVoice > 3000) { lastVoice = SystemClock.elapsedRealtime(); events.voiceShutter() {} }
                if (listening && active) main.postDelayed({ if (epoch == speechEpoch) listen() }, 500)
            }
        })
        listening = true; listen(); callback(Result.success(true))
    }
    private fun listen() {
        if (listening && active) speech?.startListening(Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
        })
    }
    override fun setDepthPreview(configurationId: String, level: Long, subjectRect: String?) {
        if (configurationId != config || !active) return
        val overlay = depthView ?: return
        val rect = subjectRect?.let { JSONObject(it) }
        overlay.level = level.toInt().coerceIn(0, 5); overlay.aspect = aspect
        overlay.subject = rect?.let { val x = it.getDouble("x").toFloat(); val y = it.getDouble("y").toFloat(); RectF(x, y, x + it.getDouble("width").toFloat(), y + it.getDouble("height").toFloat()) }
        if (overlay.level == 0 || rect == null) { overlay.replace(null); return }
        overlay.invalidate()
        val now = SystemClock.elapsedRealtime()
        if (depthPending || now - lastDepth < 500) return
        val source = previewView?.bitmap ?: return
        depthPending = true; lastDepth = now; val epoch = generation; val requestedLevel = overlay.level; val requestedRotation = displayRotation
        depthExecutor.execute {
            var blurred: Bitmap? = null
            try {
                val scale = min(1.0, 320.0 / max(source.width, source.height))
                val small = Bitmap.createScaledBitmap(source, max(1, (source.width * scale).toInt()), max(1, (source.height * scale).toInt()), true)
                if (small !== source) source.recycle()
                blurred = stillProcessor.previewBlur(small, requestedLevel)
                if (small !== blurred) small.recycle()
            } catch (_: Throwable) { if (!source.isRecycled) source.recycle() }
            val result = blurred
            main.post { depthPending = false; if (epoch == generation && requestedRotation == displayRotation && active && depthView === overlay && overlay.level > 0) overlay.replace(result) else result?.recycle() }
        }
    }
}

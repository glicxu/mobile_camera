package com.dalicamera.dali_camera_platform

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Looper
import android.os.SystemClock
import androidx.core.content.ContextCompat
import androidx.exifinterface.media.ExifInterface
import java.io.File

/** Foreground-only collection. Never waits for a fix on the shutter path. */
internal class PhotoLocation(private val context: Context) : LocationListener {
    private val manager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
    private var enabled = false
    private var active = false
    private var latest: Location? = null
    private var listening = false

    private fun permitted() = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
        ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED

    fun configure(value: Boolean, requestPermission: Boolean, activity: Activity?): String {
        enabled = value
        refresh()
        if (enabled && !permitted() && requestPermission && activity != null) {
            activity.requestPermissions(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION), PERMISSION_REQUEST)
        }
        return status()
    }

    fun setActive(value: Boolean) { active = value; refresh() }

    fun refresh() {
        stopUpdates()
        if (!enabled || !active || !permitted()) { latest = null; return }
        try {
            for (provider in manager.getProviders(true)) {
                if (provider != LocationManager.GPS_PROVIDER && provider != LocationManager.NETWORK_PROVIDER) continue
                if (provider == LocationManager.GPS_PROVIDER && ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) continue
                manager.getLastKnownLocation(provider)?.let { accept(it) }
                manager.requestLocationUpdates(provider, 10_000L, 10f, this, Looper.getMainLooper())
                listening = true
            }
        } catch (_: SecurityException) { stopUpdates(); latest = null }
    }

    private fun stopUpdates() {
        if (listening) runCatching { manager.removeUpdates(this) }
        listening = false
    }

    private fun servicesEnabled() = runCatching {
        manager.isProviderEnabled(LocationManager.GPS_PROVIDER) || manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
    }.getOrDefault(false)

    private fun valid(location: Location): Boolean {
        val age = SystemClock.elapsedRealtimeNanos() - location.elapsedRealtimeNanos
        return age in 0..120_000_000_000L && location.hasAccuracy() && location.accuracy >= 0 &&
            location.latitude.isFinite() && location.longitude.isFinite() &&
            location.latitude in -90.0..90.0 && location.longitude in -180.0..180.0
    }

    private fun accept(location: Location) {
        if (valid(location) && (latest == null || !valid(latest!!) || location.elapsedRealtimeNanos > latest!!.elapsedRealtimeNanos)) latest = Location(location)
    }

    fun current(): Location? = if (enabled && active && permitted() && servicesEnabled()) latest?.takeIf { valid(it) }?.let { Location(it) } else null

    private fun status(): String = when {
        !enabled -> "off"
        !permitted() -> "permissionDenied"
        !servicesEnabled() -> "servicesDisabled"
        current() == null -> "waiting"
        ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED -> "approximate"
        else -> "ready"
    }

    override fun onLocationChanged(location: Location) { if (enabled && active) accept(location) }
    override fun onProviderDisabled(provider: String) { latest = null }
    override fun onProviderEnabled(provider: String) { refresh() }
    @Deprecated("Legacy Android callback")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}

    companion object {
        const val PERMISSION_REQUEST = 711
        // Pixel processing creates a new JPEG. Carry GPS from the capture, never
        // from the device's position at editing/save time.
        fun copyGps(source: String, destination: File) {
            val input = ExifInterface(source)
            val output = ExifInterface(destination)
            for (tag in listOf("GPSVersionID", "GPSLatitudeRef", "GPSLatitude", "GPSLongitudeRef", "GPSLongitude",
                "GPSAltitudeRef", "GPSAltitude", "GPSTimeStamp", "GPSDateStamp", "GPSProcessingMethod",
                "GPSHPositioningError", "GPSSpeedRef", "GPSSpeed", "GPSImgDirectionRef", "GPSImgDirection")) {
                output.setAttribute(tag, input.getAttribute(tag))
            }
            output.saveAttributes()
        }
    }
}

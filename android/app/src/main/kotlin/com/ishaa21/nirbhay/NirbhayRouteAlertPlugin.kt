package com.ishaa21.nirbhay

import android.Manifest
import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Android Platform Channel for Nirbhay Proactive Route Safety Alerts.
 *
 * Posts heads-up notifications when a user approaches a community-reported safety hotspot
 * during active journey or route monitoring, even when the application is backgrounded.
 */
class NirbhayRouteAlertPlugin(
    private val activity: Activity,
    flutterEngine: FlutterEngine,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val TAG = "NirbhayRouteAlertPlugin"
        const val METHOD_CHANNEL = "com.ishaa21.nirbhay/route_alerts"
        const val CHANNEL_ID = "nirbhay_route_alerts_channel"
        const val NOTIFICATION_PERMISSION_REQUEST_CODE = 9301

        const val ACTION_VIEW_HOTSPOT = "com.ishaa21.nirbhay.ACTION_VIEW_HOTSPOT"
        const val EXTRA_HOTSPOT_ID = "hotspot_id"
        const val EXTRA_HOTSPOT_LAT = "hotspot_lat"
        const val EXTRA_HOTSPOT_LNG = "hotspot_lng"
        const val EXTRA_RISK_LEVEL = "risk_level"

        var pendingHotspotId: String? = null
        var pendingHotspotLat: Double? = null
        var pendingHotspotLng: Double? = null
    }

    private val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)

    init {
        channel.setMethodCallHandler(this)
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Proactive Safety & Danger Alerts"
            val descriptionText = "Warnings when route approaches community-reported unsafe hotspots"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val mChannel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
                enableLights(true)
                lightColor = Color.RED
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 350, 150, 350)
            }
            val notificationManager =
                activity.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(mChannel)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "showSafetyAlert" -> {
                val title = call.argument<String>("title") ?: "Safety Alert"
                val message = call.argument<String>("message") ?: "Approaching an area with recent safety reports."
                val hotspotId = call.argument<String>("hotspotId") ?: "hotspot_default"
                val latitude = call.argument<Double>("latitude") ?: 0.0
                val longitude = call.argument<Double>("longitude") ?: 0.0
                val riskLevel = call.argument<String>("riskLevel") ?: "ORANGE"
                val vibrate = call.argument<Boolean>("vibrate") ?: true

                showNotification(title, message, hotspotId, latitude, longitude, riskLevel, vibrate)
                result.success(true)
            }
            "cancelAlert" -> {
                val hotspotId = call.argument<String>("hotspotId") ?: ""
                cancelNotification(hotspotId)
                result.success(true)
            }
            "hasNotificationPermission" -> {
                result.success(checkNotificationPermission())
            }
            "requestNotificationPermission" -> {
                requestNotificationPermission()
                result.success(true)
            }
            "getPendingHotspotTap" -> {
                if (pendingHotspotId != null) {
                    val map = mapOf(
                        "hotspotId" to pendingHotspotId,
                        "latitude" to pendingHotspotLat,
                        "longitude" to pendingHotspotLng,
                    )
                    pendingHotspotId = null
                    pendingHotspotLat = null
                    pendingHotspotLng = null
                    result.success(map)
                } else {
                    result.success(null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun showNotification(
        title: String,
        message: String,
        hotspotId: String,
        latitude: Double,
        longitude: Double,
        riskLevel: String,
        vibrate: Boolean,
    ) {
        val notificationManager =
            activity.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Intent to launch MainActivity and focus the hotspot on map
        val intent = Intent(activity, MainActivity::class.java).apply {
            action = ACTION_VIEW_HOTSPOT
            putExtra(EXTRA_HOTSPOT_ID, hotspotId)
            putExtra(EXTRA_HOTSPOT_LAT, latitude)
            putExtra(EXTRA_HOTSPOT_LNG, longitude)
            putExtra(EXTRA_RISK_LEVEL, riskLevel)
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val pendingIntent = PendingIntent.getActivity(
            activity,
            hotspotId.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        val accentColor = when (riskLevel.uppercase()) {
            "RED" -> Color.rgb(211, 47, 47)
            "ORANGE" -> Color.rgb(234, 88, 12)
            else -> Color.rgb(202, 138, 4)
        }

        val notification = NotificationCompat.Builder(activity, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(message)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setColor(accentColor)
            .setColorized(true)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setOngoing(false)
            .apply {
                if (vibrate) {
                    setVibrate(longArrayOf(0, 350, 150, 350))
                }
            }
            .build()

        // Notification ID derived from hotspot string hash
        val notifId = (hotspotId.hashCode() and 0x7FFFFFFF)
        notificationManager.notify(notifId, notification)

        // Haptic feedback if enabled
        if (vibrate) {
            triggerHapticFeedback()
        }
    }

    private fun cancelNotification(hotspotId: String) {
        val notificationManager =
            activity.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val notifId = (hotspotId.hashCode() and 0x7FFFFFFF)
        notificationManager.cancel(notifId)
    }

    private fun triggerHapticFeedback() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager =
                    activity.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vibratorManager?.defaultVibrator?.vibrate(
                    VibrationEffect.createWaveform(longArrayOf(0, 350, 150, 350), -1)
                )
            } else {
                @Suppress("DEPRECATION")
                val vibrator = activity.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                @Suppress("DEPRECATION")
                vibrator?.vibrate(longArrayOf(0, 350, 150, 350), -1)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error triggering haptic vibration: ${e.message}")
        }
    }

    private fun checkNotificationPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                activity,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATION_PERMISSION_REQUEST_CODE
            )
        }
    }
}

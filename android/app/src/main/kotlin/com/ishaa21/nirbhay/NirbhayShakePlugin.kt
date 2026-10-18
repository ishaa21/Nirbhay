package com.ishaa21.nirbhay

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Build
import android.view.WindowManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter Platform Channel for Nirbhay Background Shake-to-SOS.
 *
 * Exposes methods to toggle the service, check active countdowns,
 * change sensitivity, and listen to countdown tick and cancellation events.
 */
class NirbhayShakePlugin(
    private val activity: Activity,
    flutterEngine: FlutterEngine,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        const val METHOD_CHANNEL = "com.ishaa21.nirbhay/shake_sos"
        const val EVENT_CHANNEL = "com.ishaa21.nirbhay/shake_events"

        private var eventSink: EventChannel.EventSink? = null
        private var activePluginInstance: NirbhayShakePlugin? = null

        fun onCountdownStarted(endTimeMs: Long, remainingSeconds: Int) {
            emitEvent(
                mapOf(
                    "type" to "countdown_started",
                    "endTimeMs" to endTimeMs,
                    "remainingSeconds" to remainingSeconds,
                )
            )
        }

        fun onCountdownTick(remainingSeconds: Int) {
            emitEvent(
                mapOf(
                    "type" to "countdown_tick",
                    "remainingSeconds" to remainingSeconds,
                )
            )
        }

        fun onCountdownCancelled() {
            emitEvent(
                mapOf(
                    "type" to "countdown_cancelled",
                )
            )
        }

        fun onCountdownExpired() {
            emitEvent(
                mapOf(
                    "type" to "countdown_expired",
                )
            )
        }

        private fun emitEvent(payload: Map<String, Any?>) {
            activePluginInstance?.activity?.runOnUiThread {
                eventSink?.success(payload)
            }
        }
    }

    private val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
    private val eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)

    init {
        activePluginInstance = this
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
        configureWindowShowWhenLocked()
    }

    fun dispose() {
        if (activePluginInstance == this) {
            activePluginInstance = null
        }
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startService" -> {
                val intent = Intent(activity, ShakeDetectionService::class.java).apply {
                    action = ShakeDetectionService.ACTION_START
                }
                ContextCompat.startForegroundService(activity, intent)
                val prefs = activity.getSharedPreferences(ShakeDetectionService.PREFS_NAME, Context.MODE_PRIVATE)
                prefs.edit().putBoolean(ShakeDetectionService.KEY_ENABLED, true).apply()
                result.success(true)
            }
            "stopService" -> {
                val intent = Intent(activity, ShakeDetectionService::class.java).apply {
                    action = ShakeDetectionService.ACTION_STOP
                }
                activity.startService(intent)
                val prefs = activity.getSharedPreferences(ShakeDetectionService.PREFS_NAME, Context.MODE_PRIVATE)
                prefs.edit().putBoolean(ShakeDetectionService.KEY_ENABLED, false).apply()
                result.success(true)
            }
            "isServiceEnabled" -> {
                val prefs = activity.getSharedPreferences(ShakeDetectionService.PREFS_NAME, Context.MODE_PRIVATE)
                val isEnabled = prefs.getBoolean(ShakeDetectionService.KEY_ENABLED, false)
                result.success(isEnabled)
            }
            "cancelCountdown" -> {
                ShakeDetectionService.cancelCountdown(activity)
                result.success(true)
            }
            "getCountdownState" -> {
                val active = ShakeDetectionService.isCountdownActive(activity)
                val remaining = ShakeDetectionService.getRemainingSeconds(activity)
                result.success(
                    mapOf(
                        "isActive" to active,
                        "remainingSeconds" to remaining,
                    )
                )
            }
            "setSensitivity" -> {
                val sensitivity = call.argument<String>("sensitivity") ?: "DEFAULT"
                val prefs = activity.getSharedPreferences(ShakeDetectionService.PREFS_NAME, Context.MODE_PRIVATE)
                prefs.edit().putString(ShakeDetectionService.KEY_SENSITIVITY, sensitivity).apply()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun configureWindowShowWhenLocked() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            activity.setShowWhenLocked(true)
            activity.setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            activity.window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
    }
}

package com.ishaa21.nirbhay

import android.Manifest
import android.app.Activity
import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter Platform Plugin for scheduling and controlling Fake Calls across
 * foreground, background, locked screen, and device reboot scenarios.
 */
class NirbhayFakeCallPlugin(
    private val context: Context,
    flutterEngine: FlutterEngine,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val TAG = "NirbhayFakeCall"
        const val CHANNEL = "com.ishaa21.nirbhay/fake_call"
        const val ALARM_REQUEST_CODE = 2001
        const val NOTIFICATION_PERMISSION_REQ_CODE = 3001

        var pendingTriggerCallerName: String? = null
        var pendingTriggerCallerSubtitle: String? = null
        var isAcceptedFromNotification: Boolean = false

        private var activeChannel: MethodChannel? = null
        private val mainHandler = Handler(Looper.getMainLooper())

        /**
         * Dispatches real-time event to Flutter when call triggers while app process is alive.
         */
        fun sendTriggerEventToFlutter(callerName: String, callerSubtitle: String, isAccepted: Boolean) {
            mainHandler.post {
                val data = mapOf(
                    "callerName" to callerName,
                    "callerSubtitle" to callerSubtitle,
                    "isAccepted" to isAccepted,
                )
                Log.d(TAG, "sendTriggerEventToFlutter: activeChannel=${activeChannel != null}, data=$data")
                activeChannel?.invokeMethod("onFakeCallTriggered", data)
            }
        }

        /**
         * Dispatches cancellation event to Flutter if call was declined or cancelled.
         */
        fun sendCancelEventToFlutter() {
            mainHandler.post {
                Log.d(TAG, "sendCancelEventToFlutter")
                activeChannel?.invokeMethod("onFakeCallCancelled", null)
            }
        }

        /**
         * Reschedules an alarm (e.g. from BootReceiver after device reboot).
         */
        fun rescheduleAlarm(
            context: Context,
            triggerAtMillis: Long,
            callerName: String,
            callerSubtitle: String,
            avatarIndex: Int = 0,
        ) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val pendingIntent = createAlarmPendingIntent(context, callerName, callerSubtitle, avatarIndex)

            safeSetExactAlarm(context, alarmManager, triggerAtMillis, pendingIntent)
        }

        private fun createAlarmPendingIntent(
            context: Context,
            callerName: String,
            callerSubtitle: String,
            avatarIndex: Int,
        ): PendingIntent {
            val intent = Intent(context, FakeCallReceiver::class.java).apply {
                action = FakeCallReceiver.ACTION_TRIGGER_FAKE_CALL
                putExtra(FakeCallReceiver.EXTRA_CALLER_NAME, callerName)
                putExtra(FakeCallReceiver.EXTRA_CALLER_SUBTITLE, callerSubtitle)
                putExtra(FakeCallReceiver.EXTRA_AVATAR_INDEX, avatarIndex)
            }

            val flagImmutable = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            return PendingIntent.getBroadcast(
                context,
                ALARM_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or flagImmutable,
            )
        }

        private fun safeSetExactAlarm(
            context: Context,
            alarmManager: AlarmManager,
            triggerAtMillis: Long,
            pendingIntent: PendingIntent,
        ) {
            val canScheduleExact = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                alarmManager.canScheduleExactAlarms()
            } else {
                true
            }

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP && canScheduleExact) {
                    val showIntent = Intent(context, MainActivity::class.java)
                    val flagImmutable = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
                    val showPending = PendingIntent.getActivity(
                        context,
                        2005,
                        showIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or flagImmutable,
                    )
                    alarmManager.setAlarmClock(
                        AlarmManager.AlarmClockInfo(triggerAtMillis, showPending),
                        pendingIntent,
                    )
                    Log.i(TAG, "Scheduled alarm with setAlarmClock for timestamp=$triggerAtMillis")
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    if (canScheduleExact) {
                        alarmManager.setExactAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            triggerAtMillis,
                            pendingIntent,
                        )
                        Log.i(TAG, "Scheduled alarm with setExactAndAllowWhileIdle for timestamp=$triggerAtMillis")
                    } else {
                        alarmManager.setAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            triggerAtMillis,
                            pendingIntent,
                        )
                        Log.w(TAG, "Exact alarm permission missing; fallback to setAndAllowWhileIdle")
                    }
                } else {
                    alarmManager.setExact(
                        AlarmManager.RTC_WAKEUP,
                        triggerAtMillis,
                        pendingIntent,
                    )
                    Log.i(TAG, "Scheduled alarm with setExact for timestamp=$triggerAtMillis")
                }
            } catch (se: SecurityException) {
                Log.e(TAG, "SecurityException in safeSetExactAlarm, falling back to setAndAllowWhileIdle: ${se.message}")
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        alarmManager.setAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            triggerAtMillis,
                            pendingIntent,
                        )
                    } else {
                        alarmManager.set(
                            AlarmManager.RTC_WAKEUP,
                            triggerAtMillis,
                            pendingIntent,
                        )
                    }
                } catch (fallbackEx: Throwable) {
                    Log.e(TAG, "Fallback alarm scheduling also failed: ${fallbackEx.message}")
                }
            }
        }
    }

    private val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

    init {
        channel.setMethodCallHandler(this)
        activeChannel = channel
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "scheduleFakeCall" -> {
                val delaySeconds = call.argument<Int>("delaySeconds") ?: 0
                val callerName = call.argument<String>("callerName") ?: "Mom"
                val callerSubtitle = call.argument<String>("callerSubtitle") ?: "Mobile"
                val avatarIndex = call.argument<Int>("avatarIndex") ?: 0

                Log.d(TAG, "onMethodCall scheduleFakeCall: delay=$delaySeconds, name=$callerName")
                scheduleAlarm(delaySeconds, callerName, callerSubtitle, avatarIndex)
                result.success(true)
            }

            "cancelScheduledFakeCall" -> {
                Log.d(TAG, "onMethodCall cancelScheduledFakeCall")
                cancelAlarm()
                FakeCallReceiver.stopRingtone(context)
                result.success(true)
            }

            "stopRingtone" -> {
                Log.d(TAG, "onMethodCall stopRingtone")
                FakeCallReceiver.stopRingtone(context)
                result.success(true)
            }

            "getPendingTrigger" -> {
                val data = mutableMapOf<String, Any?>()
                data["hasPendingTrigger"] = pendingTriggerCallerName != null
                data["callerName"] = pendingTriggerCallerName
                data["callerSubtitle"] = pendingTriggerCallerSubtitle
                data["isAccepted"] = isAcceptedFromNotification

                Log.d(TAG, "onMethodCall getPendingTrigger: $data")

                // Clear after consuming
                pendingTriggerCallerName = null
                pendingTriggerCallerSubtitle = null
                isAcceptedFromNotification = false

                result.success(data)
            }

            "checkPermissions" -> {
                val status = checkPermissionsStatus()
                Log.d(TAG, "onMethodCall checkPermissions: $status")
                result.success(status)
            }

            "requestNotificationPermission" -> {
                requestNotificationPermission()
                result.success(true)
            }

            "requestExactAlarmPermission" -> {
                requestExactAlarmPermission()
                result.success(true)
            }

            "requestFullScreenIntentPermission" -> {
                requestFullScreenIntentPermission()
                result.success(true)
            }

            else -> result.notImplemented()
        }
    }

    private fun scheduleAlarm(delaySeconds: Int, callerName: String, callerSubtitle: String, avatarIndex: Int) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return

        // 1. Cancel any existing pending alarm to prevent duplicate triggers
        cancelAlarm()

        if (delaySeconds <= 0) {
            // Immediate trigger requested ("Now")
            Log.i(TAG, "Triggering immediate fake call for '$callerName'")
            val intent = Intent(context, FakeCallReceiver::class.java).apply {
                action = FakeCallReceiver.ACTION_TRIGGER_FAKE_CALL
                putExtra(FakeCallReceiver.EXTRA_CALLER_NAME, callerName)
                putExtra(FakeCallReceiver.EXTRA_CALLER_SUBTITLE, callerSubtitle)
                putExtra(FakeCallReceiver.EXTRA_AVATAR_INDEX, avatarIndex)
            }
            context.sendBroadcast(intent)
            return
        }

        // 2. Compute trigger time and persist for reboot survival
        val triggerAtMillis = System.currentTimeMillis() + (delaySeconds * 1000L)
        FakeCallPreferences.saveScheduledCall(
            context,
            triggerAtMillis,
            callerName,
            callerSubtitle,
            avatarIndex,
        )

        // 3. Create PendingIntent & safely set alarm with AlarmManager
        val pendingIntent = createAlarmPendingIntent(context, callerName, callerSubtitle, avatarIndex)
        safeSetExactAlarm(context, alarmManager, triggerAtMillis, pendingIntent)
    }

    private fun cancelAlarm() {
        Log.d(TAG, "Cancelling scheduled alarm and clearing preferences")
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val intent = Intent(context, FakeCallReceiver::class.java).apply {
            action = FakeCallReceiver.ACTION_TRIGGER_FAKE_CALL
        }
        val flagImmutable = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            ALARM_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or flagImmutable,
        )
        alarmManager.cancel(pendingIntent)
        FakeCallPreferences.clearScheduledCall(context)
    }

    private fun checkPermissionsStatus(): Map<String, Boolean> {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager

        val hasNotification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }

        val hasExactAlarm = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            alarmManager?.canScheduleExactAlarms() ?: false
        } else {
            true
        }

        val hasFullScreen = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            notificationManager?.canUseFullScreenIntent() ?: false
        } else {
            true
        }

        return mapOf(
            "hasNotificationPermission" to hasNotification,
            "hasExactAlarmPermission" to hasExactAlarm,
            "hasFullScreenIntentPermission" to hasFullScreen,
        )
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val activity = context as? Activity
            if (activity != null) {
                ActivityCompat.requestPermissions(
                    activity,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    NOTIFICATION_PERMISSION_REQ_CODE,
                )
            } else {
                val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(intent)
            }
        }
    }

    private fun requestExactAlarmPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                    data = Uri.parse("package:${context.packageName}")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(intent)
            } catch (e: Throwable) {
                Log.w(TAG, "Cannot launch ACTION_REQUEST_SCHEDULE_EXACT_ALARM: ${e.message}")
            }
        }
    }

    private fun requestFullScreenIntentPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            try {
                val intent = Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT).apply {
                    data = Uri.parse("package:${context.packageName}")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(intent)
            } catch (e: Throwable) {
                Log.w(TAG, "Cannot launch ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT: ${e.message}")
            }
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        if (activeChannel == channel) {
            activeChannel = null
        }
    }
}

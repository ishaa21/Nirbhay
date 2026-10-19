package com.ishaa21.nirbhay

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorManager
import android.os.Build
import android.os.CountDownTimer
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.app.NotificationCompat

/**
 * Foreground Service for continuous background Shake-to-SOS monitoring.
 *
 * Runs a persistent low-priority foreground notification while monitoring sensors,
 * to comply with Android 9+ background sensor execution policies.
 *
 * When a valid shake is detected:
 * 1. Persists countdown state authoritatively in SharedPreferences.
 * 2. Launches ShakeCountdownActivity over the lock screen and over other apps.
 * 3. Posts a MAX-priority heads-up notification with a direct CANCEL SOS action
 *    (works outside the app via CancelSosReceiver BroadcastReceiver).
 * 4. Sets fullScreenIntent pointing to ShakeCountdownActivity (not MainActivity).
 * 5. Ticks countdown every second, broadcasts locally so the activity updates in real-time.
 * 6. If uncancelled after 15s, triggers the SOS emergency workflow exactly once.
 */
class ShakeDetectionService : Service() {

    companion object {
        const val PREFS_NAME = "nirbhay_shake_prefs"
        const val KEY_ENABLED = "shake_to_sos_enabled"
        const val KEY_SENSITIVITY = "shake_sensitivity"
        const val KEY_COUNTDOWN_ACTIVE = "countdown_active"
        const val KEY_COUNTDOWN_END_TIME = "countdown_end_time"
        const val KEY_LAST_TRIGGER_TIME = "last_trigger_time"

        const val ACTION_START = "com.ishaa21.nirbhay.ACTION_START_SHAKE_SERVICE"
        const val ACTION_STOP = "com.ishaa21.nirbhay.ACTION_STOP_SHAKE_SERVICE"
        const val ACTION_CANCEL_COUNTDOWN = "com.ishaa21.nirbhay.ACTION_CANCEL_COUNTDOWN"
        const val ACTION_TRIGGER_SOS_NOW = "com.ishaa21.nirbhay.ACTION_TRIGGER_SOS_NOW"
        // Local broadcast action for sending tick updates to ShakeCountdownActivity
        const val ACTION_COUNTDOWN_TICK = "com.ishaa21.nirbhay.ACTION_COUNTDOWN_TICK"

        const val CHANNEL_MONITOR_ID = "nirbhay_shake_monitor_channel"
        const val CHANNEL_COUNTDOWN_ID = "nirbhay_sos_countdown_channel"
        const val NOTIFICATION_MONITOR_ID = 9101
        const val NOTIFICATION_COUNTDOWN_ID = 9102

        const val COUNTDOWN_DURATION_MS = 15000L

        private var activeServiceInstance: ShakeDetectionService? = null

        fun cancelCountdown(context: Context) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putBoolean(KEY_COUNTDOWN_ACTIVE, false).apply()

            // Cancel the in-service CountDownTimer
            activeServiceInstance?.handleCancellationInternal()

            // Dismiss countdown notification
            val notificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(NOTIFICATION_COUNTDOWN_ID)

            // Notify Flutter via plugin if app is running
            NirbhayShakePlugin.onCountdownCancelled()

            // Broadcast locally so ShakeCountdownActivity dismisses itself immediately
            val dismissIntent = Intent(ACTION_CANCEL_COUNTDOWN)
            context.sendBroadcast(dismissIntent)
        }

        fun isCountdownActive(context: Context): Boolean {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val active = prefs.getBoolean(KEY_COUNTDOWN_ACTIVE, false)
            if (!active) return false
            val endTime = prefs.getLong(KEY_COUNTDOWN_END_TIME, 0L)
            return System.currentTimeMillis() < endTime
        }

        fun getRemainingSeconds(context: Context): Int {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val endTime = prefs.getLong(KEY_COUNTDOWN_END_TIME, 0L)
            val remainingMs = endTime - System.currentTimeMillis()
            return if (remainingMs > 0) ((remainingMs + 999) / 1000).toInt() else 0
        }
    }

    private lateinit var sensorManager: SensorManager
    private var accelerometer: Sensor? = null
    private var shakeDetector: ShakeDetector? = null
    private var countDownTimer: CountDownTimer? = null
    private var vibrator: Vibrator? = null

    override fun onCreate() {
        super.onCreate()
        activeServiceInstance = this
        createNotificationChannels()

        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)

        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager =
                getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibratorManager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }

        shakeDetector = ShakeDetector {
            onShakeDetected()
        }

        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val sensitivityStr = prefs.getString(KEY_SENSITIVITY, "DEFAULT") ?: "DEFAULT"
        applySensitivity(sensitivityStr)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        when (action) {
            ACTION_STOP -> {
                stopForegroundMonitoring()
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_CANCEL_COUNTDOWN -> {
                cancelCountdown(this)
            }
            else -> {
                startForegroundMonitoring()
                registerSensorListener()
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        activeServiceInstance = null
        unregisterSensorListener()
        countDownTimer?.cancel()
        countDownTimer = null
        super.onDestroy()
    }

    private fun startForegroundMonitoring() {
        val monitorNotification = buildMonitoringNotification()
        startForeground(NOTIFICATION_MONITOR_ID, monitorNotification)
    }

    private fun stopForegroundMonitoring() {
        unregisterSensorListener()
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putBoolean(KEY_ENABLED, false)
            .putBoolean(KEY_COUNTDOWN_ACTIVE, false)
            .apply()
        stopForeground(STOP_FOREGROUND_REMOVE)
    }

    private fun registerSensorListener() {
        accelerometer?.let {
            sensorManager.registerListener(
                shakeDetector,
                it,
                SensorManager.SENSOR_DELAY_UI,
            )
        }
    }

    private fun unregisterSensorListener() {
        shakeDetector?.let {
            sensorManager.unregisterListener(it)
        }
    }

    fun applySensitivity(sensitivityStr: String) {
        val level = try {
            ShakeDetector.Sensitivity.valueOf(sensitivityStr.uppercase())
        } catch (_: Exception) {
            ShakeDetector.Sensitivity.DEFAULT
        }
        shakeDetector?.sensitivity = level
    }

    private fun onShakeDetected() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val currentlyActive = prefs.getBoolean(KEY_COUNTDOWN_ACTIVE, false)
        val endTime = prefs.getLong(KEY_COUNTDOWN_END_TIME, 0L)
        val now = System.currentTimeMillis()

        // Guard against duplicate active countdowns
        if (currentlyActive && now < endTime) {
            return
        }

        val countdownEnd = now + COUNTDOWN_DURATION_MS
        prefs.edit()
            .putBoolean(KEY_COUNTDOWN_ACTIVE, true)
            .putLong(KEY_COUNTDOWN_END_TIME, countdownEnd)
            .putLong(KEY_LAST_TRIGGER_TIME, now)
            .apply()

        // Haptic warning alert
        vibrateWarning()

        // Post heads-up notification with CANCEL SOS action and full-screen intent
        // pointing at ShakeCountdownActivity (not MainActivity).
        showCountdownNotification(15)

        // Launch ShakeCountdownActivity immediately — this is the primary
        // presentation path for lock-screen and over-other-apps display.
        launchCountdownActivity(15)

        // Notify Flutter via plugin if app is running
        NirbhayShakePlugin.onCountdownStarted(countdownEnd, 15)

        // Start 15s countdown
        countDownTimer?.cancel()
        countDownTimer = object : CountDownTimer(COUNTDOWN_DURATION_MS, 1000L) {
            override fun onTick(millisUntilFinished: Long) {
                val remainingSec = ((millisUntilFinished + 999) / 1000).toInt()
                if (isCountdownActive(this@ShakeDetectionService)) {
                    // Update the notification text
                    updateCountdownNotification(remainingSec)
                    // Broadcast tick locally so ShakeCountdownActivity updates in real-time
                    broadcastTick(remainingSec)
                    // Also notify Flutter via EventChannel (if app is foreground)
                    NirbhayShakePlugin.onCountdownTick(remainingSec)
                }
            }

            override fun onFinish() {
                val active = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    .getBoolean(KEY_COUNTDOWN_ACTIVE, false)
                if (active) {
                    onCountdownExpired()
                }
            }
        }.start()
    }

    private fun launchCountdownActivity(remainingSeconds: Int) {
        try {
            val intent = Intent(this, ShakeCountdownActivity::class.java).apply {
                putExtra("remainingSeconds", remainingSeconds)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            }
            startActivity(intent)
        } catch (e: Exception) {
            // If startActivity fails (e.g. background activity restrictions),
            // the heads-up notification with CANCEL action is still displayed.
            android.util.Log.w("ShakeService", "Could not launch ShakeCountdownActivity: ${e.message}")
        }
    }

    private fun broadcastTick(remainingSeconds: Int) {
        val intent = Intent(ACTION_COUNTDOWN_TICK).apply {
            putExtra("remainingSeconds", remainingSeconds)
            setPackage(packageName) // Restrict to our own app process only
        }
        sendBroadcast(intent)
    }

    private fun handleCancellationInternal() {
        countDownTimer?.cancel()
        countDownTimer = null
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(NOTIFICATION_COUNTDOWN_ID)
    }

    private fun onCountdownExpired() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(KEY_COUNTDOWN_ACTIVE, false).apply()

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(NOTIFICATION_COUNTDOWN_ID)

        // Trigger SOS workflow via Flutter event channel (if Flutter is active)
        NirbhayShakePlugin.onCountdownExpired()

        // Launch MainActivity so the SOS workflow is executed by Flutter even if app was closed.
        // The pendingSosTrigger in NirbhayShakePlugin ensures the event is re-fired
        // once Flutter Engine is attached.
        try {
            val intent = Intent(this, MainActivity::class.java).apply {
                action = ACTION_TRIGGER_SOS_NOW
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            startActivity(intent)
        } catch (e: Exception) {
            android.util.Log.w("ShakeService", "Could not launch MainActivity for SOS: ${e.message}")
        }
    }

    private fun buildMonitoringNotification(): Notification {
        val openAppIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        return NotificationCompat.Builder(this, CHANNEL_MONITOR_ID)
            .setContentTitle("Nirbhay Shake Detection Active")
            .setContentText("Emergency shake detection is running in the background.")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun showCountdownNotification(remainingSeconds: Int) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // CANCEL SOS action: sends broadcast to CancelSosReceiver — works without opening the app.
        val cancelIntent = Intent(this, CancelSosReceiver::class.java).apply {
            action = CancelSosReceiver.ACTION_CANCEL_SOS
        }
        val cancelPendingIntent = PendingIntent.getBroadcast(
            this,
            1,
            cancelIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        // Full-screen intent: launches ShakeCountdownActivity over lock screen.
        // This is the correct implementation — the full-screen intent target must be
        // a dedicated Activity (ShakeCountdownActivity), NOT MainActivity, to avoid
        // interrupting the running Flutter UI unnecessarily.
        val fullScreenIntent = Intent(this, ShakeCountdownActivity::class.java).apply {
            putExtra("remainingSeconds", remainingSeconds)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
        }
        val fullScreenPendingIntent = PendingIntent.getActivity(
            this,
            2,
            fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_COUNTDOWN_ID)
            .setContentTitle("🚨 EMERGENCY SOS COUNTDOWN")
            .setContentText("Shake detected! SOS alert will send in $remainingSeconds seconds.")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setOngoing(true)
            .setAutoCancel(false)
            // Full-screen intent attempts to show ShakeCountdownActivity on lock screen.
            // On Android 14+ this requires MANAGE_MEDIA_PROJECTION or USE_FULL_SCREEN_INTENT
            // to be granted by the user. If not granted, the notification is displayed as
            // a heads-up notification with the CANCEL SOS action button still present.
            .setFullScreenIntent(fullScreenPendingIntent, true)
            // Tapping the notification body also opens the countdown activity
            .setContentIntent(fullScreenPendingIntent)
            // CANCEL SOS notification action: works even when phone is locked
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "CANCEL SOS",
                cancelPendingIntent,
            )
            .build()

        notificationManager.notify(NOTIFICATION_COUNTDOWN_ID, notification)
    }

    private fun updateCountdownNotification(remainingSeconds: Int) {
        showCountdownNotification(remainingSeconds)
    }

    private fun vibrateWarning() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val timings = longArrayOf(0, 350, 150, 350, 150, 350)
                val amplitudes = intArrayOf(0, 255, 0, 255, 0, 255)
                vibrator?.vibrate(VibrationEffect.createWaveform(timings, amplitudes, -1))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(longArrayOf(0, 350, 150, 350, 150, 350), -1)
            }
        } catch (_: Exception) {
        }
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // Monitoring channel (silent, low priority)
            val monitorChannel = NotificationChannel(
                CHANNEL_MONITOR_ID,
                "Shake Detection Service",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Ongoing background monitoring for Nirbhay shake detection"
                setShowBadge(false)
            }

            // Countdown channel: must be IMPORTANCE_HIGH to trigger heads-up and
            // allow the system to attempt full-screen intent display on lock screen.
            val countdownChannel = NotificationChannel(
                CHANNEL_COUNTDOWN_ID,
                "Emergency SOS Countdown",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Active 15-second SOS countdown after shake detection"
                enableVibration(true)
                setShowBadge(true)
            }

            notificationManager.createNotificationChannel(monitorChannel)
            notificationManager.createNotificationChannel(countdownChannel)
        }
    }
}

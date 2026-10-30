package com.ishaa21.nirbhay

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Handles scheduled Fake Call alarms and notification actions (Accept / Decline / Dismiss).
 * Works reliably when Nirbhay is in the foreground, background, removed from recent apps,
 * or when the device screen is locked.
 */
class FakeCallReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "NirbhayFakeCall"

        const val ACTION_TRIGGER_FAKE_CALL = "com.ishaa21.nirbhay.ACTION_TRIGGER_FAKE_CALL"
        const val ACTION_DISMISS_FAKE_CALL = "com.ishaa21.nirbhay.ACTION_DISMISS_FAKE_CALL"
        const val ACTION_ACCEPT_FAKE_CALL = "com.ishaa21.nirbhay.ACTION_ACCEPT_FAKE_CALL"

        const val EXTRA_CALLER_NAME = "callerName"
        const val EXTRA_CALLER_SUBTITLE = "callerSubtitle"
        const val EXTRA_AVATAR_INDEX = "avatarIndex"
        const val EXTRA_IS_ACCEPTED = "isAccepted"

        const val CHANNEL_ID = "nirbhay_fake_call_channel"
        const val NOTIFICATION_ID = 2004

        private var activeMediaPlayer: MediaPlayer? = null
        private var activeVibrator: Vibrator? = null
        private var wakeLock: PowerManager.WakeLock? = null

        fun stopRingtone(context: Context) {
            Log.d(TAG, "Stopping fake call ringtone, vibration, and notification")
            try {
                activeMediaPlayer?.stop()
                activeMediaPlayer?.release()
                activeMediaPlayer = null
            } catch (e: Throwable) {
                Log.w(TAG, "Error stopping media player: ${e.message}")
            }

            try {
                activeVibrator?.cancel()
                activeVibrator = null
            } catch (e: Throwable) {
                Log.w(TAG, "Error stopping vibrator: ${e.message}")
            }

            try {
                if (wakeLock?.isHeld == true) {
                    wakeLock?.release()
                }
                wakeLock = null
            } catch (e: Throwable) {
                Log.w(TAG, "Error releasing wake lock: ${e.message}")
            }

            try {
                val notificationManager =
                    context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                notificationManager?.cancel(NOTIFICATION_ID)
            } catch (e: Throwable) {
                Log.w(TAG, "Error cancelling notification: ${e.message}")
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        Log.i(TAG, "FakeCallReceiver.onReceive: action=$action")

        when (action) {
            ACTION_TRIGGER_FAKE_CALL -> {
                val callerName = intent.getStringExtra(EXTRA_CALLER_NAME) ?: "Mom"
                val callerSubtitle = intent.getStringExtra(EXTRA_CALLER_SUBTITLE) ?: "Mobile"
                val avatarIndex = intent.getIntExtra(EXTRA_AVATAR_INDEX, 0)

                // Clear armed state from SharedPreferences so reboot won't re-trigger it
                FakeCallPreferences.clearScheduledCall(context)

                triggerIncomingCallNotification(context, callerName, callerSubtitle, avatarIndex)

                // If Flutter Engine is already active in memory, inform it immediately
                NirbhayFakeCallPlugin.sendTriggerEventToFlutter(callerName, callerSubtitle, false)
            }

            ACTION_DISMISS_FAKE_CALL -> {
                Log.i(TAG, "Fake call dismissed/declined by user")
                stopRingtone(context)
                FakeCallPreferences.clearScheduledCall(context)
                NirbhayFakeCallPlugin.sendCancelEventToFlutter()
            }

            ACTION_ACCEPT_FAKE_CALL -> {
                Log.i(TAG, "Fake call accepted by user from notification action")
                stopRingtone(context)
                FakeCallPreferences.clearScheduledCall(context)

                val callerName = intent.getStringExtra(EXTRA_CALLER_NAME) ?: "Mom"
                val callerSubtitle = intent.getStringExtra(EXTRA_CALLER_SUBTITLE) ?: "Mobile"

                // Launch MainActivity directly into connected call state
                val launchIntent = Intent(context, MainActivity::class.java).apply {
                    this.action = ACTION_ACCEPT_FAKE_CALL
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP
                    putExtra(EXTRA_CALLER_NAME, callerName)
                    putExtra(EXTRA_CALLER_SUBTITLE, callerSubtitle)
                    putExtra(EXTRA_IS_ACCEPTED, true)
                }
                context.startActivity(launchIntent)

                // Also notify active engine if running
                NirbhayFakeCallPlugin.sendTriggerEventToFlutter(callerName, callerSubtitle, true)
            }
        }
    }

    private fun triggerIncomingCallNotification(
        context: Context,
        callerName: String,
        callerSubtitle: String,
        avatarIndex: Int,
    ) {
        Log.d(TAG, "triggerIncomingCallNotification: callerName='$callerName', subtitle='$callerSubtitle'")

        // 1. Acquire WakeLock to turn on the screen and keep CPU active for ringtone
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        try {
            @Suppress("DEPRECATION")
            val screenWakeLock = powerManager?.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                        PowerManager.ACQUIRE_CAUSES_WAKEUP or
                        PowerManager.ON_AFTER_RELEASE,
                "nirbhay:fake_call_screen_wakelock",
            )
            screenWakeLock?.acquire(10000) // Keep screen lit for 10 seconds to display keyguard call
        } catch (e: Throwable) {
            Log.w(TAG, "Screen wakelock failed: ${e.message}")
        }

        wakeLock = powerManager?.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "nirbhay:fake_call_wakelock",
        )?.apply {
            setReferenceCounted(false)
            acquire(35000) // Max 35 seconds ring duration
        }

        // 2. Setup Notification Channel for Incoming Call
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val ringtoneUri: Uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val audioAttributes = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                .build()

            val channel = NotificationChannel(
                CHANNEL_ID,
                LocaleHelper.getString(context, R.string.fake_call_channel_name),
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = LocaleHelper.getString(context, R.string.fake_call_channel_desc)
                enableLights(true)
                lightColor = Color.GREEN
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 1000, 800, 1000, 800)
                setSound(ringtoneUri, audioAttributes)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            }
            notificationManager.createNotificationChannel(channel)
        }

        // 3. Setup Full Screen Intent and Actions
        val fullScreenIntent = Intent(context, MainActivity::class.java).apply {
            action = ACTION_TRIGGER_FAKE_CALL
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(EXTRA_CALLER_NAME, callerName)
            putExtra(EXTRA_CALLER_SUBTITLE, callerSubtitle)
            putExtra(EXTRA_AVATAR_INDEX, avatarIndex)
            putExtra(EXTRA_IS_ACCEPTED, false)
        }

        val flagImmutable = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        val fullScreenPendingIntent = PendingIntent.getActivity(
            context,
            201,
            fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or flagImmutable,
        )

        // Accept Action PendingIntent (Broadcast to receiver)
        val acceptIntent = Intent(context, FakeCallReceiver::class.java).apply {
            action = ACTION_ACCEPT_FAKE_CALL
            putExtra(EXTRA_CALLER_NAME, callerName)
            putExtra(EXTRA_CALLER_SUBTITLE, callerSubtitle)
        }
        val acceptPendingIntent = PendingIntent.getBroadcast(
            context,
            202,
            acceptIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or flagImmutable,
        )

        // Decline Action PendingIntent (Broadcast to receiver)
        val declineIntent = Intent(context, FakeCallReceiver::class.java).apply {
            action = ACTION_DISMISS_FAKE_CALL
        }
        val declinePendingIntent = PendingIntent.getBroadcast(
            context,
            203,
            declineIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or flagImmutable,
        )

        // 4. Generate avatar large icon
        val avatarBitmap = createCallerAvatarBitmap(callerName, avatarIndex)

        // 5. Build High-Priority Call Notification
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.sym_call_incoming)
            .setLargeIcon(avatarBitmap)
            .setContentTitle(callerName)
            .setContentText(LocaleHelper.getString(context, R.string.fake_call_incoming_text, callerSubtitle))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setOngoing(true)
            .setContentIntent(fullScreenPendingIntent)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setDeleteIntent(declinePendingIntent)
            .addAction(android.R.drawable.ic_menu_call, LocaleHelper.getString(context, R.string.fake_call_action_accept), acceptPendingIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, LocaleHelper.getString(context, R.string.fake_call_action_decline), declinePendingIntent)
            .build()

        try {
            notificationManager.notify(NOTIFICATION_ID, notification)
            Log.i(TAG, "Posted incoming call notification ID=$NOTIFICATION_ID")
        } catch (e: SecurityException) {
            Log.e(TAG, "SecurityException posting notification (POST_NOTIFICATIONS missing): ${e.message}")
        } catch (e: Throwable) {
            Log.e(TAG, "Error posting notification: ${e.message}", e)
        }

        // 6. Play looping ringtone via MediaPlayer for reliable background audio
        try {
            stopRingtone(context)
            val mp = MediaPlayer().apply {
                setDataSource(context, ringtoneUri)
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                isLooping = true
                prepare()
                start()
            }
            activeMediaPlayer = mp
        } catch (e: Throwable) {
            Log.w(TAG, "Could not start MediaPlayer ringtone: ${e.message}")
        }

        // 7. Loop native vibration
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vm?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }

            val pattern = longArrayOf(0, 1000, 800, 1000, 800)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(pattern, 0)
            }
            activeVibrator = vibrator
        } catch (e: Throwable) {
            Log.w(TAG, "Could not start vibration: ${e.message}")
        }
    }

    /**
     * Generates a circular avatar bitmap with caller initials for notification largeIcon.
     */
    private fun createCallerAvatarBitmap(name: String, avatarIndex: Int): Bitmap {
        val size = 128
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val colors = intArrayOf(
            Color.parseColor("#301427"),
            Color.parseColor("#C2185B"),
            Color.parseColor("#303F9F"),
            Color.parseColor("#37474F"),
            Color.parseColor("#1565C0"),
            Color.parseColor("#00796B"),
        )
        val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = colors[avatarIndex.coerceIn(0, colors.size - 1)]
            style = Paint.Style.FILL
        }

        canvas.drawCircle(size / 2f, size / 2f, size / 2f, bgPaint)

        val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textSize = 54f
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            textAlign = Paint.Align.CENTER
        }

        val initial = if (name.isNotBlank()) name.take(1).uppercase() else "?"
        val yPos = (size / 2f) - ((textPaint.descent() + textPaint.ascent()) / 2f)
        canvas.drawText(initial, size / 2f, yPos, textPaint)

        return bitmap
    }
}

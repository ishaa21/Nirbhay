package com.ishaa21.nirbhay

import android.app.Activity
import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.view.animation.AlphaAnimation
import android.view.animation.Animation
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast

/**
 * Dedicated native countdown Activity presented instantly when a deliberate shake is detected.
 *
 * Designed to display over the lock screen (keyguard) and over other apps without requiring
 * Flutter Engine initialization. Provides an immediate, authoritative "CANCEL SOS" action.
 */
class ShakeCountdownActivity : Activity() {

    private lateinit var timerTextView: TextView
    private lateinit var statusTextView: TextView
    private lateinit var cancelButton: Button
    private lateinit var iconView: ImageView

    private var vibrator: Vibrator? = null
    private val handler = Handler(Looper.getMainLooper())
    private var isReceiverRegistered = false

    private val countdownReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                ShakeDetectionService.ACTION_COUNTDOWN_TICK -> {
                    val remaining = intent.getIntExtra("remainingSeconds", -1)
                    if (remaining >= 0) {
                        updateCountdownDisplay(remaining)
                    }
                }
                ShakeDetectionService.ACTION_CANCEL_COUNTDOWN -> {
                    finish()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        configureWindowForLockscreenAndOverlay()

        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibratorManager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }

        buildProgrammaticUi()

        val filter = IntentFilter().apply {
            addAction(ShakeDetectionService.ACTION_COUNTDOWN_TICK)
            addAction(ShakeDetectionService.ACTION_CANCEL_COUNTDOWN)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(countdownReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(countdownReceiver, filter)
        }
        isReceiverRegistered = true

        val initialSeconds = intent?.getIntExtra("remainingSeconds", 15) ?: 15
        updateCountdownDisplay(initialSeconds)
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        setIntent(intent)
        val remaining = intent?.getIntExtra("remainingSeconds", 15) ?: 15
        updateCountdownDisplay(remaining)
    }

    override fun onDestroy() {
        if (isReceiverRegistered) {
            try {
                unregisterReceiver(countdownReceiver)
            } catch (_: Exception) {}
            isReceiverRegistered = false
        }
        super.onDestroy()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // Tapping back button authoritatively cancels countdown
        handleCancel()
    }

    private fun configureWindowForLockscreenAndOverlay() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
            keyguardManager?.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    private fun buildProgrammaticUi() {
        // Root container with semi-transparent dark backdrop
        val rootLayout = FrameLayout(this).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            setBackgroundColor(Color.parseColor("#B3000000")) // 70% black dim
            setPadding(dp(24), dp(24), dp(24), dp(24))
        }

        // Card dialog container
        val cardLayout = LinearLayout(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.CENTER
            }
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(24), dp(32), dp(24), dp(32))

            val shape = GradientDrawable().apply {
                cornerRadius = dp(24).toFloat()
                setColor(Color.parseColor("#1E0A16")) // Deep Burgundy card background
                setStroke(dp(2), Color.parseColor("#D32F2F")) // Red emergency border
            }
            background = shape
            elevation = dp(16).toFloat()
        }

        // Emergency Warning Icon
        iconView = ImageView(this).apply {
            layoutParams = LinearLayout.LayoutParams(dp(48), dp(48)).apply {
                bottomMargin = dp(12)
            }
            setImageResource(android.R.drawable.ic_dialog_alert)
            setColorFilter(Color.parseColor("#FF5252"))
        }
        cardLayout.addView(iconView)

        // Pulsing animation on icon
        val pulseAnimation = AlphaAnimation(0.4f, 1.0f).apply {
            duration = 500
            repeatMode = Animation.REVERSE
            repeatCount = Animation.INFINITE
        }
        iconView.startAnimation(pulseAnimation)

        // Header Title
        val titleView = TextView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dp(8)
            }
            text = "SHAKE DETECTED"
            setTextColor(Color.WHITE)
            textSize = 20f
            typeface = Typeface.DEFAULT_BOLD
            letterSpacing = 0.1f
            gravity = Gravity.CENTER
        }
        cardLayout.addView(titleView)

        // Subtitle
        statusTextView = TextView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dp(24)
            }
            text = "Emergency SOS alert will send in:"
            setTextColor(Color.parseColor("#D1C3C9"))
            textSize = 14f
            gravity = Gravity.CENTER
        }
        cardLayout.addView(statusTextView)

        // Large Countdown Timer Display
        timerTextView = TextView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dp(4)
            }
            text = "15"
            setTextColor(Color.parseColor("#FF5252"))
            textSize = 64f
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            gravity = Gravity.CENTER
        }
        cardLayout.addView(timerTextView)

        val secondsLabel = TextView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dp(32)
            }
            text = "SECONDS"
            setTextColor(Color.parseColor("#FF8A80"))
            textSize = 12f
            typeface = Typeface.DEFAULT_BOLD
            letterSpacing = 0.15f
            gravity = Gravity.CENTER
        }
        cardLayout.addView(secondsLabel)

        // Prominent Cancel Button
        cancelButton = Button(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(56)
            )
            text = "CANCEL SOS (I AM SAFE)"
            setTextColor(Color.WHITE)
            textSize = 16f
            typeface = Typeface.DEFAULT_BOLD

            val btnShape = GradientDrawable().apply {
                cornerRadius = dp(16).toFloat()
                setColor(Color.parseColor("#2E7D32")) // Green safe button
            }
            background = btnShape
            elevation = dp(6).toFloat()

            setOnClickListener {
                handleCancel()
            }
        }
        cardLayout.addView(cancelButton)

        rootLayout.addView(cardLayout)
        setContentView(rootLayout)
    }

    private fun updateCountdownDisplay(seconds: Int) {
        if (!isFinishing) {
            timerTextView.text = seconds.toString()
            if (seconds <= 0) {
                finish()
            } else {
                tickVibration()
            }
        }
    }

    private fun tickVibration() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createOneShot(50, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(50)
            }
        } catch (_: Exception) {}
    }

    private fun handleCancel() {
        cancelButton.isEnabled = false
        cancelButton.text = "CANCELLING..."
        ShakeDetectionService.cancelCountdown(this)
        Toast.makeText(this, "Emergency SOS cancelled. No alerts sent.", Toast.LENGTH_SHORT).show()
        finish()
    }

    private fun dp(value: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            resources.displayMetrics
        ).toInt()
    }
}

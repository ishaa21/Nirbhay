package com.ishaa21.nirbhay

import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import kotlin.math.sqrt

/**
 * Robust sensor-based shake detector for personal emergency alerts.
 *
 * Distinguishes deliberate shakes from normal walking, sitting, or pocket jostles by:
 * 1. Filtering linear acceleration magnitude (|total_a - 9.81|).
 * 2. Requiring rapid directional reversals within a sliding time window (600 - 1000ms).
 * 3. Enforcing a post-shake cooldown period to prevent duplicate triggers.
 */
class ShakeDetector(
    private val onShakeListener: () -> Unit,
) : SensorEventListener {

    enum class Sensitivity(val threshold: Float, val requiredReversals: Int) {
        LOW(17.5f, 4),
        DEFAULT(14.0f, 3),
        HIGH(11.5f, 3),
    }

    var sensitivity: Sensitivity = Sensitivity.DEFAULT

    private var lastTimeNs: Long = 0
    private var lastAccelerationX: Float = 0f
    private var lastAccelerationY: Float = 0f
    private var lastAccelerationZ: Float = 0f

    private var reversalCount: Int = 0
    private var windowStartTimeMs: Long = 0
    private var lastTriggerTimeMs: Long = 0

    // Cooldown prevents immediate re-triggering (3 seconds)
    private val cooldownMs: Long = 3000L
    // Window in which reversals must occur
    private val windowDurationMs: Long = 1000L

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // No-op
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null || event.sensor.type != Sensor.TYPE_ACCELEROMETER) return

        val nowMs = System.currentTimeMillis()
        if (nowMs - lastTriggerTimeMs < cooldownMs) {
            return
        }

        val x = event.values[0]
        val y = event.values[1]
        val z = event.values[2]

        // Calculate total acceleration magnitude minus standard Earth gravity (9.81)
        val totalMagnitude = sqrt((x * x + y * y + z * z).toDouble()).toFloat()
        val netAcceleration = kotlin.math.abs(totalMagnitude - 9.81f)

        // Check if movement exceeds acceleration threshold
        if (netAcceleration >= sensitivity.threshold) {
            // Check for directional reversal
            val reversedX = (x > 0 && lastAccelerationX < 0) || (x < 0 && lastAccelerationX > 0)
            val reversedY = (y > 0 && lastAccelerationY < 0) || (y < 0 && lastAccelerationY > 0)
            val reversedZ = (z > 0 && lastAccelerationZ < 0) || (z < 0 && lastAccelerationZ > 0)

            if (reversedX || reversedY || reversedZ) {
                if (reversalCount == 0 || (nowMs - windowStartTimeMs > windowDurationMs)) {
                    reversalCount = 1
                    windowStartTimeMs = nowMs
                } else {
                    reversalCount++
                }

                if (reversalCount >= sensitivity.requiredReversals && (nowMs - windowStartTimeMs <= windowDurationMs)) {
                    lastTriggerTimeMs = nowMs
                    reversalCount = 0
                    onShakeListener()
                }
            }
        }

        lastAccelerationX = x
        lastAccelerationY = y
        lastAccelerationZ = z
        lastTimeNs = event.timestamp
    }

    fun reset() {
        reversalCount = 0
        windowStartTimeMs = 0
    }
}

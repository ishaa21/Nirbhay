package com.ishaa21.nirbhay

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.content.ContextCompat

/**
 * Resumes background shake detection and reschedules valid future Fake Calls on device reboot.
 * Expired calls that elapsed while the device was off or rebooting are discarded to prevent
 * confusing phantom calls.
 *
 * Note: If the app is force-stopped by the user via Android Settings, the OS places
 * the app in a stopped state where receivers cannot run until the app is opened again.
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "NirbhayBootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action
        Log.d(TAG, "BootReceiver triggered with action: $action")

        if (action == Intent.ACTION_BOOT_COMPLETED || action == "android.intent.action.QUICKBOOT_POWERON") {
            // 1. Resumes background shake detection if user enabled it
            try {
                val prefs = context.getSharedPreferences(ShakeDetectionService.PREFS_NAME, Context.MODE_PRIVATE)
                val isEnabled = prefs.getBoolean(ShakeDetectionService.KEY_ENABLED, false)
                if (isEnabled) {
                    val serviceIntent = Intent(context, ShakeDetectionService::class.java).apply {
                        this.action = ShakeDetectionService.ACTION_START
                    }
                    ContextCompat.startForegroundService(context, serviceIntent)
                    Log.i(TAG, "Restored ShakeDetectionService after reboot")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error restoring ShakeDetectionService: ${e.message}", e)
            }

            // 2. Reschedule valid future Fake Call if one was pending before reboot
            try {
                if (FakeCallPreferences.isArmed(context)) {
                    val triggerAtMillis = FakeCallPreferences.getTriggerAtMillis(context)
                    val now = System.currentTimeMillis()

                    if (triggerAtMillis > now) {
                        val callerName = FakeCallPreferences.getCallerName(context)
                        val callerSubtitle = FakeCallPreferences.getCallerSubtitle(context)
                        val avatarIndex = FakeCallPreferences.getAvatarIndex(context)
                        val delaySeconds = ((triggerAtMillis - now) / 1000).toInt()

                        Log.i(TAG, "Rescheduling valid future fake call for '$callerName' in ${delaySeconds}s")
                        NirbhayFakeCallPlugin.rescheduleAlarm(
                            context,
                            triggerAtMillis,
                            callerName,
                            callerSubtitle,
                            avatarIndex,
                        )
                    } else {
                        Log.i(TAG, "Pending fake call expired while device was powered off; clearing without replay")
                        FakeCallPreferences.clearScheduledCall(context)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error checking/rescheduling fake call after reboot: ${e.message}", e)
            }
        }
    }
}

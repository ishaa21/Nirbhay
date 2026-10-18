package com.ishaa21.nirbhay

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

/**
 * Resumes background shake detection on device reboot if the user has enabled it.
 * Note: If the app is force-stopped by the user via Android Settings, the OS places
 * the app in a stopped state where receivers cannot run until the app is opened again.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action
        if (action == Intent.ACTION_BOOT_COMPLETED || action == "android.intent.action.QUICKBOOT_POWERON") {
            val prefs = context.getSharedPreferences(ShakeDetectionService.PREFS_NAME, Context.MODE_PRIVATE)
            val isEnabled = prefs.getBoolean(ShakeDetectionService.KEY_ENABLED, false)
            if (isEnabled) {
                val serviceIntent = Intent(context, ShakeDetectionService::class.java).apply {
                    this.action = ShakeDetectionService.ACTION_START
                }
                ContextCompat.startForegroundService(context, serviceIntent)
            }
        }
    }
}

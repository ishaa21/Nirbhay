package com.ishaa21.nirbhay

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Authoritative receiver for cancelling active Shake-to-SOS countdowns.
 * Invoked directly from the "CANCEL SOS" notification action button
 * or internal broadcast without requiring the app UI to open first.
 */
class CancelSosReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_CANCEL_SOS = "com.ishaa21.nirbhay.ACTION_CANCEL_SOS"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action == ACTION_CANCEL_SOS) {
            ShakeDetectionService.cancelCountdown(context)
        }
    }
}

package com.ishaa21.nirbhay

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "NirbhayMainActivity"
    }

    private var smsPlugin: NirbhaySmsPlugin? = null
    private var shakePlugin: NirbhayShakePlugin? = null
    private var fakeCallPlugin: NirbhayFakeCallPlugin? = null
    private var routeAlertPlugin: NirbhayRouteAlertPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.d(TAG, "configureFlutterEngine")
        smsPlugin = NirbhaySmsPlugin(this, flutterEngine)
        shakePlugin = NirbhayShakePlugin(this, flutterEngine)
        fakeCallPlugin = NirbhayFakeCallPlugin(this, flutterEngine)
        routeAlertPlugin = NirbhayRouteAlertPlugin(this, flutterEngine)
        handleIntent(intent)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        configureWindowForLockscreen()
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        configureWindowForLockscreen()
        handleIntent(intent)
    }

    /**
     * Wakes the screen and displays over the Android keyguard / lock screen.
     */
    private fun configureWindowForLockscreen() {
        Log.d(TAG, "configureWindowForLockscreen called")
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
                        WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action
        Log.i(TAG, "handleIntent: action=$action")

        if (action == ShakeDetectionService.ACTION_TRIGGER_SOS_NOW) {
            shakePlugin?.triggerSosFromIntent()
        } else if (action == FakeCallReceiver.ACTION_TRIGGER_FAKE_CALL) {
            val callerName = intent.getStringExtra(FakeCallReceiver.EXTRA_CALLER_NAME) ?: "Mom"
            val callerSubtitle = intent.getStringExtra(FakeCallReceiver.EXTRA_CALLER_SUBTITLE) ?: "Mobile"

            NirbhayFakeCallPlugin.pendingTriggerCallerName = callerName
            NirbhayFakeCallPlugin.pendingTriggerCallerSubtitle = callerSubtitle
            NirbhayFakeCallPlugin.isAcceptedFromNotification = false

            Log.i(TAG, "ACTION_TRIGGER_FAKE_CALL for '$callerName' ($callerSubtitle)")
            NirbhayFakeCallPlugin.sendTriggerEventToFlutter(callerName, callerSubtitle, false)
        } else if (action == FakeCallReceiver.ACTION_ACCEPT_FAKE_CALL) {
            val callerName = intent.getStringExtra(FakeCallReceiver.EXTRA_CALLER_NAME) ?: "Mom"
            val callerSubtitle = intent.getStringExtra(FakeCallReceiver.EXTRA_CALLER_SUBTITLE) ?: "Mobile"

            NirbhayFakeCallPlugin.pendingTriggerCallerName = callerName
            NirbhayFakeCallPlugin.pendingTriggerCallerSubtitle = callerSubtitle
            NirbhayFakeCallPlugin.isAcceptedFromNotification = true

            Log.i(TAG, "ACTION_ACCEPT_FAKE_CALL for '$callerName' ($callerSubtitle)")
            NirbhayFakeCallPlugin.sendTriggerEventToFlutter(callerName, callerSubtitle, true)
        } else if (action == NirbhayRouteAlertPlugin.ACTION_VIEW_HOTSPOT) {
            val hotspotId = intent.getStringExtra(NirbhayRouteAlertPlugin.EXTRA_HOTSPOT_ID)
            val lat = intent.getDoubleExtra(NirbhayRouteAlertPlugin.EXTRA_HOTSPOT_LAT, 0.0)
            val lng = intent.getDoubleExtra(NirbhayRouteAlertPlugin.EXTRA_HOTSPOT_LNG, 0.0)
            NirbhayRouteAlertPlugin.pendingHotspotId = hotspotId
            NirbhayRouteAlertPlugin.pendingHotspotLat = lat
            NirbhayRouteAlertPlugin.pendingHotspotLng = lng
            Log.i(TAG, "ACTION_VIEW_HOTSPOT for '$hotspotId' at $lat,$lng")
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        smsPlugin?.onRequestPermissionsResult(requestCode, grantResults)
    }

    override fun onDestroy() {
        smsPlugin?.dispose()
        smsPlugin = null
        shakePlugin?.dispose()
        shakePlugin = null
        fakeCallPlugin?.dispose()
        fakeCallPlugin = null
        super.onDestroy()
    }
}

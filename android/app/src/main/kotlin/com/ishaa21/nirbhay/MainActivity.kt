package com.ishaa21.nirbhay

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var smsPlugin: NirbhaySmsPlugin? = null
    private var shakePlugin: NirbhayShakePlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        smsPlugin = NirbhaySmsPlugin(this, flutterEngine)
        shakePlugin = NirbhayShakePlugin(this, flutterEngine)
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
        super.onDestroy()
    }
}

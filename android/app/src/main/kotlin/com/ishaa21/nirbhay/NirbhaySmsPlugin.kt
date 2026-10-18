package com.ishaa21.nirbhay

import android.Manifest
import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SmsManager
import android.telephony.TelephonyManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger

/**
 * Native Android SMS via SmsManager + sent/delivery PendingIntent callbacks.
 */
class NirbhaySmsPlugin(
    private val activity: Activity,
    flutterEngine: FlutterEngine,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        const val METHOD_CHANNEL = "com.ishaa21.nirbhay/sms"
        const val EVENT_CHANNEL = "com.ishaa21.nirbhay/sms_events"
        private const val ACTION_SMS_SENT = "com.ishaa21.nirbhay.SMS_SENT"
        private const val ACTION_SMS_DELIVERED = "com.ishaa21.nirbhay.SMS_DELIVERED"
        private const val SMS_PERMISSION_REQUEST = 9101
    }

    private val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
    private val eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
    private var eventSink: EventChannel.EventSink? = null
    private val requestCodeSeq = AtomicInteger(1000)
    private val pendingCallbacks = ConcurrentHashMap<Int, String>()
    private var receiversRegistered = false

    private val sentReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val requestCode = intent?.getIntExtra("requestCode", -1) ?: return
            val clientRequestId = pendingCallbacks.remove(requestCode) ?: return
            val resultCode = resultCode
            val status = if (resultCode == Activity.RESULT_OK) "SENT" else "FAILED"
            val error = if (status == "FAILED") mapSmsSendError(resultCode) else null
            emitEvent(
                mapOf(
                    "type" to "sent",
                    "clientRequestId" to clientRequestId,
                    "status" to status,
                    "errorMessage" to error,
                )
            )
        }
    }

    private val deliveredReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val requestCode = intent?.getIntExtra("requestCode", -1) ?: return
            val clientRequestId = pendingCallbacks[requestCode] ?: return
            val resultCode = resultCode
            val status = if (resultCode == Activity.RESULT_OK) "DELIVERED" else "FAILED"
            val error = if (status == "FAILED") "Carrier did not confirm delivery." else null
            emitEvent(
                mapOf(
                    "type" to "delivered",
                    "clientRequestId" to clientRequestId,
                    "status" to status,
                    "errorMessage" to error,
                )
            )
            pendingCallbacks.remove(requestCode)
        }
    }

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    fun dispose() {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        unregisterReceivers()
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkCapabilities" -> result.success(checkCapabilities())
            "requestPermission" -> requestSmsPermission(result)
            "sendMessages" -> handleSendMessages(call, result)
            else -> result.notImplemented()
        }
    }

    private fun checkCapabilities(): Map<String, Any?> {
        val hasPermission = hasSendSmsPermission()
        val telephony = activity.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        val simReady = telephony.simState == TelephonyManager.SIM_STATE_READY
        return mapOf(
            "platform" to "android",
            "hasSendSmsPermission" to hasPermission,
            "simReady" to simReady,
            "smsSupported" to true,
        )
    }

    private fun hasSendSmsPermission(): Boolean {
        return ContextCompat.checkSelfPermission(activity, Manifest.permission.SEND_SMS) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun requestSmsPermission(result: MethodChannel.Result) {
        if (hasSendSmsPermission()) {
            result.success(mapOf("granted" to true, "permanentlyDenied" to false))
            return
        }
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(Manifest.permission.SEND_SMS),
            SMS_PERMISSION_REQUEST,
        )
    }

    private var pendingPermissionResult: MethodChannel.Result? = null

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != SMS_PERMISSION_REQUEST) return
        val callback = pendingPermissionResult ?: return
        pendingPermissionResult = null
        val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        val permanentlyDenied = !granted && !ActivityCompat.shouldShowRequestPermissionRationale(
            activity,
            Manifest.permission.SEND_SMS,
        )
        callback.success(mapOf("granted" to granted, "permanentlyDenied" to permanentlyDenied))
    }

    private fun handleSendMessages(call: MethodCall, result: MethodChannel.Result) {
        if (!hasSendSmsPermission()) {
            result.success(
                mapOf(
                    "success" to false,
                    "errorCode" to "PERMISSION_DENIED",
                    "errorMessage" to "SEND_SMS permission is not granted.",
                    "results" to emptyList<Map<String, Any?>>(),
                )
            )
            return
        }

        val telephony = activity.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        if (telephony.simState != TelephonyManager.SIM_STATE_READY) {
            result.success(
                mapOf(
                    "success" to false,
                    "errorCode" to "NO_SIM",
                    "errorMessage" to "No ready SIM detected. SMS cannot be sent.",
                    "results" to emptyList<Map<String, Any?>>(),
                )
            )
            return
        }

        @Suppress("UNCHECKED_CAST")
        val messages = call.argument<List<Map<String, Any>>>("messages") ?: emptyList()
        if (messages.isEmpty()) {
            result.success(mapOf("success" to true, "results" to emptyList<Map<String, Any?>>()))
            return
        }

        ensureReceiversRegistered()

        val smsManager = SmsManager.getDefault()
        val out = mutableListOf<Map<String, Any?>>()

        for (entry in messages) {
            val clientRequestId = entry["clientRequestId"] as? String ?: continue
            val phone = entry["phone"] as? String ?: ""
            val body = entry["body"] as? String ?: ""
            if (phone.isBlank() || body.isBlank()) {
                out.add(
                    mapOf(
                        "clientRequestId" to clientRequestId,
                        "status" to "FAILED",
                        "errorMessage" to "Invalid phone or message body.",
                    )
                )
                continue
            }

            try {
                val parts = smsManager.divideMessage(body)
                val requestCode = requestCodeSeq.incrementAndGet()
                pendingCallbacks[requestCode] = clientRequestId

                val sentIntent = buildPendingIntent(ACTION_SMS_SENT, requestCode)
                val deliveredIntent = buildPendingIntent(ACTION_SMS_DELIVERED, requestCode)

                if (parts.size > 1) {
                    val sentIntents = ArrayList<PendingIntent>()
                    val deliveredIntents = ArrayList<PendingIntent>()
                    repeat(parts.size) {
                        sentIntents.add(sentIntent)
                        deliveredIntents.add(deliveredIntent)
                    }
                    smsManager.sendMultipartTextMessage(
                        phone,
                        null,
                        parts,
                        sentIntents,
                        deliveredIntents,
                    )
                } else {
                    smsManager.sendTextMessage(
                        phone,
                        null,
                        body,
                        sentIntent,
                        deliveredIntent,
                    )
                }

                out.add(
                    mapOf(
                        "clientRequestId" to clientRequestId,
                        "status" to "PENDING",
                        "errorMessage" to null,
                    )
                )
            } catch (sec: SecurityException) {
                out.add(
                    mapOf(
                        "clientRequestId" to clientRequestId,
                        "status" to "FAILED",
                        "errorMessage" to sec.message,
                    )
                )
            } catch (ex: Exception) {
                out.add(
                    mapOf(
                        "clientRequestId" to clientRequestId,
                        "status" to "FAILED",
                        "errorMessage" to (ex.message ?: "SMS send failed."),
                    )
                )
            }
        }

        result.success(mapOf("success" to true, "results" to out))
    }

    private fun buildPendingIntent(action: String, requestCode: Int): PendingIntent {
        val intent = Intent(action).setPackage(activity.packageName)
        intent.putExtra("requestCode", requestCode)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getBroadcast(activity, requestCode, intent, flags)
    }

    private fun ensureReceiversRegistered() {
        if (receiversRegistered) return
        val filterSent = IntentFilter(ACTION_SMS_SENT)
        val filterDelivered = IntentFilter(ACTION_SMS_DELIVERED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            activity.registerReceiver(sentReceiver, filterSent, Context.RECEIVER_NOT_EXPORTED)
            activity.registerReceiver(deliveredReceiver, filterDelivered, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            activity.registerReceiver(sentReceiver, filterSent)
            @Suppress("DEPRECATION")
            activity.registerReceiver(deliveredReceiver, filterDelivered)
        }
        receiversRegistered = true
    }

    private fun unregisterReceivers() {
        if (!receiversRegistered) return
        try {
            activity.unregisterReceiver(sentReceiver)
            activity.unregisterReceiver(deliveredReceiver)
        } catch (_: Exception) {
        }
        receiversRegistered = false
    }

    private fun emitEvent(payload: Map<String, Any?>) {
        activity.runOnUiThread {
            eventSink?.success(payload)
        }
    }

    private fun mapSmsSendError(resultCode: Int): String {
        return when (resultCode) {
            SmsManager.RESULT_ERROR_NO_SERVICE -> "No cellular service available."
            SmsManager.RESULT_ERROR_RADIO_OFF -> "Radio is off; enable mobile network."
            SmsManager.RESULT_ERROR_NULL_PDU -> "Invalid SMS PDU."
            SmsManager.RESULT_ERROR_GENERIC_FAILURE -> "Generic SMS send failure (balance/plan/network)."
            else -> "SMS send failed with code $resultCode."
        }
    }
}

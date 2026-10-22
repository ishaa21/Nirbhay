package com.ishaa21.nirbhay

import android.content.Context
import android.content.SharedPreferences

/**
 * SharedPreferences storage for scheduled Fake Call state.
 * Enables device reboot recovery, deduplication, and lifecycle tracking.
 */
object FakeCallPreferences {
    private const val PREFS_NAME = "nirbhay_fake_call_prefs"
    private const val KEY_IS_ARMED = "is_armed"
    private const val KEY_TRIGGER_AT_MILLIS = "trigger_at_millis"
    private const val KEY_CALLER_NAME = "caller_name"
    private const val KEY_CALLER_SUBTITLE = "caller_subtitle"
    private const val KEY_AVATAR_INDEX = "avatar_index"

    private fun getPrefs(context: Context): SharedPreferences {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    fun saveScheduledCall(
        context: Context,
        triggerAtMillis: Long,
        callerName: String,
        callerSubtitle: String,
        avatarIndex: Int = 0
    ) {
        getPrefs(context).edit()
            .putBoolean(KEY_IS_ARMED, true)
            .putLong(KEY_TRIGGER_AT_MILLIS, triggerAtMillis)
            .putString(KEY_CALLER_NAME, callerName)
            .putString(KEY_CALLER_SUBTITLE, callerSubtitle)
            .putInt(KEY_AVATAR_INDEX, avatarIndex)
            .apply()
    }

    fun clearScheduledCall(context: Context) {
        getPrefs(context).edit().clear().apply()
    }

    fun isArmed(context: Context): Boolean {
        return getPrefs(context).getBoolean(KEY_IS_ARMED, false)
    }

    fun getTriggerAtMillis(context: Context): Long {
        return getPrefs(context).getLong(KEY_TRIGGER_AT_MILLIS, 0L)
    }

    fun getCallerName(context: Context): String {
        return getPrefs(context).getString(KEY_CALLER_NAME, "Mom") ?: "Mom"
    }

    fun getCallerSubtitle(context: Context): String {
        return getPrefs(context).getString(KEY_CALLER_SUBTITLE, "Mobile") ?: "Mobile"
    }

    fun getAvatarIndex(context: Context): Int {
        return getPrefs(context).getInt(KEY_AVATAR_INDEX, 0)
    }
}

package com.ishaa21.nirbhay

import android.content.Context
import android.content.res.Configuration
import androidx.annotation.StringRes
import java.util.Locale

object LocaleHelper {
    private const val PREFS_NAME = "nirbhay_locale_prefs"
    private const val KEY_LANG = "selected_language"

    fun setLanguage(context: Context, langCode: String) {
        val code = when (langCode.lowercase(Locale.ROOT)) {
            "hi" -> "hi"
            "gu" -> "gu"
            else -> "en"
        }
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putString(KEY_LANG, code).apply()
    }

    fun getLanguage(context: Context): String {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getString(KEY_LANG, "en") ?: "en"
    }

    fun getLocalizedContext(context: Context): Context {
        val lang = getLanguage(context)
        val locale = Locale.forLanguageTag(lang)
        Locale.setDefault(locale)
        val config = Configuration(context.resources.configuration)
        config.setLocale(locale)
        return context.createConfigurationContext(config)
    }

    fun getString(context: Context, @StringRes resId: Int, vararg formatArgs: Any): String {
        val localizedContext = getLocalizedContext(context)
        return if (formatArgs.isNotEmpty()) {
            localizedContext.getString(resId, *formatArgs)
        } else {
            localizedContext.getString(resId)
        }
    }
}

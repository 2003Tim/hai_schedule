package com.hainanu.hai_schedule

import android.content.Context
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

object NativeCredentialStore {
    private const val PREFS_NAME = "hai_schedule_secure_credentials"
    private const val KEY_USERNAME = "portal_username"
    private const val KEY_PASSWORD = "portal_password"
    private const val KEY_COOKIE_SNAPSHOT = "last_auto_sync_cookie"

    private fun prefs(context: Context) = EncryptedSharedPreferences.create(
        context,
        PREFS_NAME,
        MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build(),
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
    )

    fun save(context: Context, username: String, password: String) {
        prefs(context).edit()
            .putString(KEY_USERNAME, username)
            .putString(KEY_PASSWORD, password)
            .apply()
    }

    fun clear(context: Context) {
        prefs(context).edit()
            .remove(KEY_USERNAME)
            .remove(KEY_PASSWORD)
            .apply()
    }

    fun load(context: Context): Pair<String, String>? {
        val prefs = prefs(context)
        val username = prefs.getString(KEY_USERNAME, null)
        val password = prefs.getString(KEY_PASSWORD, null)
        if (username.isNullOrBlank() || password.isNullOrBlank()) {
            return null
        }
        return username to password
    }

    fun saveCookieSnapshot(context: Context, cookie: String) {
        prefs(context).edit()
            .putString(KEY_COOKIE_SNAPSHOT, cookie)
            .apply()
    }

    fun loadCookieSnapshot(context: Context): String? {
        return prefs(context).getString(KEY_COOKIE_SNAPSHOT, null)
            ?.takeIf { it.isNotBlank() }
    }

    fun clearCookieSnapshot(context: Context) {
        prefs(context).edit()
            .remove(KEY_COOKIE_SNAPSHOT)
            .apply()
    }
}

package com.hainanu.hai_schedule

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

object NativeCredentialStore {
    private const val PREFS_NAME = "hai_schedule_secure_credentials"
    private const val KEY_USERNAME = "portal_username"
    private const val KEY_PASSWORD = "portal_password"
    private const val KEY_COOKIE_SNAPSHOT = "last_auto_sync_cookie"

    @Volatile
    private var cachedPrefs: SharedPreferences? = null

    private fun keyForSource(key: String, source: String?): String {
        return if (source == "undergraduate") "undergraduate.$key" else key
    }

    /**
     * Returns a process-wide cached EncryptedSharedPreferences instance.
     *
     * #P8: previously this called [EncryptedSharedPreferences.create] on
     * every access. That call pulls the Tink master key from Keystore and
     * re-derives the AEAD for both key and value encryption, which is
     * tens of milliseconds per call. With multiple credential reads per
     * foreground sync, this dominated the native bridge cost.
     *
     * The instance is cached with double-checked locking. The cache is
     * process-scoped; on Keystore key invalidation (rare) the user must
     * re-authenticate anyway, which clears the keys and forces a fresh
     * create on next access.
     */
    private fun prefs(context: Context): SharedPreferences {
        cachedPrefs?.let { return it }
        return synchronized(this) {
            cachedPrefs ?: EncryptedSharedPreferences.create(
                context,
                PREFS_NAME,
                MasterKey.Builder(context)
                    .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                    .build(),
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
            ).also { cachedPrefs = it }
        }
    }

    fun save(context: Context, username: String, password: String, source: String? = null) {
        prefs(context).edit()
            .putString(keyForSource(KEY_USERNAME, source), username)
            .putString(keyForSource(KEY_PASSWORD, source), password)
            .commit()
    }

    fun clear(context: Context, source: String? = null) {
        prefs(context).edit()
            .remove(keyForSource(KEY_USERNAME, source))
            .remove(keyForSource(KEY_PASSWORD, source))
            .commit()
    }

    fun load(context: Context, source: String? = null): Pair<String, String>? {
        val prefs = prefs(context)
        val username = prefs.getString(keyForSource(KEY_USERNAME, source), null)
        val password = prefs.getString(keyForSource(KEY_PASSWORD, source), null)
        if (username.isNullOrBlank() || password.isNullOrBlank()) {
            return null
        }
        return username to password
    }

    fun saveCookieSnapshot(context: Context, cookie: String, source: String? = null) {
        prefs(context).edit()
            .putString(keyForSource(KEY_COOKIE_SNAPSHOT, source), cookie)
            .commit()
    }

    fun loadCookieSnapshot(context: Context, source: String? = null): String? {
        return prefs(context).getString(keyForSource(KEY_COOKIE_SNAPSHOT, source), null)
            ?.takeIf { it.isNotBlank() }
    }

    fun clearCookieSnapshot(context: Context, source: String? = null) {
        prefs(context).edit()
            .remove(keyForSource(KEY_COOKIE_SNAPSHOT, source))
            .commit()
    }
}

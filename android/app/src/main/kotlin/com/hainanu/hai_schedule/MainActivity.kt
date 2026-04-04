package com.hainanu.hai_schedule

import android.webkit.CookieManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "hai_schedule/auto_sync",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCookie" -> {
                    val url = call.argument<String>("url")
                    if (url.isNullOrBlank()) {
                        result.error("INVALID_URL", "url 涓嶈兘涓虹┖", null)
                    } else {
                        val manager = CookieManager.getInstance()
                        manager.setAcceptCookie(true)
                        manager.flush()
                        result.success(manager.getCookie(url) ?: "")
                    }
                }

                "flushCookies" -> {
                    val manager = CookieManager.getInstance()
                    manager.setAcceptCookie(true)
                    manager.flush()
                    result.success(true)
                }

                "configureBackgroundSync" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    val frequency = call.argument<String>("frequency") ?: "daily"
                    val customIntervalMinutes = call.argument<Int>("customIntervalMinutes")
                    val afterSuccessfulSync = call.argument<Boolean>("afterSuccessfulSync") ?: false
                    val preserveExistingCustomSchedule =
                        call.argument<Boolean>("preserveExistingCustomSchedule") ?: true
                    val next = AutoSyncScheduler.configure(
                        context = applicationContext,
                        enabled = enabled,
                        frequency = frequency,
                        customIntervalMinutes = customIntervalMinutes,
                        afterSuccessfulSync = afterSuccessfulSync,
                        preserveExistingCustomSchedule = preserveExistingCustomSchedule,
                    )
                    result.success(next ?: "")
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "hai_schedule/native_credentials",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveCredential" -> {
                    val username = call.argument<String>("username")
                    val password = call.argument<String>("password")
                    if (username.isNullOrBlank() || password.isNullOrBlank()) {
                        result.error("INVALID_ARGUMENT", "username/password 涓嶈兘涓虹┖", null)
                    } else {
                        NativeCredentialStore.save(applicationContext, username, password)
                        result.success(true)
                    }
                }

                "clearCredential" -> {
                    NativeCredentialStore.clear(applicationContext)
                    result.success(true)
                }

                "hasCredential" -> {
                    result.success(NativeCredentialStore.load(applicationContext) != null)
                }

                "loadCredential" -> {
                    val credential = NativeCredentialStore.load(applicationContext)
                    if (credential == null) {
                        result.success(null)
                    } else {
                        result.success(
                            mapOf(
                                "username" to credential.first,
                                "password" to credential.second,
                            ),
                        )
                    }
                }

                "saveCookieSnapshot" -> {
                    val cookie = call.argument<String>("cookie")
                    if (cookie.isNullOrBlank()) {
                        result.error("INVALID_ARGUMENT", "cookie 涓嶈兘涓虹┖", null)
                    } else {
                        NativeCredentialStore.saveCookieSnapshot(applicationContext, cookie)
                        result.success(true)
                    }
                }

                "loadCookieSnapshot" -> {
                    result.success(NativeCredentialStore.loadCookieSnapshot(applicationContext))
                }

                "clearCookieSnapshot" -> {
                    NativeCredentialStore.clearCookieSnapshot(applicationContext)
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "hai_schedule/class_silence",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPolicyAccess" -> {
                    result.success(ClassSilenceScheduler.hasPolicyAccess(applicationContext))
                }

                "openPolicyAccessSettings" -> {
                    ClassSilenceScheduler.openPolicyAccessSettings(applicationContext)
                    result.success(true)
                }

                "configureSchedule" -> {
                    val events = call.argument<List<Map<String, Any?>>>("events") ?: emptyList()
                    ClassSilenceScheduler.configure(applicationContext, events)
                    result.success(true)
                }

                "rebuildFromProjection" -> {
                    val payload = call.argument<String>("payload")
                    ClassSilenceScheduler.rebuildFromStoredProjection(
                        context = applicationContext,
                        payloadText = payload,
                    )
                    result.success(true)
                }

                "cancelSchedule" -> {
                    ClassSilenceScheduler.cancel(applicationContext)
                    result.success(true)
                }

                "startManualTest" -> {
                    val durationMinutes = call.argument<Int>("durationMinutes") ?: 1
                    ClassSilenceScheduler.startManualTest(
                        context = applicationContext,
                        durationMinutes = durationMinutes,
                    )
                    result.success(true)
                }

                "restoreNow" -> {
                    ClassSilenceScheduler.restoreNow(applicationContext)
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "hai_schedule/class_reminder",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "rebuildFromProjection" -> {
                    val payload = call.argument<String>("payload")
                    val leadMinutes = call.argument<Int>("leadMinutes") ?: 0
                    ClassReminderScheduler.rebuildFromStoredProjection(
                        context = applicationContext,
                        payloadText = payload,
                        leadMinutesOverride = leadMinutes,
                    )
                    result.success(true)
                }

                "cancelSchedule" -> {
                    ClassReminderScheduler.cancel(applicationContext)
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }
}



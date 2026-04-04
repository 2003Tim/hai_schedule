package com.hainanu.hai_schedule

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

class ClassSilenceScheduler : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_CLASS_START -> {
                val endAtMillis = intent.getLongExtra(EXTRA_END_AT_MILLIS, 0L)
                enterClassSilence(context, endAtMillis)
            }

            ACTION_CLASS_END -> {
                val endAtMillis = intent.getLongExtra(EXTRA_END_AT_MILLIS, 0L)
                restoreIfNeeded(context, endAtMillis)
            }
        }
    }

    companion object {
        private const val tag = "ClassSilence"
        private const val prefsName = "hai_schedule_class_silence"
        private const val flutterPrefsName = "FlutterSharedPreferences"

        private const val actionClassStart = "com.hainanu.hai_schedule.CLASS_SILENCE_START"
        private const val actionClassEnd = "com.hainanu.hai_schedule.CLASS_SILENCE_END"
        private const val extraEventId = "event_id"
        private const val extraEndAtMillis = "end_at_millis"

        private const val keyEventsJson = "events_json"
        private const val keyPreviousRingerMode = "previous_ringer_mode"
        private const val keyActiveUntilMillis = "active_until_millis"
        private const val keyHasSnapshot = "has_snapshot"

        private const val flutterEnabledKey = "flutter.class_silence_enabled"
        private const val flutterLastBuildTimeKey = "flutter.class_silence_last_build_time"
        private const val flutterHorizonEndKey = "flutter.class_silence_horizon_end"
        private const val flutterScheduledCountKey = "flutter.class_silence_scheduled_count"

        const val ACTION_CLASS_START = actionClassStart
        const val ACTION_CLASS_END = actionClassEnd
        const val EXTRA_END_AT_MILLIS = extraEndAtMillis

        fun hasPolicyAccess(context: Context): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
            val manager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            return manager.isNotificationPolicyAccessGranted
        }

        fun openPolicyAccessSettings(context: Context) {
            val packageManager = context.packageManager
            val intents = buildList {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    add(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS).apply {
                        data = Uri.fromParts("package", context.packageName, null)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    })
                }
                add(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                })
                add(Intent(Settings.ACTION_SOUND_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                })
                add(Intent(Settings.ACTION_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                })
            }

            for (intent in intents) {
                if (intent.resolveActivity(packageManager) != null) {
                    context.startActivity(intent)
                    return
                }
            }

            throw PackageManager.NameNotFoundException("No settings activity found")
        }

        fun configure(context: Context, events: List<Map<String, Any?>>) {
            cancel(context, clearBuildState = false)
            val prefs = prefs(context)
            val jsonEvents = JSONArray()
            val now = System.currentTimeMillis()

            var activeSessionFound = false
            var scheduledCount = 0
            var horizonEndMillis = 0L

            for (event in events) {
                val id = event["id"]?.toString()?.takeIf { it.isNotBlank() } ?: continue
                val startAtMillis = (event["startAtMillis"] as? Number)?.toLong() ?: continue
                val endAtMillis = (event["endAtMillis"] as? Number)?.toLong() ?: continue
                if (endAtMillis <= now) continue

                val json = JSONObject().apply {
                    put("id", id)
                    put("startAtMillis", startAtMillis)
                    put("endAtMillis", endAtMillis)
                    put("courseName", event["courseName"]?.toString() ?: "")
                    put("date", event["date"]?.toString() ?: "")
                    put("startSection", (event["startSection"] as? Number)?.toInt() ?: 0)
                    put("endSection", (event["endSection"] as? Number)?.toInt() ?: 0)
                }
                jsonEvents.put(json)
                scheduledCount++
                horizonEndMillis = maxOf(horizonEndMillis, endAtMillis)

                if (startAtMillis <= now) {
                    activeSessionFound = true
                    enterClassSilence(context, endAtMillis)
                    scheduleEnd(context, id, endAtMillis)
                } else {
                    scheduleStart(context, id, startAtMillis, endAtMillis)
                    scheduleEnd(context, id, endAtMillis)
                }
            }

            prefs.edit().putString(keyEventsJson, jsonEvents.toString()).apply()
            if (!activeSessionFound) {
                restoreIfNeeded(context, Long.MAX_VALUE)
            }
            writeBuildState(
                context = context,
                scheduledCount = scheduledCount,
                horizonEndMillis = horizonEndMillis.takeIf { it > 0L },
            )
        }

        fun rebuildFromStoredProjection(
            context: Context,
            payloadText: String? = null,
        ) {
            val flutterPrefs = flutterPrefs(context)
            if (!flutterPrefs.getBoolean(flutterEnabledKey, false)) {
                cancel(context)
                return
            }
            if (!hasPolicyAccess(context)) {
                cancel(context)
                return
            }

            val payload =
                ScheduleProjectionSupport.parsePayload(payloadText)
                    ?: ScheduleProjectionSupport.loadStoredPayload(context)
            if (payload == null) {
                cancel(context, clearBuildState = false)
                writeBuildState(
                    context = context,
                    scheduledCount = 0,
                    horizonEndMillis = Calendar.getInstance().apply {
                        add(Calendar.DAY_OF_YEAR, 7)
                    }.timeInMillis,
                )
                return
            }

            val events = payload.buildOccurrences(Calendar.getInstance(), 7).map { occurrence ->
                mapOf<String, Any?>(
                    "id" to "${occurrence.dateKey}-${occurrence.courseId}-${occurrence.startSection}-${occurrence.endSection}",
                    "courseName" to occurrence.courseName,
                    "date" to occurrence.dateKey,
                    "startSection" to occurrence.startSection,
                    "endSection" to occurrence.endSection,
                    "startAtMillis" to occurrence.startAtMillis,
                    "endAtMillis" to occurrence.endAtMillis,
                )
            }
            configure(context, events)
            if (events.isEmpty()) {
                writeBuildState(
                    context = context,
                    scheduledCount = 0,
                    horizonEndMillis = Calendar.getInstance().apply {
                        add(Calendar.DAY_OF_YEAR, 7)
                    }.timeInMillis,
                )
            }
        }

        fun cancel(context: Context, clearBuildState: Boolean = true) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val stored = loadStoredEvents(context)
            stored.forEach { event ->
                alarmManager.cancel(createStartIntent(context, event.id, event.endAtMillis))
                alarmManager.cancel(createEndIntent(context, event.id, event.endAtMillis))
            }

            restoreImmediatelyIfNeeded(context)

            prefs(context).edit()
                .remove(keyEventsJson)
                .remove(keyPreviousRingerMode)
                .remove(keyActiveUntilMillis)
                .remove(keyHasSnapshot)
                .apply()

            if (clearBuildState) {
                clearBuildState(context)
            }
        }

        fun startManualTest(context: Context, durationMinutes: Int) {
            if (!hasPolicyAccess(context)) {
                throw IllegalStateException("Missing notification policy access")
            }

            val safeDurationMinutes = durationMinutes.coerceIn(1, 10)
            val now = System.currentTimeMillis()
            val endAtMillis = now + safeDurationMinutes * 60_000L
            val eventId = "manual-test-$now"

            enterClassSilence(context, endAtMillis)
            scheduleEnd(context, eventId, endAtMillis)
        }

        fun restoreNow(context: Context) {
            restoreImmediatelyIfNeeded(context)
            prefs(context).edit()
                .remove(keyPreviousRingerMode)
                .remove(keyActiveUntilMillis)
                .remove(keyHasSnapshot)
                .apply()
        }

        private fun enterClassSilence(context: Context, endAtMillis: Long) {
            if (!hasPolicyAccess(context)) return
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val prefs = prefs(context)
            val now = System.currentTimeMillis()
            val activeUntil = prefs.getLong(keyActiveUntilMillis, 0L)

            if (activeUntil <= now) {
                prefs.edit()
                    .putBoolean(keyHasSnapshot, true)
                    .putInt(keyPreviousRingerMode, audioManager.ringerMode)
                    .apply()
            }

            val nextActiveUntil = maxOf(activeUntil, endAtMillis)
            prefs.edit().putLong(keyActiveUntilMillis, nextActiveUntil).apply()

            if (audioManager.ringerMode != AudioManager.RINGER_MODE_SILENT) {
                audioManager.ringerMode = AudioManager.RINGER_MODE_SILENT
            }
        }

        private fun restoreIfNeeded(context: Context, triggerEndAtMillis: Long) {
            if (!hasPolicyAccess(context)) return
            val prefs = prefs(context)
            val now = System.currentTimeMillis()
            val activeUntil = prefs.getLong(keyActiveUntilMillis, 0L)
            if (activeUntil == 0L) return
            if (triggerEndAtMillis < activeUntil && now < activeUntil) return
            if (now < activeUntil) return

            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            if (prefs.getBoolean(keyHasSnapshot, false)) {
                val previousMode = prefs.getInt(
                    keyPreviousRingerMode,
                    AudioManager.RINGER_MODE_NORMAL,
                )
                audioManager.ringerMode = previousMode
            }

            prefs.edit()
                .remove(keyPreviousRingerMode)
                .remove(keyActiveUntilMillis)
                .remove(keyHasSnapshot)
                .apply()
        }

        private fun restoreImmediatelyIfNeeded(context: Context) {
            if (!hasPolicyAccess(context)) return
            val prefs = prefs(context)
            if (!prefs.getBoolean(keyHasSnapshot, false)) return

            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val previousMode = prefs.getInt(
                keyPreviousRingerMode,
                AudioManager.RINGER_MODE_NORMAL,
            )
            audioManager.ringerMode = previousMode
        }

        private fun scheduleStart(
            context: Context,
            eventId: String,
            startAtMillis: Long,
            endAtMillis: Long,
        ) {
            scheduleAlarm(
                context = context,
                triggerAtMillis = startAtMillis,
                pendingIntent = createStartIntent(context, eventId, endAtMillis),
            )
        }

        private fun scheduleEnd(
            context: Context,
            eventId: String,
            endAtMillis: Long,
        ) {
            scheduleAlarm(
                context = context,
                triggerAtMillis = endAtMillis,
                pendingIntent = createEndIntent(context, eventId, endAtMillis),
            )
        }

        private fun scheduleAlarm(
            context: Context,
            triggerAtMillis: Long,
            pendingIntent: PendingIntent,
        ) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.cancel(pendingIntent)
            AlarmSchedulerCompat.schedule(
                context = context,
                alarmManager = alarmManager,
                type = AlarmManager.RTC_WAKEUP,
                triggerAtMillis = triggerAtMillis,
                pendingIntent = pendingIntent,
                logTag = tag,
            )
        }

        private fun createStartIntent(
            context: Context,
            eventId: String,
            endAtMillis: Long,
        ): PendingIntent {
            val intent = Intent(context, ClassSilenceScheduler::class.java).apply {
                action = ACTION_CLASS_START
                putExtra(extraEventId, eventId)
                putExtra(EXTRA_END_AT_MILLIS, endAtMillis)
            }
            return PendingIntent.getBroadcast(
                context,
                ("start:$eventId").hashCode(),
                intent,
                pendingIntentFlags(),
            )
        }

        private fun createEndIntent(
            context: Context,
            eventId: String,
            endAtMillis: Long,
        ): PendingIntent {
            val intent = Intent(context, ClassSilenceScheduler::class.java).apply {
                action = ACTION_CLASS_END
                putExtra(extraEventId, eventId)
                putExtra(EXTRA_END_AT_MILLIS, endAtMillis)
            }
            return PendingIntent.getBroadcast(
                context,
                ("end:$eventId").hashCode(),
                intent,
                pendingIntentFlags(),
            )
        }

        private fun pendingIntentFlags(): Int {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
        }

        private fun loadStoredEvents(context: Context): List<StoredEvent> {
            val text = prefs(context).getString(keyEventsJson, null) ?: return emptyList()
            return try {
                val array = JSONArray(text)
                buildList {
                    for (index in 0 until array.length()) {
                        val item = array.optJSONObject(index) ?: continue
                        add(
                            StoredEvent(
                                id = item.optString("id"),
                                startAtMillis = item.optLong("startAtMillis"),
                                endAtMillis = item.optLong("endAtMillis"),
                                courseName = item.optString("courseName"),
                                date = item.optString("date"),
                                startSection = item.optInt("startSection"),
                                endSection = item.optInt("endSection"),
                            ),
                        )
                    }
                }
            } catch (t: Throwable) {
                Log.e(tag, "Failed to parse stored silence events", t)
                emptyList()
            }
        }

        private fun writeBuildState(
            context: Context,
            scheduledCount: Int,
            horizonEndMillis: Long?,
        ) {
            flutterPrefs(context).edit()
                .putString(flutterLastBuildTimeKey, isoNow())
                .putInt(flutterScheduledCountKey, scheduledCount)
                .apply()

            val editor = flutterPrefs(context).edit()
            if (horizonEndMillis != null) {
                editor.putString(flutterHorizonEndKey, toIsoString(horizonEndMillis))
            } else {
                editor.remove(flutterHorizonEndKey)
            }
            editor.apply()
        }

        private fun clearBuildState(context: Context) {
            flutterPrefs(context).edit()
                .remove(flutterLastBuildTimeKey)
                .remove(flutterHorizonEndKey)
                .putInt(flutterScheduledCountKey, 0)
                .apply()
        }

        private fun prefs(context: Context) =
            context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)

        private fun flutterPrefs(context: Context) =
            context.getSharedPreferences(flutterPrefsName, Context.MODE_PRIVATE)

        private fun isoNow(): String = toIsoString(System.currentTimeMillis())

        private fun toIsoString(timeMillis: Long): String {
            return java.text.SimpleDateFormat(
                "yyyy-MM-dd'T'HH:mm:ss.SSSXXX",
                java.util.Locale.US,
            ).format(java.util.Date(timeMillis))
        }

        private data class StoredEvent(
            val id: String,
            val startAtMillis: Long,
            val endAtMillis: Long,
            val courseName: String,
            val date: String,
            val startSection: Int,
            val endSection: Int,
        )
    }
}

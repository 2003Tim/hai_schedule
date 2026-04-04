package com.hainanu.hai_schedule

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone

class ClassReminderScheduler : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_FIRE_REMINDER) return
        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) return

        ensureChannel(context)

        val notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, 0)
        val title = intent.getStringExtra(EXTRA_TITLE).orEmpty().ifBlank { "上课提醒" }
        val body = intent.getStringExtra(EXTRA_BODY).orEmpty()
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setContentIntent(createLaunchIntent(context))

        try {
            NotificationManagerCompat.from(context).notify(notificationId, builder.build())
        } catch (error: SecurityException) {
            Log.w(TAG, "Notification permission denied while dispatching reminder", error)
        }
    }

    companion object {
        private const val TAG = "ClassReminder"
        private const val PREFS_NAME = "hai_schedule_class_reminder"
        private const val FLUTTER_PREFS_NAME = "FlutterSharedPreferences"

        private const val CHANNEL_ID = "hai_schedule_class_reminders"
        private const val CHANNEL_NAME = "课前提醒"
        private const val CHANNEL_DESCRIPTION = "上课前的本地提醒通知"

        private const val ACTION_FIRE_REMINDER = "com.hainanu.hai_schedule.CLASS_REMINDER_FIRE"
        private const val EXTRA_NOTIFICATION_ID = "notification_id"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_BODY = "body"

        private const val KEY_NOTIFICATIONS_JSON = "notifications_json"

        private const val FLUTTER_LEAD_MINUTES_KEY = "flutter.class_reminder_lead_minutes"
        private const val FLUTTER_LAST_BUILD_TIME_KEY = "flutter.class_reminder_last_build_time"
        private const val FLUTTER_HORIZON_END_KEY = "flutter.class_reminder_horizon_end"
        private const val FLUTTER_SCHEDULED_COUNT_KEY = "flutter.class_reminder_scheduled_count"
        private const val FLUTTER_EXACT_ALARM_ENABLED_KEY =
            "flutter.class_reminder_exact_alarm_enabled"

        fun rebuildFromStoredProjection(
            context: Context,
            payloadText: String? = null,
            leadMinutesOverride: Int? = null,
        ) {
            val flutterPrefs = flutterPrefs(context)
            val leadMinutes =
                leadMinutesOverride
                    ?: flutterPrefs.getInt(FLUTTER_LEAD_MINUTES_KEY, 0)
            if (leadMinutes <= 0) {
                cancel(context)
                writeBuildState(
                    context = context,
                    scheduledCount = 0,
                    horizonEndMillis = null,
                    exactAlarmEnabled = false,
                )
                return
            }

            if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) {
                cancel(context)
                writeBuildState(
                    context = context,
                    scheduledCount = 0,
                    horizonEndMillis = null,
                    exactAlarmEnabled = false,
                )
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
                    horizonEndMillis = horizonEndMillis(),
                    exactAlarmEnabled = false,
                )
                return
            }

            cancel(context, clearBuildState = false)
            ensureChannel(context)

            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val horizonEndMillis = horizonEndMillis()
            val occurrences = payload.buildOccurrences(Calendar.getInstance(), 7)
            val stored = JSONArray()
            var scheduledCount = 0
            var exactAlarmEnabled = AlarmSchedulerCompat.canUseExactAlarms(context, alarmManager)

            for (occurrence in occurrences) {
                val remindAtMillis = occurrence.startAtMillis - leadMinutes * 60_000L
                if (remindAtMillis <= System.currentTimeMillis()) continue
                if (remindAtMillis > horizonEndMillis) continue

                val notificationId = notificationIdFor(occurrence)
                val title = "$leadMinutes 分钟后上课"
                val body = buildBody(occurrence)
                val pendingIntent = createReminderIntent(
                    context = context,
                    notificationId = notificationId,
                    remindAtMillis = remindAtMillis,
                    title = title,
                    body = body,
                )
                val usedExact = AlarmSchedulerCompat.schedule(
                    context = context,
                    alarmManager = alarmManager,
                    type = AlarmManager.RTC_WAKEUP,
                    triggerAtMillis = remindAtMillis,
                    pendingIntent = pendingIntent,
                    logTag = TAG,
                )
                if (!usedExact) {
                    exactAlarmEnabled = false
                }

                stored.put(
                    JSONObject().apply {
                        put("notificationId", notificationId)
                        put("remindAtMillis", remindAtMillis)
                    },
                )
                scheduledCount++
            }

            prefs(context).edit().putString(KEY_NOTIFICATIONS_JSON, stored.toString()).apply()
            writeBuildState(
                context = context,
                scheduledCount = scheduledCount,
                horizonEndMillis = horizonEndMillis,
                exactAlarmEnabled = exactAlarmEnabled,
            )
        }

        fun cancel(context: Context, clearBuildState: Boolean = true) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            loadStoredNotifications(context).forEach { reminder ->
                alarmManager.cancel(
                    createReminderIntent(
                        context = context,
                        notificationId = reminder.notificationId,
                        remindAtMillis = reminder.remindAtMillis,
                        title = "",
                        body = "",
                    ),
                )
            }
            prefs(context).edit().remove(KEY_NOTIFICATIONS_JSON).apply()
            if (clearBuildState) {
                clearBuildState(context)
            }
        }

        private fun buildBody(
            occurrence: ScheduleProjectionSupport.ResolvedProjectionOccurrence,
        ): String {
            return listOf(
                occurrence.courseName,
                "${occurrence.startTime}-${occurrence.endTime}",
                occurrence.location.trim(),
            ).filter { it.isNotBlank() }.joinToString(" · ")
        }

        private fun notificationIdFor(
            occurrence: ScheduleProjectionSupport.ResolvedProjectionOccurrence,
        ): Int {
            val raw = "${occurrence.courseId}|${occurrence.dateKey}|${occurrence.startSection}|${occurrence.endSection}"
            return ((raw.hashCode().toLong() and 0x7FFFFFFF) % 2147480000L).toInt()
        }

        private fun createReminderIntent(
            context: Context,
            notificationId: Int,
            remindAtMillis: Long,
            title: String,
            body: String,
        ): PendingIntent {
            val intent = Intent(context, ClassReminderScheduler::class.java).apply {
                action = ACTION_FIRE_REMINDER
                putExtra(EXTRA_NOTIFICATION_ID, notificationId)
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_BODY, body)
            }
            return PendingIntent.getBroadcast(
                context,
                ("reminder:$notificationId:$remindAtMillis").hashCode(),
                intent,
                pendingIntentFlags(),
            )
        }

        private fun createLaunchIntent(context: Context): PendingIntent? {
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: return null
            launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            return PendingIntent.getActivity(
                context,
                41001,
                launchIntent,
                pendingIntentFlags(),
            )
        }

        private fun ensureChannel(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (manager.getNotificationChannel(CHANNEL_ID) != null) return
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_HIGH)
                    .apply {
                        description = CHANNEL_DESCRIPTION
                    },
            )
        }

        private fun pendingIntentFlags(): Int {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
        }

        private fun loadStoredNotifications(context: Context): List<StoredReminder> {
            val raw = prefs(context).getString(KEY_NOTIFICATIONS_JSON, null) ?: return emptyList()
            return try {
                val array = JSONArray(raw)
                buildList {
                    for (index in 0 until array.length()) {
                        val item = array.optJSONObject(index) ?: continue
                        add(
                            StoredReminder(
                                notificationId = item.optInt("notificationId"),
                                remindAtMillis = item.optLong("remindAtMillis"),
                            ),
                        )
                    }
                }
            } catch (error: Throwable) {
                Log.e(TAG, "Failed to parse stored reminders", error)
                emptyList()
            }
        }

        private fun writeBuildState(
            context: Context,
            scheduledCount: Int,
            horizonEndMillis: Long?,
            exactAlarmEnabled: Boolean,
        ) {
            val editor = flutterPrefs(context).edit()
                .putString(FLUTTER_LAST_BUILD_TIME_KEY, isoNow())
                .putInt(FLUTTER_SCHEDULED_COUNT_KEY, scheduledCount)
                .putBoolean(FLUTTER_EXACT_ALARM_ENABLED_KEY, exactAlarmEnabled)

            if (horizonEndMillis != null) {
                editor.putString(FLUTTER_HORIZON_END_KEY, toIsoString(horizonEndMillis))
            } else {
                editor.remove(FLUTTER_HORIZON_END_KEY)
            }
            editor.apply()
        }

        private fun clearBuildState(context: Context) {
            flutterPrefs(context).edit()
                .remove(FLUTTER_LAST_BUILD_TIME_KEY)
                .remove(FLUTTER_HORIZON_END_KEY)
                .putInt(FLUTTER_SCHEDULED_COUNT_KEY, 0)
                .putBoolean(FLUTTER_EXACT_ALARM_ENABLED_KEY, false)
                .apply()
        }

        private fun horizonEndMillis(): Long {
            return Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, 7)
            }.timeInMillis
        }

        private fun prefs(context: Context) =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        private fun flutterPrefs(context: Context) =
            context.getSharedPreferences(FLUTTER_PREFS_NAME, Context.MODE_PRIVATE)

        private fun isoNow(): String = toIsoString(System.currentTimeMillis())

        private fun toIsoString(timeMillis: Long): String {
            val format = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
            format.timeZone = TimeZone.getTimeZone("UTC")
            return format.format(Date(timeMillis))
        }

        private data class StoredReminder(
            val notificationId: Int,
            val remindAtMillis: Long,
        )
    }
}

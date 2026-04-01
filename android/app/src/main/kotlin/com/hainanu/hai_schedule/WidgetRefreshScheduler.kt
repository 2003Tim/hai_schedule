package com.hainanu.hai_schedule

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.concurrent.TimeUnit

class WidgetRefreshScheduler : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.d(TAG, "onReceive: action=$action")

        when (action) {
            ACTION_PERIODIC_REFRESH -> {
                TodayScheduleWidgetProvider.refreshAll(context)
                scheduleNext(context)
            }
            ACTION_DAILY_RESET -> {
                resetAllWidgetsToToday(context)
                TodayScheduleWidgetProvider.refreshAll(context)
                scheduleNext(context)
                scheduleDailyReset(context)
            }
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                scheduleNext(context)
                scheduleDailyReset(context)
            }
        }
    }

    companion object {
        private const val TAG = "WidgetRefresh"
        const val ACTION_PERIODIC_REFRESH = "com.hainanu.hai_schedule.WIDGET_PERIODIC_REFRESH"
        const val ACTION_DAILY_RESET = "com.hainanu.hai_schedule.WIDGET_DAILY_RESET"

        private const val REQUEST_CODE_PERIODIC = 9001
        private const val REQUEST_CODE_DAILY = 9002

        private const val INTERVAL_ACTIVE = 60_000L
        private const val INTERVAL_UPCOMING = 5 * 60_000L
        private const val INTERVAL_IDLE = 15 * 60_000L
        private const val INTERVAL_NIGHT = 60 * 60_000L

        fun start(context: Context) {
            scheduleNext(context)
            scheduleDailyReset(context)
        }

        fun stop(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.cancel(createPeriodicIntent(context))
            alarmManager.cancel(createDailyIntent(context))
        }

        private fun scheduleNext(context: Context) {
            val interval = calculateNextInterval(context)
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val triggerAt = SystemClock.elapsedRealtime() + interval

            alarmManager.cancel(createPeriodicIntent(context))

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    triggerAt,
                    createPeriodicIntent(context),
                )
            } else {
                alarmManager.setExact(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    triggerAt,
                    createPeriodicIntent(context),
                )
            }

            Log.d(TAG, "下次刷新在 ${interval / 1000} 秒后")
        }

        private fun scheduleDailyReset(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            val calendar = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 6)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                if (timeInMillis <= System.currentTimeMillis()) {
                    add(Calendar.DAY_OF_YEAR, 1)
                }
            }

            alarmManager.cancel(createDailyIntent(context))

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    calendar.timeInMillis,
                    createDailyIntent(context),
                )
            } else {
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    calendar.timeInMillis,
                    createDailyIntent(context),
                )
            }
        }

        private fun calculateNextInterval(context: Context): Long {
            val now = Calendar.getInstance()
            val hour = now.get(Calendar.HOUR_OF_DAY)
            val minute = now.get(Calendar.MINUTE)
            val nowMinutes = hour * 60 + minute

            if (hour >= 22 || hour < 6) {
                return INTERVAL_NIGHT
            }

            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val payloadText = prefs.getString("hai_schedule_widget_payload", null)
            if (payloadText.isNullOrBlank()) {
                return INTERVAL_IDLE
            }

            return try {
                val payload = JSONObject(payloadText)
                val semesterStart = payload.optString("semesterStart")
                val totalWeeks = payload.optInt("totalWeeks", 20)
                val classTimes = payload.optJSONArray("classTimes") ?: JSONArray()
                val slots = payload.optJSONArray("slots") ?: JSONArray()
                val overrides = payload.optJSONArray("overrides") ?: JSONArray()

                val weekday = todayWeekday(now)
                val currentWeek = calculateCurrentWeek(semesterStart, totalWeeks, now)
                if (currentWeek <= 0) return INTERVAL_IDLE

                val todaySlots = resolveTodaySlots(
                    now = now,
                    weekday = weekday,
                    currentWeek = currentWeek,
                    slots = slots,
                    overrides = overrides,
                    classTimes = classTimes,
                )

                if (todaySlots.isEmpty()) return INTERVAL_IDLE

                todaySlots.sortBy { it.first }

                for ((start, end) in todaySlots) {
                    if (nowMinutes in start..end) {
                        return INTERVAL_ACTIVE
                    }
                    if (nowMinutes < start && start - nowMinutes <= 30) {
                        return INTERVAL_UPCOMING
                    }
                }

                val nextStart = todaySlots.firstOrNull { it.first > nowMinutes }
                if (nextStart != null) {
                    val diff = nextStart.first - nowMinutes
                    return if (diff > 30) INTERVAL_IDLE else INTERVAL_UPCOMING
                }

                INTERVAL_IDLE
            } catch (e: Exception) {
                Log.e(TAG, "计算刷新间隔失败", e)
                INTERVAL_IDLE
            }
        }

        private fun resetAllWidgetsToToday(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, TodayScheduleWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(component)
            val statePrefs = context.getSharedPreferences("hai_schedule_widget_state", Context.MODE_PRIVATE)
            val editor = statePrefs.edit()
            ids.forEach { id -> editor.putInt("offset_$id", 0) }
            editor.apply()
        }

        private fun createPeriodicIntent(context: Context): PendingIntent {
            val intent = Intent(context, WidgetRefreshScheduler::class.java).apply {
                action = ACTION_PERIODIC_REFRESH
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            return PendingIntent.getBroadcast(context, REQUEST_CODE_PERIODIC, intent, flags)
        }

        private fun createDailyIntent(context: Context): PendingIntent {
            val intent = Intent(context, WidgetRefreshScheduler::class.java).apply {
                action = ACTION_DAILY_RESET
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            return PendingIntent.getBroadcast(context, REQUEST_CODE_DAILY, intent, flags)
        }

        private fun todayWeekday(calendar: Calendar): Int {
            return when (calendar.get(Calendar.DAY_OF_WEEK)) {
                Calendar.SUNDAY -> 7
                else -> calendar.get(Calendar.DAY_OF_WEEK) - 1
            }
        }

        private fun calculateCurrentWeek(semesterStart: String, totalWeeks: Int, now: Calendar): Int {
            val format = SimpleDateFormat("yyyy-MM-dd", Locale.US)
            val startDate = format.parse(semesterStart) ?: return 0
            val start = Calendar.getInstance().apply {
                time = startDate
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val day = (now.clone() as Calendar).apply {
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val diffDays = TimeUnit.MILLISECONDS.toDays(day.timeInMillis - start.timeInMillis).toInt()
            if (diffDays < 0) return 0
            return (diffDays / 7 + 1).coerceIn(1, totalWeeks)
        }

        private fun containsWeek(weeks: JSONArray, target: Int): Boolean {
            for (i in 0 until weeks.length()) {
                if (weeks.optInt(i) == target) return true
            }
            return false
        }

        private fun findTime(classTimes: JSONArray, section: Int, isStart: Boolean): String {
            for (i in 0 until classTimes.length()) {
                val item = classTimes.optJSONObject(i) ?: continue
                if (item.optInt("section") == section) {
                    return if (isStart) item.optString("startTime") else item.optString("endTime")
                }
            }
            return "00:00"
        }

        private fun resolveTodaySlots(
            now: Calendar,
            weekday: Int,
            currentWeek: Int,
            slots: JSONArray,
            overrides: JSONArray,
            classTimes: JSONArray,
        ): MutableList<Pair<Int, Int>> {
            val dateKey = formatDateKey(now)
            val dayOverrides = mutableListOf<JSONObject>()
            for (i in 0 until overrides.length()) {
                val item = overrides.optJSONObject(i) ?: continue
                if (item.optString("dateKey") == dateKey && item.optInt("weekday") == weekday) {
                    dayOverrides.add(item)
                }
            }

            val todaySlots = mutableListOf<Pair<Int, Int>>()

            for (i in 0 until slots.length()) {
                val slot = slots.optJSONObject(i) ?: continue
                if (slot.optInt("weekday") != weekday) continue

                val activeWeeks = slot.optJSONArray("activeWeeks")
                if (activeWeeks == null || !containsWeek(activeWeeks, currentWeek)) continue

                val courseId = slot.optString("courseId")
                val cancelOverride = dayOverrides.firstOrNull { item ->
                    item.optString("type") == "cancel" &&
                        item.optString("status") != "orphaned" &&
                        (
                            item.optString("targetCourseId") == courseId ||
                                (
                                    item.optInt("sourceStartSection", item.optInt("startSection")) == slot.optInt("startSection") &&
                                        item.optInt("sourceEndSection", item.optInt("endSection")) == slot.optInt("endSection")
                                    )
                            )
                }
                if (cancelOverride != null) continue

                val modifyOverride = dayOverrides.firstOrNull { item ->
                    item.optString("type") == "modify" &&
                        item.optString("status") != "orphaned" &&
                        (
                            item.optString("targetCourseId") == courseId ||
                                (
                                    item.optInt("sourceStartSection", item.optInt("startSection")) == slot.optInt("startSection") &&
                                        item.optInt("sourceEndSection", item.optInt("endSection")) == slot.optInt("endSection")
                                    )
                            )
                }

                val startSection = modifyOverride?.optInt("startSection") ?: slot.optInt("startSection")
                val endSection = modifyOverride?.optInt("endSection") ?: slot.optInt("endSection")
                val startTime = findTime(classTimes, startSection, true)
                val endTime = findTime(classTimes, endSection, false)
                todaySlots.add(toMinutes(startTime) to toMinutes(endTime))
            }

            for (item in dayOverrides) {
                if (item.optString("type") != "add") continue
                if (item.optString("status") == "orphaned") continue
                val startSection = item.optInt("startSection")
                val endSection = item.optInt("endSection")
                val startTime = findTime(classTimes, startSection, true)
                val endTime = findTime(classTimes, endSection, false)
                todaySlots.add(toMinutes(startTime) to toMinutes(endTime))
            }

            return todaySlots
        }

        private fun formatDateKey(calendar: Calendar): String {
            return String.format(
                Locale.US,
                "%04d-%02d-%02d",
                calendar.get(Calendar.YEAR),
                calendar.get(Calendar.MONTH) + 1,
                calendar.get(Calendar.DAY_OF_MONTH),
            )
        }

        private fun toMinutes(text: String): Int {
            val parts = text.split(":")
            if (parts.size != 2) return 0
            return (parts[0].toIntOrNull() ?: 0) * 60 + (parts[1].toIntOrNull() ?: 0)
        }
    }
}

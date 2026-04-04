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
import java.util.Calendar

class WidgetRefreshScheduler : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        logd("onReceive: action=$action")

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
        }
    }

    companion object {
        private const val TAG = "WidgetRefresh"

        private fun logd(msg: String) {
            if (Log.isLoggable(TAG, Log.DEBUG)) Log.d(TAG, msg)
        }
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

            AlarmSchedulerCompat.schedule(
                context = context,
                alarmManager = alarmManager,
                type = AlarmManager.ELAPSED_REALTIME_WAKEUP,
                triggerAtMillis = triggerAt,
                pendingIntent = createPeriodicIntent(context),
                logTag = TAG,
            )

            logd("下次刷新在 ${interval / 1000} 秒后")
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

            AlarmSchedulerCompat.schedule(
                context = context,
                alarmManager = alarmManager,
                type = AlarmManager.RTC_WAKEUP,
                triggerAtMillis = calendar.timeInMillis,
                pendingIntent = createDailyIntent(context),
                logTag = TAG,
            )
        }

        private fun calculateNextInterval(context: Context): Long {
            val now = Calendar.getInstance()
            val hour = now.get(Calendar.HOUR_OF_DAY)
            val minute = now.get(Calendar.MINUTE)
            val nowMinutes = hour * 60 + minute

            if (hour >= 22 || hour < 6) {
                return INTERVAL_NIGHT
            }

            val payload = ScheduleProjectionSupport.loadStoredPayload(context)
            if (payload == null) {
                return INTERVAL_IDLE
            }

            return try {
                val currentWeek = payload.calculateWeek(now)
                if (currentWeek <= 0) return INTERVAL_IDLE

                val todaySlots =
                    payload.resolveDaySlots(now).mapNotNull { slot ->
                        val startTime = payload.findTime(slot.startSection, true)
                        val endTime = payload.findTime(slot.endSection, false)
                        if (startTime == null || endTime == null) {
                            null
                        } else {
                            toMinutes(startTime) to toMinutes(endTime)
                        }
                    }.toMutableList()

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

        private fun toMinutes(text: String): Int {
            val parts = text.split(":")
            if (parts.size != 2) return 0
            return (parts[0].toIntOrNull() ?: 0) * 60 + (parts[1].toIntOrNull() ?: 0)
        }
    }
}

package com.hainanu.hai_schedule

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.os.Build
import android.util.Log

object AlarmSchedulerCompat {
    fun canUseExactAlarms(context: Context, alarmManager: AlarmManager): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            alarmManager.canScheduleExactAlarms()
        } else {
            true
        }
    }

    fun schedule(
        context: Context,
        alarmManager: AlarmManager,
        type: Int,
        triggerAtMillis: Long,
        pendingIntent: PendingIntent,
        logTag: String,
    ): Boolean {
        val exactAllowed = canUseExactAlarms(context, alarmManager)
        if (exactAllowed) {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(type, triggerAtMillis, pendingIntent)
                } else {
                    alarmManager.setExact(type, triggerAtMillis, pendingIntent)
                }
                return true
            } catch (error: SecurityException) {
                Log.w(logTag, "Exact alarm denied at runtime, falling back to inexact scheduling", error)
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(type, triggerAtMillis, pendingIntent)
        } else {
            alarmManager.set(type, triggerAtMillis, pendingIntent)
        }
        return false
    }
}

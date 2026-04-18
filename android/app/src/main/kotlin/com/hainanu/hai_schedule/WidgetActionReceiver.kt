package com.hainanu.hai_schedule

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class WidgetActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            val action = intent.action ?: return
            if (
                action != TodayScheduleWidgetProvider.ACTION_PREV &&
                    action != TodayScheduleWidgetProvider.ACTION_TODAY &&
                    action != TodayScheduleWidgetProvider.ACTION_NEXT
            ) {
                return
            }

            val widgetId = intent.getIntExtra(
                AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID,
            )
            if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) return

            val statePrefs = context.getSharedPreferences(
                "hai_schedule_widget_state",
                Context.MODE_PRIVATE,
            )
            val currentOffset = statePrefs.getInt("offset_$widgetId", 0)
            val nextOffset = when (action) {
                TodayScheduleWidgetProvider.ACTION_PREV -> (currentOffset - 1).coerceAtLeast(-13)
                TodayScheduleWidgetProvider.ACTION_NEXT -> (currentOffset + 1).coerceAtMost(13)
                else -> 0
            }
            statePrefs.edit().putInt("offset_$widgetId", nextOffset).apply()

            TodayScheduleWidgetProvider.refreshAll(context)
            WidgetRefreshScheduler.start(context)
        } catch (t: Throwable) {
            Log.e(TAG, "Failed to handle widget action", t)
        }
    }

    companion object {
        private const val TAG = "WidgetActionReceiver"
    }
}

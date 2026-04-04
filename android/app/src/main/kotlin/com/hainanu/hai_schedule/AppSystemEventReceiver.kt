package com.hainanu.hai_schedule

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class AppSystemEventReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                try {
                    AutoSyncScheduler.schedule(context, afterSuccessfulSync = false)
                    WidgetRefreshScheduler.start(context)
                    ClassReminderScheduler.rebuildFromStoredProjection(context)
                    ClassSilenceScheduler.rebuildFromStoredProjection(context)
                } catch (error: Throwable) {
                    Log.e("HaiSystemReceiver", "Failed to restore background schedules", error)
                }
            }
        }
    }
}

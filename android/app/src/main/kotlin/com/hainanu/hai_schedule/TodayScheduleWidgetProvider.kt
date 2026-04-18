package com.hainanu.hai_schedule

import android.app.NotificationManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.os.Build
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import kotlin.math.min

class TodayScheduleWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { appWidgetId ->
            updateSingleWidget(context, appWidgetManager, appWidgetId, widgetData)
        }
        WidgetRefreshScheduler.start(context)
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        WidgetRefreshScheduler.start(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        WidgetRefreshScheduler.stop(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        if (intent.action == Intent.ACTION_CONFIGURATION_CHANGED) {
            refreshAll(context)
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        val prefs = context.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE)
        val editor = prefs.edit()
        appWidgetIds.forEach { editor.remove(offsetKey(it)) }
        editor.apply()
    }

    private fun updateSingleWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        widgetData: SharedPreferences,
    ) {
        try {
            val views = buildRemoteViews(context, appWidgetId, widgetData)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        } catch (t: Throwable) {
            Log.e(TAG, "Failed to update widget $appWidgetId", t)
        }
    }

    private fun buildRemoteViews(
        context: Context,
        appWidgetId: Int,
        widgetData: SharedPreferences,
    ): RemoteViews {
        return try {
            val views = newRemoteViews(context)
            val appearance = resolveAppearance(context)
            val indicators = loadIndicators(context)
            val statePrefs = context.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE)
            val dayOffset = statePrefs.getInt(offsetKey(appWidgetId), 0)
            val target = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, dayOffset) }

            bindButtons(context, views, appWidgetId, dayOffset, appearance)
            bindStaticTheme(views, appearance)
            views.setOnClickPendingIntent(R.id.widget_root, createLaunchIntent(context))

            val payloadText = widgetData.getString(KEY_PAYLOAD, null)
            if (payloadText.isNullOrBlank()) {
                bindHeader(
                    views = views,
                    target = target,
                    weekdayText = weekdayText(target),
                    currentWeek = 0,
                    count = 0,
                    dayOffset = dayOffset,
                )
                bindEmptyState(views, "还没有课表数据", "先打开海大课表，登录或导入课表")
                return views
            }

            val payload = ScheduleProjectionSupport.parsePayload(payloadText)
                ?: throw IllegalStateException("Payload parse failed")

            val now = Calendar.getInstance()
            val currentWeek = payload.calculateWeek(target)
            val dayRelation = compareDay(target, now)
            val dayLabel = dayOffsetText(dayOffset)
            val daySlots = buildDayItems(
                payload = payload,
                now = now,
                target = target,
                dayRelation = dayRelation,
                currentWeek = currentWeek,
                totalWeeks = payload.totalWeeks,
            )

            bindHeader(
                views = views,
                target = target,
                weekdayText = weekdayText(target),
                currentWeek = currentWeek,
                count = daySlots.length(),
                dayOffset = dayOffset,
            )
            bindList(
                context = context,
                views = views,
                daySlots = daySlots,
                dayLabel = dayLabel,
                colors = appearance.colors,
                indicators = indicators,
                currentWeek = currentWeek,
                totalWeeks = payload.totalWeeks,
            )
            views
        } catch (t: Throwable) {
            Log.e(TAG, "Failed to build remote views for widget $appWidgetId", t)
            buildFallbackRemoteViews(context, t)
        }
    }

    private fun newRemoteViews(context: Context): RemoteViews {
        return RemoteViews(context.packageName, R.layout.widget_today_schedule_premium)
    }

    private fun buildFallbackRemoteViews(context: Context, error: Throwable): RemoteViews {
        val views = newRemoteViews(context)
        runCatching {
            bindStaticTheme(views, resolveAppearance(context))
        }
        views.setTextViewText(R.id.header_date, "海大课表")
        views.setTextViewText(R.id.header_week, "小组件恢复中")
        bindEmptyState(views, "小组件加载失败", error.message ?: "请重新打开应用同步")
        views.setOnClickPendingIntent(R.id.widget_root, createLaunchIntent(context))
        return views
    }

    private fun bindButtons(
        context: Context,
        views: RemoteViews,
        appWidgetId: Int,
        dayOffset: Int,
        appearance: WidgetAppearance,
    ) {
        views.setOnClickPendingIntent(
            R.id.btn_prev,
            createActionIntent(context, ACTION_PREV, appWidgetId, 1000 + appWidgetId),
        )
        views.setOnClickPendingIntent(
            R.id.btn_today,
            createActionIntent(context, ACTION_TODAY, appWidgetId, 2000 + appWidgetId),
        )
        views.setOnClickPendingIntent(
            R.id.btn_next,
            createActionIntent(context, ACTION_NEXT, appWidgetId, 3000 + appWidgetId),
        )

        views.setTextColor(R.id.btn_prev, appearance.colors.button)
        views.setTextColor(R.id.btn_next, appearance.colors.button)
        views.setTextColor(
            R.id.btn_today,
            if (dayOffset == 0) appearance.colors.accent else appearance.colors.button,
        )
        views.setInt(R.id.btn_prev, "setBackgroundResource", appearance.navButtonBackgroundRes)
        views.setInt(R.id.btn_next, "setBackgroundResource", appearance.navButtonBackgroundRes)
        views.setInt(
            R.id.btn_today,
            "setBackgroundResource",
            if (dayOffset == 0) appearance.navActiveBackgroundRes else appearance.navButtonBackgroundRes,
        )
    }

    private fun bindStaticTheme(views: RemoteViews, appearance: WidgetAppearance) {
        views.setInt(R.id.widget_root, "setBackgroundResource", appearance.rootBackgroundRes)
        views.setInt(R.id.course_1, "setBackgroundResource", appearance.cardBackgroundRes)
        views.setInt(R.id.course_2, "setBackgroundResource", appearance.cardBackgroundRes)
        intArrayOf(
            R.id.course_reminder_badge_1,
            R.id.course_silence_badge_1,
            R.id.course_reminder_badge_2,
            R.id.course_silence_badge_2,
        ).forEach { badgeId ->
            views.setInt(badgeId, "setBackgroundResource", appearance.badgeBackgroundRes)
        }

        views.setTextColor(R.id.header_date, appearance.colors.title)
        views.setTextColor(R.id.header_week, appearance.colors.subtitle)
        views.setInt(R.id.top_divider, "setBackgroundColor", appearance.colors.divider)
        views.setTextColor(R.id.empty_text, appearance.colors.title)
        views.setTextColor(R.id.empty_subtext, blendAlpha(appearance.colors.hint, 0.78f))
        views.setTextColor(R.id.empty_icon, appearance.colors.sunAccent)
        views.setTextColor(R.id.more_text, appearance.colors.hint)
    }

    private fun bindHeader(
        views: RemoteViews,
        target: Calendar,
        weekdayText: String,
        currentWeek: Int,
        count: Int,
        dayOffset: Int,
    ) {
        val dateLabel = SimpleDateFormat("M月d日", Locale.CHINA).format(target.time)
        val weekText = if (currentWeek > 0) "第${currentWeek}周" else "未开学"
        val dayLabel = dayOffsetText(dayOffset)
        val countText = if (count == 0) "无课" else "${count}节"

        views.setTextViewText(R.id.header_date, dateLabel)
        views.setTextViewText(R.id.header_week, "$weekdayText · $dayLabel · $weekText · $countText")
    }

    private fun bindEmptyState(
        views: RemoteViews,
        title: String,
        subtitle: String,
    ) {
        views.setViewVisibility(R.id.empty_container, View.VISIBLE)
        views.setViewVisibility(R.id.course_list_container, View.GONE)
        views.setViewVisibility(R.id.more_text, View.GONE)
        views.setTextViewText(R.id.empty_text, title)
        views.setTextViewText(R.id.empty_subtext, subtitle)
        views.setViewVisibility(
            R.id.empty_subtext,
            if (subtitle.isBlank()) View.GONE else View.VISIBLE,
        )
    }

    private fun bindList(
        context: Context,
        views: RemoteViews,
        daySlots: JSONArray,
        dayLabel: String,
        colors: WidgetColors,
        indicators: WidgetIndicators,
        currentWeek: Int,
        totalWeeks: Int,
    ) {
        if (daySlots.length() == 0) {
            val title = if (dayLabel == "今天") {
                "今天无课"
            } else {
                "$dayLabel 无课"
            }
            bindEmptyState(views, title, "尽享时光")
            return
        }

        views.setViewVisibility(R.id.empty_container, View.GONE)
        views.setViewVisibility(R.id.course_list_container, View.VISIBLE)

        bindRow(context, views, 0, daySlots, colors, indicators, currentWeek, totalWeeks)
        bindRow(context, views, 1, daySlots, colors, indicators, currentWeek, totalWeeks)

        val extra = daySlots.length() - 2
        if (extra > 0) {
            views.setViewVisibility(R.id.more_text, View.VISIBLE)
            views.setTextViewText(R.id.more_text, "还有 ${extra} 节课程未显示")
        } else {
            views.setViewVisibility(R.id.more_text, View.GONE)
        }
    }

    private fun bindRow(
        context: Context,
        views: RemoteViews,
        index: Int,
        daySlots: JSONArray,
        colors: WidgetColors,
        indicators: WidgetIndicators,
        currentWeek: Int,
        totalWeeks: Int,
    ) {
        val rootIds = intArrayOf(R.id.course_1, R.id.course_2)
        val indicatorIds = intArrayOf(R.id.course_indicator_1, R.id.course_indicator_2)
        val titleIds = intArrayOf(R.id.course_title_1, R.id.course_title_2)
        val metaIds = intArrayOf(R.id.course_meta_1, R.id.course_meta_2)
        val statusIds = intArrayOf(R.id.course_status_1, R.id.course_status_2)
        val statusRowIds = intArrayOf(R.id.course_status_row_1, R.id.course_status_row_2)
        val reminderBadgeIds = intArrayOf(R.id.course_reminder_badge_1, R.id.course_reminder_badge_2)
        val silenceBadgeIds = intArrayOf(R.id.course_silence_badge_1, R.id.course_silence_badge_2)
        val ringIds = intArrayOf(R.id.course_ring_1, R.id.course_ring_2)
        val weekValueIds = intArrayOf(R.id.course_week_value_1, R.id.course_week_value_2)
        val weekLabelIds = intArrayOf(R.id.course_week_label_1, R.id.course_week_label_2)

        if (index >= daySlots.length()) {
            views.setViewVisibility(rootIds[index], View.GONE)
            return
        }

        val item = daySlots.getJSONObject(index)
        val itemColor = parseColor(item.optInt("color"))
        val progress = ringProgress(currentWeek, totalWeeks)

        views.setViewVisibility(rootIds[index], View.VISIBLE)
        views.setTextViewText(titleIds[index], item.optString("courseName"))
        views.setTextColor(titleIds[index], colors.title)
        views.setTextViewText(metaIds[index], item.optString("meta"))
        views.setTextColor(metaIds[index], colors.subtitle)
        views.setTextViewText(statusIds[index], item.optString("statusText"))
        views.setInt(indicatorIds[index], "setBackgroundColor", itemColor)

        val statusColor = when (item.optString("status")) {
            "ongoing" -> colors.ongoing
            "upcoming" -> colors.upcoming
            else -> colors.hint
        }
        views.setTextColor(statusIds[index], statusColor)

        val hasIndicators = indicators.reminderEnabled || indicators.silenceEnabled
        views.setViewVisibility(statusRowIds[index], if (hasIndicators) View.VISIBLE else View.GONE)
        views.setViewVisibility(
            reminderBadgeIds[index],
            if (indicators.reminderEnabled) View.VISIBLE else View.GONE,
        )
        views.setViewVisibility(
            silenceBadgeIds[index],
            if (indicators.silenceEnabled) View.VISIBLE else View.GONE,
        )
        views.setTextColor(reminderBadgeIds[index], colors.accent)
        views.setTextColor(silenceBadgeIds[index], colors.ongoing)

        views.setTextViewText(weekValueIds[index], weekValueText(currentWeek, totalWeeks))
        views.setTextViewText(
            weekLabelIds[index],
            if (currentWeek > 0 && totalWeeks > 0) "周" else "未开",
        )
        views.setTextColor(weekValueIds[index], itemColor)
        views.setTextColor(weekLabelIds[index], colors.hint)
        views.setImageViewBitmap(
            ringIds[index],
            createProgressRingBitmap(context, progress, itemColor),
        )
    }

    private fun buildDayItems(
        payload: ScheduleProjectionSupport.ProjectionPayload,
        now: Calendar,
        target: Calendar,
        dayRelation: Int,
        currentWeek: Int,
        totalWeeks: Int,
    ): JSONArray {
        val list = mutableListOf<JSONObject>()
        val nowMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        for (effectiveSlot in payload.resolveDaySlots(target)) {
            val startTime = payload.findTime(effectiveSlot.startSection, true) ?: "--:--"
            val endTime = payload.findTime(effectiveSlot.endSection, false) ?: "--:--"
            val startMinutes = toMinutes(startTime)
            val endMinutes = toMinutes(endTime)

            val status = when {
                dayRelation > 0 -> "upcoming"
                dayRelation < 0 -> "finished"
                nowMinutes < startMinutes -> "upcoming"
                nowMinutes <= endMinutes -> "ongoing"
                else -> "finished"
            }

            val statusText = when {
                dayRelation > 0 -> "待上课"
                dayRelation < 0 -> "已结束"
                status == "upcoming" -> {
                    val diff = startMinutes - nowMinutes
                    when {
                        diff < 60 -> "${diff}分钟后"
                        diff % 60 == 0 -> "${diff / 60}小时后"
                        else -> "${diff / 60}h${diff % 60}m后"
                    }
                }
                status == "ongoing" -> {
                    val diff = endMinutes - nowMinutes
                    if (diff <= 0) "即将下课" else "剩${diff}分钟"
                }
                else -> "已结束"
            }

            val meta = buildMetaText(
                location = shortLocation(effectiveSlot.location).ifBlank { "教室待定" },
                activeWeeks = effectiveSlot.activeWeeks,
                currentWeek = currentWeek,
                totalWeeks = totalWeeks,
            )

            list.add(
                JSONObject().apply {
                    put("courseName", effectiveSlot.courseName)
                    put("meta", meta)
                    put("status", status)
                    put("statusText", statusText)
                    put("sortKey", effectiveSlot.startSection)
                    put("color", effectiveSlot.color.takeIf { it != 0 } ?: Color.parseColor("#5B8FF9"))
                },
            )
        }

        list.sortBy { it.optInt("sortKey") }
        return JSONArray(list)
    }

    private fun todayWeekday(calendar: Calendar): Int {
        return when (calendar.get(Calendar.DAY_OF_WEEK)) {
            Calendar.SUNDAY -> 7
            else -> calendar.get(Calendar.DAY_OF_WEEK) - 1
        }
    }

    private fun compareDay(target: Calendar, now: Calendar): Int {
        val t = (target.clone() as Calendar).apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val n = (now.clone() as Calendar).apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        return t.time.compareTo(n.time)
    }

    private fun toMinutes(text: String): Int {
        val parts = text.split(":")
        if (parts.size != 2) return 0
        return (parts[0].toIntOrNull() ?: 0) * 60 + (parts[1].toIntOrNull() ?: 0)
    }

    private fun dayOffsetText(offset: Int): String {
        return when (offset) {
            0 -> "今天"
            1 -> "明天"
            -1 -> "昨天"
            2 -> "后天"
            -2 -> "前天"
            else -> if (offset > 0) "${offset}天后" else "${-offset}天前"
        }
    }

    private fun weekdayText(calendar: Calendar): String {
        return when (todayWeekday(calendar)) {
            1 -> "星期一"
            2 -> "星期二"
            3 -> "星期三"
            4 -> "星期四"
            5 -> "星期五"
            6 -> "星期六"
            else -> "星期日"
        }
    }

    private fun shortLocation(location: String): String {
        return location.replace(Regex("\\(.*?\\)"), "").trim()
    }

    private fun buildMetaText(
        location: String,
        activeWeeks: List<Int>,
        currentWeek: Int,
        totalWeeks: Int,
    ): String {
        val parts = mutableListOf(location)
        if (currentWeek > 0 && totalWeeks > 0) {
            parts += "第$currentWeek/${totalWeeks}周"
        }

        val weekSummary = formatWeekSummary(activeWeeks)
        if (weekSummary.isNotBlank()) {
            parts += weekSummary
        }

        return parts.joinToString(" · ")
    }

    private fun formatWeekSummary(activeWeeks: List<Int>): String {
        val weeks = activeWeeks.filter { it > 0 }.distinct().sorted()
        if (weeks.isEmpty()) return "仅本次"

        val parts = mutableListOf<String>()
        var rangeStart = weeks.first()
        var previous = weeks.first()
        for (index in 1 until weeks.size) {
            val current = weeks[index]
            if (current == previous + 1) {
                previous = current
                continue
            }
            parts += weekRangeText(rangeStart, previous)
            rangeStart = current
            previous = current
        }
        parts += weekRangeText(rangeStart, previous)

        val summary = parts.joinToString("、")
        return if (summary.length <= 16) summary else summary.take(15) + "…"
    }

    private fun weekRangeText(start: Int, end: Int): String {
        return if (start == end) "${start}周" else "${start}-${end}周"
    }

    private fun ringProgress(currentWeek: Int, totalWeeks: Int): Float {
        if (currentWeek <= 0 || totalWeeks <= 0) return 0f
        return (currentWeek.toFloat() / totalWeeks.toFloat()).coerceIn(0f, 1f)
    }

    private fun weekValueText(currentWeek: Int, totalWeeks: Int): String {
        return if (currentWeek > 0 && totalWeeks > 0) {
            "$currentWeek/$totalWeeks"
        } else {
            "--"
        }
    }

    private fun createProgressRingBitmap(
        context: Context,
        progress: Float,
        color: Int,
    ): Bitmap {
        val sizePx = dpToPx(context, 46f)
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val strokeWidth = dpToPx(context, 2.4f).toFloat()
        val inset = strokeWidth / 2f + dpToPx(context, 4f)
        val rect = RectF(
            inset,
            inset,
            sizePx.toFloat() - inset,
            sizePx.toFloat() - inset,
        )

        val basePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            this.strokeWidth = strokeWidth
            this.color = blendAlpha(color, 0.14f)
        }
        val progressPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
            this.strokeWidth = strokeWidth
            this.color = blendAlpha(color, 0.92f)
        }
        val haloPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            this.strokeWidth = dpToPx(context, 0.8f).toFloat()
            this.color = Color.argb(52, 255, 255, 255)
        }

        val radius = (min(sizePx, sizePx) - strokeWidth) / 2f - dpToPx(context, 3f)
        canvas.drawCircle(sizePx / 2f, sizePx / 2f, radius, haloPaint)
        canvas.drawArc(rect, 0f, 360f, false, basePaint)
        if (progress > 0f) {
            canvas.drawArc(rect, -90f, 360f * progress, false, progressPaint)
        }

        return bitmap
    }

    private fun blendAlpha(color: Int, factor: Float): Int {
        val alpha = (Color.alpha(color) * factor).toInt().coerceIn(0, 255)
        return Color.argb(alpha, Color.red(color), Color.green(color), Color.blue(color))
    }

    private fun dpToPx(context: Context, dp: Float): Int {
        return (dp * context.resources.displayMetrics.density).toInt().coerceAtLeast(1)
    }

    private fun loadIndicators(context: Context): WidgetIndicators {
        return runCatching {
            val prefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            val reminderEnabled =
                readFlutterInt(prefs, KEY_REMINDER_LEAD_MINUTES, defaultValue = 0) > 0
            val silenceEnabled =
                readFlutterBoolean(prefs, KEY_CLASS_SILENCE_ENABLED, defaultValue = false) &&
                    hasNotificationPolicyAccess(context)
            WidgetIndicators(
                reminderEnabled = reminderEnabled,
                silenceEnabled = silenceEnabled,
            )
        }.getOrElse { error ->
            Log.w(TAG, "Failed to load widget indicators", error)
            WidgetIndicators(
                reminderEnabled = false,
                silenceEnabled = false,
            )
        }
    }

    private fun readFlutterInt(
        prefs: SharedPreferences,
        key: String,
        defaultValue: Int,
    ): Int {
        return when (val value = prefs.all[flutterKey(key)]) {
            is Int -> value
            is Long -> value.toInt()
            is Float -> value.toInt()
            is Double -> value.toInt()
            is String -> value.toIntOrNull() ?: defaultValue
            else -> defaultValue
        }
    }

    private fun readFlutterBoolean(
        prefs: SharedPreferences,
        key: String,
        defaultValue: Boolean,
    ): Boolean {
        return when (val value = prefs.all[flutterKey(key)]) {
            is Boolean -> value
            is String -> value.toBooleanStrictOrNull() ?: defaultValue
            else -> defaultValue
        }
    }

    private fun hasNotificationPolicyAccess(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                ?: return false
        return manager.isNotificationPolicyAccessGranted
    }

    private fun parseColor(value: Int): Int {
        return if (value == 0) Color.parseColor("#5B8FF9") else value
    }

    private fun createLaunchIntent(context: Context): PendingIntent? {
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(Intent.ACTION_MAIN).apply {
                `package` = context.packageName
            }
        launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        return PendingIntent.getActivity(context, 1001, launchIntent, flags)
    }

    private fun createActionIntent(
        context: Context,
        action: String,
        appWidgetId: Int,
        requestCode: Int,
    ): PendingIntent {
        val intent = Intent(context, WidgetActionReceiver::class.java).apply {
            this.action = action
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        }

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        return PendingIntent.getBroadcast(context, requestCode, intent, flags)
    }

    private fun resolveAppearance(context: Context): WidgetAppearance {
        val useDark = shouldUseDarkAppearance(context)
        return if (useDark) {
            WidgetAppearance(
                rootBackgroundRes = R.drawable.widget_background_glass_dark,
                cardBackgroundRes = R.drawable.widget_course_glass_dark,
                badgeBackgroundRes = R.drawable.widget_badge_glass_dark,
                navButtonBackgroundRes = R.drawable.widget_nav_btn_bg_dark,
                navActiveBackgroundRes = R.drawable.widget_nav_btn_active_bg_dark,
                colors = WidgetColors(
                    title = Color.parseColor("#F7FAFF"),
                    subtitle = Color.parseColor("#B8C8DD"),
                    hint = Color.parseColor("#8FA4BF"),
                    accent = Color.parseColor("#A8CEFF"),
                    button = Color.parseColor("#EDF4FF"),
                    ongoing = Color.parseColor("#9CEFFF"),
                    upcoming = Color.parseColor("#D9E4FF"),
                    divider = Color.parseColor("#25405A"),
                    sunAccent = Color.parseColor("#FFD7A4"),
                ),
            )
        } else {
            WidgetAppearance(
                rootBackgroundRes = R.drawable.widget_background_glass,
                cardBackgroundRes = R.drawable.widget_course_glass,
                badgeBackgroundRes = R.drawable.widget_badge_glass,
                navButtonBackgroundRes = R.drawable.widget_nav_btn_bg_light,
                navActiveBackgroundRes = R.drawable.widget_nav_btn_active_bg_light,
                colors = WidgetColors(
                    title = Color.parseColor("#12243C"),
                    subtitle = Color.parseColor("#60728B"),
                    hint = Color.parseColor("#8192A5"),
                    accent = Color.parseColor("#2A67DB"),
                    button = Color.parseColor("#24415F"),
                    ongoing = Color.parseColor("#0A7B86"),
                    upcoming = Color.parseColor("#2A67DB"),
                    divider = Color.parseColor("#D8E5EF"),
                    sunAccent = Color.parseColor("#C46A49"),
                ),
            )
        }
    }

    private fun shouldUseDarkAppearance(context: Context): Boolean {
        val prefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        val followSystem = prefs.getBoolean(flutterKey(KEY_FOLLOW_SYSTEM), false)
        return if (followSystem) {
            isSystemDarkMode(context)
        } else {
            isDarkThemeId(prefs.getString(flutterKey(KEY_THEME_ID), DEFAULT_THEME_ID))
        }
    }

    private fun isSystemDarkMode(context: Context): Boolean {
        val nightMode = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
        return nightMode == Configuration.UI_MODE_NIGHT_YES
    }

    private fun isDarkThemeId(themeId: String?): Boolean {
        return themeId == "dark" || themeId == "purple"
    }

    private fun offsetKey(appWidgetId: Int): String = "offset_$appWidgetId"

    data class WidgetAppearance(
        val rootBackgroundRes: Int,
        val cardBackgroundRes: Int,
        val badgeBackgroundRes: Int,
        val navButtonBackgroundRes: Int,
        val navActiveBackgroundRes: Int,
        val colors: WidgetColors,
    )

    data class WidgetColors(
        val title: Int,
        val subtitle: Int,
        val hint: Int,
        val accent: Int,
        val button: Int,
        val ongoing: Int,
        val upcoming: Int,
        val divider: Int,
        val sunAccent: Int,
    )

    data class WidgetIndicators(
        val reminderEnabled: Boolean,
        val silenceEnabled: Boolean,
    )

    companion object {
        private const val HOME_WIDGET_PREFS = "HomeWidgetPreferences"
        private const val FLUTTER_PREFS = "FlutterSharedPreferences"
        private const val STATE_PREFS = "hai_schedule_widget_state"
        private const val KEY_PAYLOAD = "hai_schedule_widget_payload"
        private const val KEY_FOLLOW_SYSTEM = "follow_system_theme"
        private const val KEY_THEME_ID = "theme_id"
        private const val KEY_REMINDER_LEAD_MINUTES = "class_reminder_lead_minutes"
        private const val KEY_CLASS_SILENCE_ENABLED = "class_silence_enabled"
        private const val DEFAULT_THEME_ID = "blue"
        private const val TAG = "TodayScheduleWidget"

        const val ACTION_PREV = "com.hainanu.hai_schedule.widget.PREV"
        const val ACTION_TODAY = "com.hainanu.hai_schedule.widget.TODAY"
        const val ACTION_NEXT = "com.hainanu.hai_schedule.widget.NEXT"

        private fun flutterKey(key: String): String = "flutter.$key"

        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, TodayScheduleWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(component)
            val widgetData = context.getSharedPreferences(HOME_WIDGET_PREFS, Context.MODE_PRIVATE)
            ids.forEach { id ->
                try {
                    val views = TodayScheduleWidgetProvider().buildRemoteViews(context, id, widgetData)
                    manager.updateAppWidget(id, views)
                } catch (t: Throwable) {
                    Log.e(TAG, "Failed to refresh widget $id", t)
                }
            }
        }
    }
}

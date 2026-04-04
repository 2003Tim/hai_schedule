package com.hainanu.hai_schedule

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Color
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import java.util.Locale
import java.text.SimpleDateFormat

/**
 * 浠婃棩璇捐〃 4x2 妗岄潰灏忕粍浠讹紙绗簩闃舵淇鐗堬級
 * - 澶撮儴鍥哄畾鍦ㄩ《閮? * - 鍐呭鍖哄崟鐙脊鎬у竷灞€
 * - 绌虹姸鎬佸彧褰卞搷鍐呭鍖猴紝涓嶅啀鎶婃棩鏈熷拰鎸夐挳鏁翠綋灞呬腑
 */
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

        val action = intent.action ?: return
        if (action == Intent.ACTION_CONFIGURATION_CHANGED) {
            refreshAll(context)
            return
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
        val views = buildRemoteViews(context, appWidgetId, widgetData)
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun buildRemoteViews(
        context: Context,
        appWidgetId: Int,
        widgetData: SharedPreferences,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_today_schedule)
        val appearance = resolveAppearance(context)
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

        return try {
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
            )

            bindHeader(
                views = views,
                target = target,
                weekdayText = weekdayText(target),
                currentWeek = currentWeek,
                count = daySlots.length(),
                dayOffset = dayOffset,
            )
            bindList(views, daySlots, dayLabel, appearance.colors)
            views
        } catch (e: Exception) {
            bindHeader(
                views = views,
                target = target,
                weekdayText = weekdayText(target),
                currentWeek = 0,
                count = 0,
                dayOffset = dayOffset,
            )
            bindEmptyState(views, "小组件数据异常", e.message ?: "解析失败")
            views
        }
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
        views.setInt(
            R.id.btn_prev,
            "setBackgroundResource",
            appearance.navButtonBackgroundRes,
        )
        views.setInt(
            R.id.btn_next,
            "setBackgroundResource",
            appearance.navButtonBackgroundRes,
        )
        views.setInt(
            R.id.btn_today,
            "setBackgroundResource",
            if (dayOffset == 0) {
                appearance.navActiveBackgroundRes
            } else {
                appearance.navButtonBackgroundRes
            },
        )
    }

    private fun bindStaticTheme(views: RemoteViews, appearance: WidgetAppearance) {
        views.setInt(
            R.id.widget_root,
            "setBackgroundResource",
            appearance.rootBackgroundRes,
        )
        views.setInt(
            R.id.course_1,
            "setBackgroundResource",
            appearance.cardBackgroundRes,
        )
        views.setInt(
            R.id.course_2,
            "setBackgroundResource",
            appearance.cardBackgroundRes,
        )
        views.setTextColor(R.id.header_date, appearance.colors.title)
        views.setTextColor(R.id.header_week, appearance.colors.subtitle)
        views.setInt(R.id.top_divider, "setBackgroundColor", appearance.colors.divider)
        views.setTextColor(R.id.empty_text, appearance.colors.title)
        views.setTextColor(R.id.empty_subtext, appearance.colors.hint)
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
        views.setTextViewText(R.id.empty_text, title)
        views.setTextViewText(R.id.empty_subtext, subtitle)
    }

    private fun bindList(
        views: RemoteViews,
        daySlots: JSONArray,
        dayLabel: String,
        colors: WidgetColors,
    ) {
        if (daySlots.length() == 0) {
            bindEmptyState(views, "$dayLabel 没有课", "点左右切换日期，中间按钮回到今天")
            return
        }

        views.setViewVisibility(R.id.empty_container, View.GONE)
        views.setViewVisibility(R.id.course_list_container, View.VISIBLE)

        bindRow(views, 0, daySlots, colors)
        bindRow(views, 1, daySlots, colors)

        val extra = daySlots.length() - 2
        if (extra > 0) {
            views.setViewVisibility(R.id.more_text, View.VISIBLE)
            views.setTextViewText(R.id.more_text, "还有 ${extra} 节课程未显示")
        } else {
            views.setViewVisibility(R.id.more_text, View.GONE)
        }
    }

    private fun bindRow(
        views: RemoteViews,
        index: Int,
        daySlots: JSONArray,
        colors: WidgetColors,
    ) {
        val rootIds = intArrayOf(R.id.course_1, R.id.course_2)
        val indicatorIds = intArrayOf(R.id.course_indicator_1, R.id.course_indicator_2)
        val titleIds = intArrayOf(R.id.course_title_1, R.id.course_title_2)
        val metaIds = intArrayOf(R.id.course_meta_1, R.id.course_meta_2)
        val statusIds = intArrayOf(R.id.course_status_1, R.id.course_status_2)

        if (index >= daySlots.length()) {
            views.setViewVisibility(rootIds[index], View.GONE)
            return
        }

        val item = daySlots.getJSONObject(index)
        views.setViewVisibility(rootIds[index], View.VISIBLE)
        views.setTextViewText(titleIds[index], item.optString("courseName"))
        views.setTextColor(titleIds[index], colors.title)
        views.setTextViewText(metaIds[index], item.optString("meta"))
        views.setTextColor(metaIds[index], colors.subtitle)
        views.setTextViewText(statusIds[index], item.optString("statusText"))
        views.setInt(indicatorIds[index], "setBackgroundColor", parseColor(item.optInt("color")))

        val statusColor = when (item.optString("status")) {
            "ongoing" -> colors.ongoing
            "upcoming" -> colors.upcoming
            else -> colors.hint
        }
        views.setTextColor(statusIds[index], statusColor)
    }

    private fun buildDayItems(
        payload: ScheduleProjectionSupport.ProjectionPayload,
        now: Calendar,
        target: Calendar,
        dayRelation: Int,
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
                dayRelation < 0 -> "已上过"
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

            val location = shortLocation(effectiveSlot.location)
            val teacher = shortTeacher(effectiveSlot.teacher)
            val meta = buildMetaText(startTime, endTime, location, teacher)

            list.add(
                JSONObject().apply {
                    put("courseName", effectiveSlot.courseName)
                    put("meta", meta)
                    put("status", status)
                    put("statusText", statusText)
                    put("sortKey", effectiveSlot.startSection)
                    put("color", effectiveSlot.color.takeIf { it != 0 } ?: Color.parseColor("#5B8FF9"))
                }
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

    private fun shortTeacher(teacher: String): String {
        return teacher
            .split(',', '，')
            .firstOrNull()
            ?.trim()
            .orEmpty()
    }

    private fun buildMetaText(
        startTime: String,
        endTime: String,
        location: String,
        teacher: String,
    ): String {
        return buildString {
            append("$startTime-$endTime")
            if (location.isNotBlank()) {
                append(" · $location")
            }
            if (teacher.isNotBlank()) {
                append(" · $teacher")
            }
        }
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
                rootBackgroundRes = R.drawable.widget_today_bg_dark,
                cardBackgroundRes = R.drawable.widget_today_card_bg_dark,
                navButtonBackgroundRes = R.drawable.widget_nav_btn_bg_dark,
                navActiveBackgroundRes = R.drawable.widget_nav_btn_active_bg_dark,
                colors = WidgetColors(
                    title = Color.parseColor("#F7FAFF"),
                    subtitle = Color.parseColor("#B7C4DB"),
                    hint = Color.parseColor("#8EA0BA"),
                    accent = Color.parseColor("#9FC8FF"),
                    button = Color.parseColor("#ECF3FF"),
                    ongoing = Color.parseColor("#A9F0FF"),
                    upcoming = Color.parseColor("#D8E1FF"),
                    divider = Color.parseColor("#24344D"),
                ),
            )
        } else {
            WidgetAppearance(
                rootBackgroundRes = R.drawable.widget_today_bg_light,
                cardBackgroundRes = R.drawable.widget_today_card_bg_light,
                navButtonBackgroundRes = R.drawable.widget_nav_btn_bg_light,
                navActiveBackgroundRes = R.drawable.widget_nav_btn_active_bg_light,
                colors = WidgetColors(
                    title = Color.parseColor("#15253D"),
                    subtitle = Color.parseColor("#5E718B"),
                    hint = Color.parseColor("#8090A4"),
                    accent = Color.parseColor("#2158C7"),
                    button = Color.parseColor("#24415F"),
                    ongoing = Color.parseColor("#006D77"),
                    upcoming = Color.parseColor("#2158C7"),
                    divider = Color.parseColor("#D7E0EA"),
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
    )

    companion object {
        private const val HOME_WIDGET_PREFS = "HomeWidgetPreferences"
        private const val FLUTTER_PREFS = "FlutterSharedPreferences"
        private const val STATE_PREFS = "hai_schedule_widget_state"
        private const val KEY_PAYLOAD = "hai_schedule_widget_payload"
        private const val KEY_FOLLOW_SYSTEM = "follow_system_theme"
        private const val KEY_THEME_ID = "theme_id"
        private const val DEFAULT_THEME_ID = "blue"

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
                val views = TodayScheduleWidgetProvider().buildRemoteViews(context, id, widgetData)
                manager.updateAppWidget(id, views)
            }
        }
    }
}

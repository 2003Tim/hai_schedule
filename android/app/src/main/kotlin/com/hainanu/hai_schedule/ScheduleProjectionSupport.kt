package com.hainanu.hai_schedule

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.TimeUnit

object ScheduleProjectionSupport {
    private const val homeWidgetPrefs = "HomeWidgetPreferences"
    private const val payloadKey = "hai_schedule_widget_payload"

    const val schemaVersion = 2
    private val supportedSchemaVersions = setOf(1, schemaVersion)
    private val defaultClassTimes = listOf(
        ProjectionClassTime(section = 1, startTime = "07:40", endTime = "08:25"),
        ProjectionClassTime(section = 2, startTime = "08:35", endTime = "09:20"),
        ProjectionClassTime(section = 3, startTime = "09:45", endTime = "10:30"),
        ProjectionClassTime(section = 4, startTime = "10:40", endTime = "11:25"),
        ProjectionClassTime(section = 5, startTime = "14:30", endTime = "15:15"),
        ProjectionClassTime(section = 6, startTime = "15:25", endTime = "16:10"),
        ProjectionClassTime(section = 7, startTime = "16:35", endTime = "17:20"),
        ProjectionClassTime(section = 8, startTime = "17:30", endTime = "18:15"),
        ProjectionClassTime(section = 9, startTime = "19:20", endTime = "20:05"),
        ProjectionClassTime(section = 10, startTime = "20:15", endTime = "21:00"),
        ProjectionClassTime(section = 11, startTime = "21:10", endTime = "21:55"),
    )

    fun loadStoredPayload(context: Context): ProjectionPayload? {
        val prefs = context.getSharedPreferences(homeWidgetPrefs, Context.MODE_PRIVATE)
        return parsePayload(prefs.getString(payloadKey, null))
    }

    fun savePayload(context: Context, payload: ProjectionPayload) {
        val prefs = context.getSharedPreferences(homeWidgetPrefs, Context.MODE_PRIVATE)
        prefs.edit().putString(payloadKey, payload.toJson().toString()).apply()
    }

    fun createPayload(
        semesterStart: String,
        totalWeeks: Int,
        classTimes: List<ProjectionClassTime>,
        slots: List<ProjectionSlot>,
        overrides: List<ProjectionOverride>,
        generatedAt: String? = null,
    ): ProjectionPayload {
        return ProjectionPayload(
            generatedAt = generatedAt ?: utcTimestamp(System.currentTimeMillis()),
            semesterStart = semesterStart,
            totalWeeks = totalWeeks,
            classTimes = classTimes,
            slots = slots,
            overrides = overrides,
        )
    }

    fun loadClassTimes(rawSchoolTimeConfig: String?): List<ProjectionClassTime> {
        if (!rawSchoolTimeConfig.isNullOrBlank()) {
            try {
                val root = JSONObject(rawSchoolTimeConfig)
                val source = root.optJSONArray("classTimes")
                if (source != null && source.length() > 0) {
                    return parseClassTimes(source)
                }
            } catch (_: Throwable) {
            }
        }
        return defaultClassTimes
    }

    fun parseOverrides(
        rawOverrides: String?,
        semester: String,
    ): List<ProjectionOverride> {
        if (rawOverrides.isNullOrBlank()) return emptyList()

        val source = try {
            JSONArray(rawOverrides)
        } catch (_: Throwable) {
            return emptyList()
        }

        return buildList {
            for (index in 0 until source.length()) {
                val item = source.optJSONObject(index) ?: continue
                if (item.optString("semesterCode") != semester) continue
                add(
                    ProjectionOverride(
                        id = item.optString("id"),
                        semesterCode = item.optString("semesterCode"),
                        dateKey = item.optString("dateKey"),
                        weekday = item.optInt("weekday"),
                        startSection = item.optInt("startSection"),
                        endSection = item.optInt("endSection"),
                        type = item.optString("type"),
                        targetCourseId = item.optString("targetCourseId"),
                        courseName = item.optString("courseName"),
                        teacher = item.optString("teacher"),
                        location = item.optString("location"),
                        status = item.optString("status", "normal"),
                        sourceStartSection = optNullableInt(item, "sourceStartSection"),
                        sourceEndSection = optNullableInt(item, "sourceEndSection"),
                        activeWeeks = parseWeeks(item.optJSONArray("activeWeeks")),
                        color = item.optInt("color"),
                    ),
                )
            }
        }
    }

    fun semesterStartForCode(code: String): String {
        val startYear = code.take(4).toIntOrNull() ?: return firstMondayOnOrAfter(2026, 3, 1)
        val month = if (code.endsWith("1")) 9 else 3
        val year = if (code.endsWith("1")) startYear else startYear + 1
        return firstMondayOnOrAfter(year, month, 1)
    }

    fun parsePayload(payloadText: String?): ProjectionPayload? {
        if (payloadText.isNullOrBlank()) return null
        return try {
            val root = JSONObject(payloadText)
            val version = root.optInt("schemaVersion", 0)
            if (!supportedSchemaVersions.contains(version)) {
                return null
            }

            ProjectionPayload(
                generatedAt = root.optString("generatedAt").ifBlank { null },
                semesterStart = root.optString("semesterStart"),
                totalWeeks = root.optInt("totalWeeks", 20),
                classTimes = parseClassTimes(root.optJSONArray("classTimes") ?: JSONArray()),
                slots = parseSlots(root.optJSONArray("slots") ?: JSONArray()),
                overrides = parseProjectionOverrides(root.optJSONArray("overrides") ?: JSONArray()),
            )
        } catch (_: Throwable) {
            null
        }
    }

    data class ProjectionPayload(
        val generatedAt: String? = null,
        val semesterStart: String,
        val totalWeeks: Int,
        val classTimes: List<ProjectionClassTime>,
        val slots: List<ProjectionSlot>,
        val overrides: List<ProjectionOverride>,
    ) {
        fun toJson(): JSONObject {
            return JSONObject().apply {
                put("schemaVersion", schemaVersion)
                generatedAt?.let { put("generatedAt", it) }
                put("semesterStart", semesterStart)
                put("totalWeeks", totalWeeks)
                put(
                    "classTimes",
                    JSONArray().apply {
                        classTimes.forEach { put(it.toJson()) }
                    },
                )
                put(
                    "slots",
                    JSONArray().apply {
                        slots.forEach { put(it.toJson()) }
                    },
                )
                put(
                    "overrides",
                    JSONArray().apply {
                        overrides.forEach { put(it.toJson()) }
                    },
                )
            }
        }

        fun calculateWeek(target: Calendar): Int {
            val rawWeek = rawWeekNumber(target)
            if (rawWeek <= 0) return 0
            return rawWeek.coerceIn(1, totalWeeks)
        }

        fun resolveDaySlots(target: Calendar): List<ResolvedProjectionSlot> {
            val rawWeek = rawWeekNumber(target)
            if (rawWeek !in 1..totalWeeks) {
                return emptyList()
            }

            val weekday = weekdayFor(target)
            val dateKey = formatDateKey(target)
            val dayOverrides = overrides.filter {
                it.dateKey == dateKey && it.weekday == weekday
            }

            val resolved = mutableListOf<ResolvedProjectionSlot>()
            for (slot in slots) {
                if (slot.weekday != weekday || rawWeek !in slot.activeWeeks) {
                    continue
                }
                val cancelOverride = dayOverrides.firstOrNull { item ->
                    item.type == "cancel" &&
                        item.status != "orphaned" &&
                        matchesSource(item, slot)
                }
                if (cancelOverride != null) {
                    continue
                }

                val modifyOverride = dayOverrides.firstOrNull { item ->
                    item.type == "modify" &&
                        item.status != "orphaned" &&
                        matchesSource(item, slot)
                }
                if (modifyOverride != null) {
                    resolved.add(
                        ResolvedProjectionSlot(
                            courseId = slot.courseId,
                            courseName = modifyOverride.courseName.ifBlank { slot.courseName },
                            teacher = modifyOverride.teacher.ifBlank { slot.teacher },
                            location = modifyOverride.location.ifBlank { slot.location },
                            weekday = weekday,
                            startSection = modifyOverride.startSection,
                            endSection = modifyOverride.endSection,
                            activeWeeks = modifyOverride.activeWeeks.ifEmpty { slot.activeWeeks },
                            color = modifyOverride.color.takeIf { it != 0 } ?: slot.color,
                        ),
                    )
                    continue
                }

                resolved.add(
                    ResolvedProjectionSlot(
                        courseId = slot.courseId,
                        courseName = slot.courseName,
                        teacher = slot.teacher,
                        location = slot.location,
                        weekday = slot.weekday,
                        startSection = slot.startSection,
                        endSection = slot.endSection,
                        activeWeeks = slot.activeWeeks,
                        color = slot.color,
                    ),
                )
            }

            dayOverrides.asSequence()
                .filter { it.type == "add" && it.status != "orphaned" }
                .forEach { item ->
                    resolved.add(
                        ResolvedProjectionSlot(
                            courseId = item.id.ifBlank { "override-${item.dateKey}-${item.startSection}" },
                            courseName = item.courseName.ifBlank { "临时课程" },
                            teacher = item.teacher,
                            location = item.location,
                            weekday = weekday,
                            startSection = item.startSection,
                            endSection = item.endSection,
                            activeWeeks = item.activeWeeks.ifEmpty { listOf(rawWeek) },
                            color = item.color,
                        ),
                    )
                }

            return resolved.sortedBy { it.startSection }
        }

        fun buildOccurrences(now: Calendar, horizonDays: Int): List<ResolvedProjectionOccurrence> {
            val startOfDay = (now.clone() as Calendar).apply {
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val endOfHorizon = (now.clone() as Calendar).apply {
                add(Calendar.DAY_OF_YEAR, horizonDays)
            }

            val occurrences = mutableListOf<ResolvedProjectionOccurrence>()
            for (offset in 0..horizonDays) {
                val target = (startOfDay.clone() as Calendar).apply {
                    add(Calendar.DAY_OF_YEAR, offset)
                }
                for (slot in resolveDaySlots(target)) {
                    val startTime = findTime(slot.startSection, true)
                    val endTime = findTime(slot.endSection, false)
                    if (startTime == null || endTime == null) continue

                    val startAt = dateTimeFor(target, startTime) ?: continue
                    val endAt = dateTimeFor(target, endTime) ?: continue
                    if (endAt <= now.timeInMillis) continue
                    if (startAt > endOfHorizon.timeInMillis) continue

                    occurrences.add(
                        ResolvedProjectionOccurrence(
                            courseId = slot.courseId,
                            courseName = slot.courseName,
                            teacher = slot.teacher,
                            location = slot.location,
                            weekday = slot.weekday,
                            dateKey = formatDateKey(target),
                            startSection = slot.startSection,
                            endSection = slot.endSection,
                            startTime = startTime,
                            endTime = endTime,
                            startAtMillis = startAt,
                            endAtMillis = endAt,
                            color = slot.color,
                        ),
                    )
                }
            }
            return occurrences.sortedBy { it.startAtMillis }
        }

        fun findTime(section: Int, isStart: Boolean): String? {
            val classTime = classTimes.firstOrNull { it.section == section } ?: return null
            return if (isStart) classTime.startTime else classTime.endTime
        }

        private fun rawWeekNumber(target: Calendar): Int {
            val parser = SimpleDateFormat("yyyy-MM-dd", Locale.US).apply {
                isLenient = false
            }
            val startDate = parser.parse(semesterStart) ?: return 0
            val start = Calendar.getInstance().apply {
                time = startDate
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val day = (target.clone() as Calendar).apply {
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val diffDays = TimeUnit.MILLISECONDS.toDays(day.timeInMillis - start.timeInMillis).toInt()
            if (diffDays < 0) return 0
            return diffDays / 7 + 1
        }

        private fun dateTimeFor(target: Calendar, timeText: String): Long? {
            val parts = timeText.split(":")
            if (parts.size != 2) return null
            val hour = parts[0].toIntOrNull() ?: return null
            val minute = parts[1].toIntOrNull() ?: return null
            return (target.clone() as Calendar).apply {
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }.timeInMillis
        }
    }

    data class ProjectionClassTime(
        val section: Int,
        val startTime: String,
        val endTime: String,
    ) {
        fun toJson(): JSONObject {
            return JSONObject().apply {
                put("section", section)
                put("startTime", startTime)
                put("endTime", endTime)
            }
        }
    }

    data class ProjectionSlot(
        val courseId: String,
        val courseName: String,
        val teacher: String,
        val location: String,
        val weekday: Int,
        val startSection: Int,
        val endSection: Int,
        val activeWeeks: List<Int>,
        val color: Int,
    ) {
        fun toJson(): JSONObject {
            return JSONObject().apply {
                put("courseId", courseId)
                put("courseName", courseName)
                put("teacher", teacher)
                put("location", location)
                put("weekday", weekday)
                put("startSection", startSection)
                put("endSection", endSection)
                put("activeWeeks", JSONArray(activeWeeks))
                put("color", color)
            }
        }
    }

    data class ProjectionOverride(
        val id: String,
        val semesterCode: String,
        val dateKey: String,
        val weekday: Int,
        val startSection: Int,
        val endSection: Int,
        val type: String,
        val targetCourseId: String,
        val courseName: String,
        val teacher: String,
        val location: String,
        val status: String,
        val sourceStartSection: Int?,
        val sourceEndSection: Int?,
        val activeWeeks: List<Int>,
        val color: Int,
    ) {
        fun toJson(): JSONObject {
            return JSONObject().apply {
                put("id", id)
                put("semesterCode", semesterCode)
                put("dateKey", dateKey)
                put("weekday", weekday)
                put("startSection", startSection)
                put("endSection", endSection)
                put("type", type)
                put("targetCourseId", targetCourseId)
                put("courseName", courseName)
                put("teacher", teacher)
                put("location", location)
                put("status", status)
                if (sourceStartSection != null) {
                    put("sourceStartSection", sourceStartSection)
                }
                if (sourceEndSection != null) {
                    put("sourceEndSection", sourceEndSection)
                }
                put("activeWeeks", JSONArray(activeWeeks))
                put("color", color)
            }
        }
    }

    data class ResolvedProjectionSlot(
        val courseId: String,
        val courseName: String,
        val teacher: String,
        val location: String,
        val weekday: Int,
        val startSection: Int,
        val endSection: Int,
        val activeWeeks: List<Int>,
        val color: Int,
    )

    data class ResolvedProjectionOccurrence(
        val courseId: String,
        val courseName: String,
        val teacher: String,
        val location: String,
        val weekday: Int,
        val dateKey: String,
        val startSection: Int,
        val endSection: Int,
        val startTime: String,
        val endTime: String,
        val startAtMillis: Long,
        val endAtMillis: Long,
        val color: Int,
    )

    private fun parseClassTimes(source: JSONArray): List<ProjectionClassTime> {
        return buildList {
            for (index in 0 until source.length()) {
                val item = source.optJSONObject(index) ?: continue
                add(
                    ProjectionClassTime(
                        section = item.optInt("section"),
                        startTime = item.optString("startTime"),
                        endTime = item.optString("endTime"),
                    ),
                )
            }
        }
    }

    private fun parseSlots(source: JSONArray): List<ProjectionSlot> {
        return buildList {
            for (index in 0 until source.length()) {
                val item = source.optJSONObject(index) ?: continue
                add(
                    ProjectionSlot(
                        courseId = item.optString("courseId"),
                        courseName = item.optString("courseName"),
                        teacher = item.optString("teacher"),
                        location = item.optString("location"),
                        weekday = item.optInt("weekday"),
                        startSection = item.optInt("startSection"),
                        endSection = item.optInt("endSection"),
                        activeWeeks = buildList {
                            val weeks = item.optJSONArray("activeWeeks") ?: JSONArray()
                            for (weekIndex in 0 until weeks.length()) {
                                add(weeks.optInt(weekIndex))
                            }
                        },
                        color = item.optInt("color"),
                    ),
                )
            }
        }
    }

    private fun parseProjectionOverrides(source: JSONArray): List<ProjectionOverride> {
        return buildList {
            for (index in 0 until source.length()) {
                val item = source.optJSONObject(index) ?: continue
                add(
                    ProjectionOverride(
                        id = item.optString("id"),
                        semesterCode = item.optString("semesterCode"),
                        dateKey = item.optString("dateKey"),
                        weekday = item.optInt("weekday"),
                        startSection = item.optInt("startSection"),
                        endSection = item.optInt("endSection"),
                        type = item.optString("type"),
                        targetCourseId = item.optString("targetCourseId"),
                        courseName = item.optString("courseName"),
                        teacher = item.optString("teacher"),
                        location = item.optString("location"),
                        status = item.optString("status", "normal"),
                        sourceStartSection = optNullableInt(item, "sourceStartSection"),
                        sourceEndSection = optNullableInt(item, "sourceEndSection"),
                        activeWeeks = parseWeeks(item.optJSONArray("activeWeeks")),
                        color = item.optInt("color"),
                    ),
                )
            }
        }
    }

    private fun parseWeeks(source: JSONArray?): List<Int> {
        if (source == null) return emptyList()
        return buildList {
            for (index in 0 until source.length()) {
                add(source.optInt(index))
            }
        }
    }

    private fun matchesSource(override: ProjectionOverride, slot: ProjectionSlot): Boolean {
        val targetCourseId = override.targetCourseId.takeIf { it.isNotBlank() }
        if (targetCourseId != null && targetCourseId != slot.courseId) {
            return false
        }

        val hasExplicitSourceSections =
            override.sourceStartSection != null || override.sourceEndSection != null
        if (hasExplicitSourceSections) {
            val sourceStart = override.sourceStartSection ?: override.startSection
            val sourceEnd = override.sourceEndSection ?: override.endSection
            return sourceStart == slot.startSection && sourceEnd == slot.endSection
        }

        if (targetCourseId != null) {
            return if (override.type == "modify") {
                true
            } else {
                slot.startSection == override.startSection &&
                    slot.endSection == override.endSection
            }
        }

        return slot.startSection == override.startSection &&
            slot.endSection == override.endSection
    }

    private fun optNullableInt(item: JSONObject, key: String): Int? {
        if (!item.has(key) || item.isNull(key)) return null
        return item.optInt(key)
    }

    fun weekdayFor(calendar: Calendar): Int {
        return when (calendar.get(Calendar.DAY_OF_WEEK)) {
            Calendar.SUNDAY -> 7
            else -> calendar.get(Calendar.DAY_OF_WEEK) - 1
        }
    }

    fun formatDateKey(calendar: Calendar): String {
        return String.format(
            Locale.US,
            "%04d-%02d-%02d",
            calendar.get(Calendar.YEAR),
            calendar.get(Calendar.MONTH) + 1,
            calendar.get(Calendar.DAY_OF_MONTH),
        )
    }

    private fun utcTimestamp(timeMillis: Long): String {
        val format = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        format.timeZone = TimeZone.getTimeZone("UTC")
        return format.format(Date(timeMillis))
    }

    private fun firstMondayOnOrAfter(year: Int, month: Int, dayOfMonth: Int): String {
        val calendar = Calendar.getInstance().apply {
            set(Calendar.YEAR, year)
            set(Calendar.MONTH, month - 1)
            set(Calendar.DAY_OF_MONTH, dayOfMonth)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        while (calendar.get(Calendar.DAY_OF_WEEK) != Calendar.MONDAY) {
            calendar.add(Calendar.DAY_OF_MONTH, 1)
        }
        return String.format(
            Locale.US,
            "%04d-%02d-%02d",
            calendar.get(Calendar.YEAR),
            calendar.get(Calendar.MONTH) + 1,
            calendar.get(Calendar.DAY_OF_MONTH),
        )
    }
}

package com.hainanu.hai_schedule

import org.json.JSONArray
import org.json.JSONObject
import java.util.regex.Pattern

object ScheduleNativeParser {
    private const val MAX_RAW_SCHEDULE_LENGTH = 5000
    private const val MAX_SECTION_COUNT = 20
    private val WEEKDAY_MAP = mapOf(
        "一" to 1,
        "二" to 2,
        "三" to 3,
        "四" to 4,
        "五" to 5,
        "六" to 6,
        "日" to 7,
        "天" to 7,
    )
    private val SLOT_PATTERN = Pattern.compile(
        "^\\s*(.+?)\\s*星期([一二三四五六日天])\\s*\\[(\\d+)(?:\\s*-\\s*(\\d+))?节\\]\\s*(.*)$",
    )
    private val COURSE_COLORS = intArrayOf(
        0xFF4E8DF5.toInt(),
        0xFF43C59E.toInt(),
        0xFFFC7B5D.toInt(),
        0xFF9B7FE6.toInt(),
        0xFFF5A623.toInt(),
        0xFF5BC0EB.toInt(),
        0xFFE85D75.toInt(),
        0xFF2EC4B6.toInt(),
        0xFFFF8A5C.toInt(),
        0xFF7B68EE.toInt(),
    )

    fun parseCourses(root: JSONObject): List<ParsedCourse> {
        val rows = extractRows(root) ?: return emptyList()
        return buildList {
            for (index in 0 until rows.length()) {
                val row = rows.optJSONObject(index) ?: continue
                val courseId = row.optString("WID")
                val courseName = row.optString("KCMC")
                val teacher = row.optString("RKJS")
                add(
                    ParsedCourse(
                        id = courseId,
                        code = row.optString("KCDM"),
                        name = courseName,
                        className = row.optString("BJMC"),
                        teacher = teacher,
                        college = row.optString("KKDW_DISPLAY"),
                        credits = row.optDouble("XF"),
                        totalHours = row.optInt("ZXS"),
                        semester = row.optString("XNXQDM_DISPLAY"),
                        campus = row.optString("XQDM_DISPLAY"),
                        teachingType = row.optString("SKFSDM_DISPLAY"),
                        slots = parseScheduleSlots(
                            courseId = courseId,
                            courseName = courseName,
                            teacher = teacher,
                            raw = scheduleExpressionFromRow(row),
                        ),
                    ),
                )
            }
        }
    }

    fun parseArchivedCourses(source: JSONArray): List<ParsedCourse> {
        return buildList {
            for (index in 0 until source.length()) {
                val item = source.optJSONObject(index) ?: continue
                add(
                    ParsedCourse(
                        id = item.optString("id"),
                        code = item.optString("code"),
                        name = item.optString("name"),
                        className = item.optString("className"),
                        teacher = item.optString("teacher"),
                        college = item.optString("college"),
                        credits = item.optDouble("credits"),
                        totalHours = item.optInt("totalHours"),
                        semester = item.optString("semester"),
                        campus = item.optString("campus"),
                        teachingType = item.optString("teachingType"),
                        slots = buildList {
                            val slotArray = item.optJSONArray("slots") ?: JSONArray()
                            for (slotIndex in 0 until slotArray.length()) {
                                val slot = slotArray.optJSONObject(slotIndex) ?: continue
                                add(
                                    ParsedSlot(
                                        courseId = slot.optString("courseId"),
                                        courseName = slot.optString("courseName"),
                                        teacher = slot.optString("teacher"),
                                        location = slot.optString("location"),
                                        weekday = slot.optInt("weekday"),
                                        startSection = slot.optInt("startSection"),
                                        endSection = slot.optInt("endSection"),
                                        activeWeeks = expandArchivedWeeks(slot.optJSONArray("weekRanges")),
                                        color = pickColor(slot.optString("courseName")),
                                    ),
                                )
                            }
                        },
                    ),
                )
            }
        }
    }

    private fun scheduleExpressionFromRow(row: JSONObject): String {
        val withLocation = row.optString("PKSJDD").trim()
        if (withLocation.isNotEmpty()) return withLocation
        return row.optString("PKSJ").trim()
    }

    private fun parseScheduleSlots(
        courseId: String,
        courseName: String,
        teacher: String,
        raw: String,
    ): List<ParsedSlot> {
        if (raw.isBlank() || raw.length > MAX_RAW_SCHEDULE_LENGTH) return emptyList()

        val slotsByKey = linkedMapOf<String, SlotAccumulator>()
        raw.split(Regex("[;；]"))
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .forEach { segment ->
                val slot = parseSingleSlot(
                    text = segment,
                    courseId = courseId,
                    courseName = courseName,
                    teacher = teacher,
                ) ?: return@forEach
                val key = listOf(
                    slot.weekday,
                    slot.startSection,
                    slot.endSection,
                    slot.location,
                ).joinToString("|")
                slotsByKey.getOrPut(key) { SlotAccumulator(slot) }
                    .addActiveWeeks(slot.activeWeeks)
            }

        return slotsByKey.values
            .map { it.toSlot() }
            .sortedWith(
                compareBy<ParsedSlot> { it.weekday }
                    .thenBy { it.startSection }
                    .thenBy { it.endSection },
            )
    }

    private fun parseSingleSlot(
        text: String,
        courseId: String,
        courseName: String,
        teacher: String,
    ): ParsedSlot? {
        val matcher = SLOT_PATTERN.matcher(text)
        if (!matcher.matches()) return null

        val weekText = matcher.group(1)?.trim() ?: return null
        val weekdayKey = matcher.group(2) ?: return null
        val weekday = WEEKDAY_MAP[weekdayKey] ?: return null
        val startSection = matcher.group(3)?.toIntOrNull() ?: return null
        val endSection = matcher.group(4)?.toIntOrNull() ?: startSection
        if (
            startSection < 1 ||
            startSection > MAX_SECTION_COUNT ||
            endSection < 1 ||
            endSection > MAX_SECTION_COUNT ||
            startSection > endSection
        ) {
            return null
        }

        val activeWeeks = parseWeeks(weekText)
        if (activeWeeks.isEmpty()) return null

        return ParsedSlot(
            courseId = courseId,
            courseName = courseName,
            teacher = teacher,
            location = matcher.group(5)?.trim() ?: "",
            weekday = weekday,
            startSection = startSection,
            endSection = endSection,
            activeWeeks = activeWeeks,
            color = pickColor(courseName),
        )
    }

    private fun parseWeeks(weekText: String): List<Int> {
        val normalized = weekText
            .replace('，', ',')
            .replace('（', '(')
            .replace('）', ')')
            .replace(Regex("\\s+"), "")
            .replace("第", "")
            .replace("教学周", "")
            .replace("周次", "")

        val weeks = linkedSetOf<Int>()
        normalized.split(',')
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .forEach { part ->
                val type = when {
                    part.contains("单") -> "odd"
                    part.contains("双") -> "even"
                    else -> "all"
                }
                val cleaned = part.replace(Regex("周|\\(|\\)|单|双"), "")
                if (cleaned.isBlank()) return@forEach
                if (cleaned.contains("-")) {
                    val pieces = cleaned.split("-")
                    if (pieces.size != 2) return@forEach
                    val start = pieces[0].trim().toIntOrNull()
                    val end = pieces[1].trim().toIntOrNull()
                    if (start == null || end == null) return@forEach
                    if (start < 1 || end > 53 || start > end) return@forEach
                    for (week in start..end) {
                        if (matchesWeekType(week, type)) weeks.add(week)
                    }
                } else {
                    val week = cleaned.toIntOrNull() ?: return@forEach
                    if (week in 1..53 && matchesWeekType(week, type)) {
                        weeks.add(week)
                    }
                }
            }
        return weeks.toList().sorted()
    }

    private fun expandArchivedWeeks(weekRanges: JSONArray?): List<Int> {
        if (weekRanges == null) return emptyList()
        val weeks = linkedSetOf<Int>()
        for (index in 0 until weekRanges.length()) {
            val range = weekRanges.optJSONObject(index) ?: continue
            val start = range.optInt("start")
            val end = range.optInt("end")
            val type = range.optString("type", "all")
            for (week in start..end) {
                if (week in 1..53 && matchesWeekType(week, type)) {
                    weeks.add(week)
                }
            }
        }
        return weeks.toList().sorted()
    }

    private fun matchesWeekType(week: Int, type: String): Boolean {
        return when (type) {
            "odd" -> week % 2 == 1
            "even" -> week % 2 == 0
            else -> true
        }
    }

    private fun extractRows(root: JSONObject): JSONArray? {
        val datas = root.optJSONObject("datas") ?: return null
        val keys = datas.keys()
        while (keys.hasNext()) {
            val child = datas.optJSONObject(keys.next()) ?: continue
            val rows = child.optJSONArray("rows")
            if (rows != null) return rows
        }
        return null
    }

    private fun pickColor(courseName: String): Int {
        if (courseName.isBlank()) return COURSE_COLORS.first()
        var hash = 0x811C9DC5.toInt()
        courseName.forEach { ch ->
            hash = hash xor ch.code
            hash = (hash * 0x01000193).toInt()
        }
        return COURSE_COLORS[(hash.toLong() and 0xFFFFFFFFL).rem(COURSE_COLORS.size).toInt()]
    }

    private class SlotAccumulator(private val baseSlot: ParsedSlot) {
        private val activeWeeks = linkedSetOf<Int>()

        fun addActiveWeeks(weeks: List<Int>): SlotAccumulator {
            activeWeeks.addAll(weeks)
            return this
        }

        fun toSlot(): ParsedSlot {
            return baseSlot.copy(activeWeeks = activeWeeks.toList().sorted())
        }
    }
}

data class ParsedSlot(
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

data class ParsedCourse(
    val id: String,
    val code: String,
    val name: String,
    val className: String,
    val teacher: String,
    val college: String,
    val credits: Double,
    val totalHours: Int,
    val semester: String,
    val campus: String,
    val teachingType: String,
    val slots: List<ParsedSlot>,
) {
    fun toJson(): JSONObject {
        return JSONObject().apply {
            put("id", id)
            put("code", code)
            put("name", name)
            put("className", className)
            put("teacher", teacher)
            put("college", college)
            put("credits", credits)
            put("totalHours", totalHours)
            put("semester", semester)
            put("campus", campus)
            put("teachingType", teachingType)
            put(
                "slots",
                JSONArray().apply {
                    slots.forEach { slot ->
                        put(
                            JSONObject().apply {
                                put("courseId", slot.courseId)
                                put("courseName", slot.courseName)
                                put("teacher", slot.teacher)
                                put("weekday", slot.weekday)
                                put("startSection", slot.startSection)
                                put("endSection", slot.endSection)
                                put("location", slot.location)
                                put(
                                    "weekRanges",
                                    JSONArray().apply {
                                        buildWeekRanges(slot.activeWeeks).forEach { put(it) }
                                    },
                                )
                            },
                        )
                    }
                },
            )
        }
    }

    fun identity(): String = "$code|$name|$teacher|$className"

    fun signature(): String {
        val slotSignatures = slots.map { slot ->
            listOf(
                slot.weekday,
                slot.startSection,
                slot.endSection,
                slot.location,
                slot.activeWeeks.joinToString("/"),
            ).joinToString("|")
        }.sorted()
        return listOf(
            college,
            credits,
            totalHours,
            semester,
            campus,
            teachingType,
            slotSignatures.joinToString(";"),
        ).joinToString("|")
    }
}

fun buildWeekRanges(activeWeeks: List<Int>): List<JSONObject> {
    if (activeWeeks.isEmpty()) return emptyList()
    val sortedWeeks = activeWeeks.distinct().sorted()
    val ranges = mutableListOf<JSONObject>()
    var start = sortedWeeks.first()
    var previous = start
    sortedWeeks.drop(1).forEach { week ->
        if (week == previous + 1) {
            previous = week
        } else {
            ranges.add(JSONObject().put("start", start).put("end", previous).put("type", "all"))
            start = week
            previous = week
        }
    }
    ranges.add(JSONObject().put("start", start).put("end", previous).put("type", "all"))
    return ranges
}

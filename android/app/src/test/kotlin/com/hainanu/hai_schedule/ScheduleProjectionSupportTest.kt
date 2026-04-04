package com.hainanu.hai_schedule

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.util.Calendar
import java.util.TimeZone

class ScheduleProjectionSupportTest {
    @Test
    fun parsePayload_acceptsSharedFixtureContract() {
        val payload = ScheduleProjectionSupport.parsePayload(
            loadFixture("schedule_projection_payload_v2.json"),
        )

        assertNotNull(payload)
        payload!!
        assertEquals("2026-03-01T00:00:00.000Z", payload.generatedAt)
        assertEquals("2026-03-02", payload.semesterStart)
        assertEquals(20, payload.totalWeeks)
        assertEquals(6, payload.classTimes.size)
        assertEquals(2, payload.slots.size)
        assertEquals(3, payload.overrides.size)
    }

    @Test
    fun parsePayload_rejectsUnsupportedSchemaVersion() {
        val payload = ScheduleProjectionSupport.parsePayload(
            """
            {
              "schemaVersion": 99,
              "semesterStart": "2026-03-02",
              "totalWeeks": 20,
              "classTimes": [],
              "slots": [],
              "overrides": []
            }
            """.trimIndent(),
        )

        assertNull(payload)
    }

    @Test
    fun resolveDaySlots_appliesOverridesForResolvedDaySlots() {
        val payload = projectionPayload(
            slots = listOf(
                ScheduleProjectionSupport.ProjectionSlot(
                    courseId = "math",
                    courseName = "Linear Algebra",
                    teacher = "Prof A",
                    location = "A101",
                    weekday = 1,
                    startSection = 1,
                    endSection = 2,
                    activeWeeks = listOf(1, 2, 3),
                    color = 11,
                ),
                ScheduleProjectionSupport.ProjectionSlot(
                    courseId = "chem",
                    courseName = "Chemistry",
                    teacher = "Prof B",
                    location = "B201",
                    weekday = 1,
                    startSection = 3,
                    endSection = 4,
                    activeWeeks = listOf(1, 2, 3),
                    color = 22,
                ),
            ),
            overrides = listOf(
                ScheduleProjectionSupport.ProjectionOverride(
                    id = "modify-math",
                    semesterCode = "2026-1",
                    dateKey = "2026-03-02",
                    weekday = 1,
                    startSection = 2,
                    endSection = 3,
                    type = "modify",
                    targetCourseId = "math",
                    courseName = "Advanced Algebra",
                    teacher = "",
                    location = "A301",
                    status = "normal",
                    sourceStartSection = 1,
                    sourceEndSection = 2,
                    color = 33,
                ),
                ScheduleProjectionSupport.ProjectionOverride(
                    id = "cancel-chem",
                    semesterCode = "2026-1",
                    dateKey = "2026-03-02",
                    weekday = 1,
                    startSection = 3,
                    endSection = 4,
                    type = "cancel",
                    targetCourseId = "chem",
                    courseName = "",
                    teacher = "",
                    location = "",
                    status = "normal",
                    sourceStartSection = null,
                    sourceEndSection = null,
                    color = 0,
                ),
                ScheduleProjectionSupport.ProjectionOverride(
                    id = "add-temp",
                    semesterCode = "2026-1",
                    dateKey = "2026-03-02",
                    weekday = 1,
                    startSection = 4,
                    endSection = 4,
                    type = "add",
                    targetCourseId = "",
                    courseName = "Temporary",
                    teacher = "Prof C",
                    location = "Lab 1",
                    status = "normal",
                    sourceStartSection = null,
                    sourceEndSection = null,
                    color = 44,
                ),
            ),
        )

        val target = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
            set(2026, Calendar.MARCH, 2, 12, 0, 0)
            set(Calendar.MILLISECOND, 0)
        }

        val resolved = payload.resolveDaySlots(target)
        assertEquals(2, resolved.size)
        assertEquals("Advanced Algebra", resolved[0].courseName)
        assertEquals(2, resolved[0].startSection)
        assertEquals(3, resolved[0].endSection)
        assertEquals(33, resolved[0].color)
        assertEquals("Temporary", resolved[1].courseName)
        assertEquals(4, resolved[1].startSection)
        assertEquals(4, resolved[1].endSection)
    }

    @Test
    fun buildOccurrences_skipsPastEntriesAndSortsFutureOnes() {
        val payload = projectionPayload(
            slots = listOf(
                ScheduleProjectionSupport.ProjectionSlot(
                    courseId = "past",
                    courseName = "Morning",
                    teacher = "Prof A",
                    location = "A101",
                    weekday = 1,
                    startSection = 1,
                    endSection = 2,
                    activeWeeks = listOf(1),
                    color = 11,
                ),
                ScheduleProjectionSupport.ProjectionSlot(
                    courseId = "future",
                    courseName = "Afternoon",
                    teacher = "Prof B",
                    location = "B201",
                    weekday = 1,
                    startSection = 5,
                    endSection = 6,
                    activeWeeks = listOf(1),
                    color = 22,
                ),
            ),
        )

        val now = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
            set(2026, Calendar.MARCH, 2, 13, 0, 0)
            set(Calendar.MILLISECOND, 0)
        }

        val occurrences = payload.buildOccurrences(now, 1)
        assertEquals(1, occurrences.size)
        assertEquals("Afternoon", occurrences[0].courseName)
        assertTrue(occurrences[0].startAtMillis > now.timeInMillis)
    }

    private fun projectionPayload(
        slots: List<ScheduleProjectionSupport.ProjectionSlot>,
        overrides: List<ScheduleProjectionSupport.ProjectionOverride> = emptyList(),
    ): ScheduleProjectionSupport.ProjectionPayload {
        return ScheduleProjectionSupport.ProjectionPayload(
            semesterStart = "2026-03-02",
            totalWeeks = 20,
            classTimes = listOf(
                ScheduleProjectionSupport.ProjectionClassTime(
                    section = 1,
                    startTime = "08:00",
                    endTime = "08:45",
                ),
                ScheduleProjectionSupport.ProjectionClassTime(
                    section = 2,
                    startTime = "08:55",
                    endTime = "09:40",
                ),
                ScheduleProjectionSupport.ProjectionClassTime(
                    section = 3,
                    startTime = "10:10",
                    endTime = "10:55",
                ),
                ScheduleProjectionSupport.ProjectionClassTime(
                    section = 4,
                    startTime = "11:05",
                    endTime = "11:50",
                ),
                ScheduleProjectionSupport.ProjectionClassTime(
                    section = 5,
                    startTime = "14:00",
                    endTime = "14:45",
                ),
                ScheduleProjectionSupport.ProjectionClassTime(
                    section = 6,
                    startTime = "14:55",
                    endTime = "15:40",
                ),
            ),
            slots = slots,
            overrides = overrides,
        )
    }

    private fun loadFixture(name: String): String {
        val candidates = listOf(
            File("test/fixtures/$name"),
            File("../test/fixtures/$name"),
            File("../../test/fixtures/$name"),
        )

        return candidates.firstOrNull { it.exists() }?.readText(Charsets.UTF_8)
            ?: error(
                "Fixture not found: $name (searched from ${System.getProperty("user.dir")})",
            )
    }
}

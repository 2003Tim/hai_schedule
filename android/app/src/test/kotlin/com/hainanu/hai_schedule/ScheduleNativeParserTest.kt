package com.hainanu.hai_schedule

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ScheduleNativeParserTest {
    @Test
    fun parseCourses_supportsDartAlignedScheduleSyntax() {
        val courses = ScheduleNativeParser.parseCourses(
            JSONObject(
                """
                {
                  "code": "0",
                  "datas": {
                    "cxkb": {
                      "rows": [
                        {
                          "WID": "course-1",
                          "KCDM": "MATH001",
                          "KCMC": "高等数学",
                          "BJMC": "数学一班",
                          "RKJS": "张老师",
                          "KKDW_DISPLAY": "理学院",
                          "XF": 4.0,
                          "ZXS": 64,
                          "XNXQDM_DISPLAY": "2025-2026学年 第一学期",
                          "XQDM_DISPLAY": "海甸校区",
                          "SKFSDM_DISPLAY": "讲授",
                          "PKSJDD": "第3-4，6-7教学周 星期一[1-2节](海甸)2-106；8-11周 星期一[1-2节](海甸)2-106;3-15周(单) 星期三[3节](海甸)4-201"
                        }
                      ]
                    }
                  }
                }
                """.trimIndent(),
            ),
        )

        assertEquals(1, courses.size)
        val course = courses.single()
        assertEquals("course-1", course.id)
        assertEquals("高等数学", course.name)
        assertEquals("张老师", course.teacher)
        assertEquals(2, course.slots.size)

        val monday = course.slots.first { it.weekday == 1 }
        assertEquals(1, monday.startSection)
        assertEquals(2, monday.endSection)
        assertEquals("(海甸)2-106", monday.location)
        assertEquals(listOf(3, 4, 6, 7, 8, 9, 10, 11), monday.activeWeeks)

        val wednesday = course.slots.first { it.weekday == 3 }
        assertEquals(3, wednesday.startSection)
        assertEquals(3, wednesday.endSection)
        assertEquals(listOf(3, 5, 7, 9, 11, 13, 15), wednesday.activeWeeks)
    }

    @Test
    fun parseCourses_discardsInvalidWeekAndSectionBounds() {
        val courses = ScheduleNativeParser.parseCourses(
            JSONObject(
                """
                {
                  "datas": {
                    "cxkb": {
                      "rows": [
                        {
                          "WID": "course-2",
                          "KCMC": "异常课程",
                          "PKSJDD": "0-2周 星期一[1-2节]教室;1-54周 星期二[1-2节]教室;1-2周 星期三[5-4节]教室;1-2周 星期四[21节]教室"
                        }
                      ]
                    }
                  }
                }
                """.trimIndent(),
            ),
        )

        assertEquals(1, courses.size)
        assertTrue(courses.single().slots.isEmpty())
    }

    @Test
    fun parsedCourse_toJsonKeepsArchiveShape() {
        val courses = ScheduleNativeParser.parseCourses(
            JSONObject(
                """
                {
                  "datas": {
                    "cxkb": {
                      "rows": [
                        {
                          "WID": "course-3",
                          "KCDM": "PHY001",
                          "KCMC": "大学物理",
                          "BJMC": "物理一班",
                          "RKJS": "王老师",
                          "KKDW_DISPLAY": "理学院",
                          "XF": 3.0,
                          "ZXS": 48,
                          "XNXQDM_DISPLAY": "2025-2026学年 第一学期",
                          "XQDM_DISPLAY": "海甸校区",
                          "SKFSDM_DISPLAY": "讲授",
                          "PKSJDD": "1-2周 星期二[3-4节]教二-201"
                        }
                      ]
                    }
                  }
                }
                """.trimIndent(),
            ),
        )

        val json = courses.single().toJson()
        assertEquals("course-3", json.getString("id"))
        assertEquals("PHY001", json.getString("code"))
        assertEquals("大学物理", json.getString("name"))
        val slot = json.getJSONArray("slots").getJSONObject(0)
        assertEquals("course-3", slot.getString("courseId"))
        assertEquals("大学物理", slot.getString("courseName"))
        assertEquals(2, slot.getInt("weekday"))
        assertEquals(3, slot.getInt("startSection"))
        assertEquals(4, slot.getInt("endSection"))
        assertEquals("教二-201", slot.getString("location"))
        val weekRange = slot.getJSONArray("weekRanges").getJSONObject(0)
        assertEquals(1, weekRange.getInt("start"))
        assertEquals(2, weekRange.getInt("end"))
        assertEquals("all", weekRange.getString("type"))
    }
}

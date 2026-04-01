package com.hainanu.hai_schedule

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.util.Log
import android.webkit.CookieManager
import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.regex.Pattern
import kotlin.concurrent.thread

class AutoSyncScheduler : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "收到广播: ${intent.action}")
        when (intent.action) {
            ACTION_RUN -> {
                val pendingResult = goAsync()
                thread(name = "hai-schedule-auto-sync") {
                    var syncSucceeded = false
                    try {
                        syncSucceeded = performSync(context)
                    } catch (t: Throwable) {
                        Log.e(TAG, "后台自动同步异常", t)
                        writeState(
                            context,
                            state = "failed",
                            message = "后台自动同步异常: ${t.message ?: "未知错误"}",
                            error = t.stackTraceToString(),
                        )
                    } finally {
                        schedule(context, afterSuccessfulSync = syncSucceeded)
                        pendingResult.finish()
                    }
                }
            }
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                schedule(context, afterSuccessfulSync = false)
            }
        }
    }

    companion object {
        private const val TAG = "HaiAutoSync"
        private const val ACTION_RUN = "com.hainanu.hai_schedule.AUTO_SYNC_RUN"
        private const val REQUEST_CODE = 9310

        private const val BASE_URL = "https://ehall.hainanu.edu.cn"
        private const val INDEX_URL = "https://ehall.hainanu.edu.cn/gsapp/sys/wdkbapp/*default/index.do"
        private const val API_URL = "https://ehall.hainanu.edu.cn/gsapp/sys/wdkbapp/modules/xskcb/xsjxrwcx.do"
        private const val AUTH_BASE_URL = "https://authserver.hainanu.edu.cn"
        private const val WEBVIEW_USER_AGENT = "Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36"

        private const val PREFS_FLUTTER = "FlutterSharedPreferences"
        private const val PREFS_HOME_WIDGET = "HomeWidgetPreferences"

        private const val KEY_FREQUENCY = "auto_sync_frequency"
        private const val KEY_CUSTOM_INTERVAL_MINUTES = "auto_sync_custom_interval_minutes"
        private const val KEY_LAST_FETCH = "last_fetch_time"
        private const val KEY_LAST_ATTEMPT = "last_auto_sync_attempt_time"
        private const val KEY_LAST_STATE = "last_auto_sync_state"
        private const val KEY_LAST_MESSAGE = "last_auto_sync_message"
        private const val KEY_LAST_ERROR = "last_auto_sync_error"
        private const val KEY_LAST_SOURCE = "last_auto_sync_source"
        private const val KEY_LAST_SCHEDULE_JSON = "last_schedule_json"
        private const val KEY_LAST_SEMESTER = "last_semester_code"
        private const val KEY_LEGACY_SEMESTER = "current_semester"
        private const val KEY_ACTIVE_SEMESTER = "active_semester_code"
        private const val KEY_NEXT_SYNC = "next_background_sync_time"
        private const val KEY_COOKIE_SNAPSHOT = "last_auto_sync_cookie"
        private const val KEY_SCHEDULE_ARCHIVE = "schedule_archive_by_semester"
        private const val KEY_SCHEDULE_OVERRIDES = "schedule_overrides"
        private const val KEY_SCHOOL_TIME_CONFIG = "school_time_config"

        private const val HOME_WIDGET_PAYLOAD_KEY = "hai_schedule_widget_payload"

        private const val DEFAULT_TOTAL_WEEKS = 20
        private const val PAGE_SIZE = 100
        private const val MAX_PAGES = 20
        private const val DEFAULT_CUSTOM_INTERVAL_MINUTES = 12 * 60
        private const val MIN_CUSTOM_INTERVAL_MINUTES = 60
        private const val MAX_CUSTOM_INTERVAL_MINUTES = 30 * 24 * 60

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

        private val WEEK_REGEX = Pattern.compile("^(.+?周)\\s*")
        private val DAY_REGEX = Pattern.compile("星期([一二三四五六日天])")
        private val SECTION_REGEX = Pattern.compile("\\[(\\d+)-(\\d+)节\\]")

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

        fun configure(
            context: Context,
            enabled: Boolean,
            frequency: String,
            customIntervalMinutes: Int?,
            afterSuccessfulSync: Boolean,
            preserveExistingCustomSchedule: Boolean,
        ): String? {
            val prefs = flutterPrefs(context)
            prefs.edit().putString(flutterKey(KEY_FREQUENCY), frequency).apply()
            if (customIntervalMinutes != null) {
                prefs.edit()
                    .putInt(flutterKey(KEY_CUSTOM_INTERVAL_MINUTES), customIntervalMinutes)
                    .apply()
            } else if (frequency != "custom") {
                prefs.edit().remove(flutterKey(KEY_CUSTOM_INTERVAL_MINUTES)).apply()
            }

            if (!enabled || frequency == "manual") {
                cancel(context)
                prefs.edit().remove(flutterKey(KEY_NEXT_SYNC)).apply()
                return null
            }

            return schedule(
                context = context,
                frequency = frequency,
                customIntervalMinutes = customIntervalMinutes,
                afterSuccessfulSync = afterSuccessfulSync,
                preserveExistingCustomSchedule = preserveExistingCustomSchedule,
            )
        }

        fun schedule(
            context: Context,
            frequency: String? = null,
            customIntervalMinutes: Int? = null,
            afterSuccessfulSync: Boolean,
            preserveExistingCustomSchedule: Boolean = true,
        ): String? {
            val prefs = flutterPrefs(context)
            val resolvedFrequency = frequency
                ?: prefs.getString(flutterKey(KEY_FREQUENCY), "daily")
                ?: "daily"
            val resolvedCustomIntervalMinutes = customIntervalMinutes
                ?: prefs.getInt(
                    flutterKey(KEY_CUSTOM_INTERVAL_MINUTES),
                    DEFAULT_CUSTOM_INTERVAL_MINUTES,
                )

            if (resolvedFrequency == "manual") {
                cancel(context)
                prefs.edit().remove(flutterKey(KEY_NEXT_SYNC)).apply()
                return null
            }

            val triggerAt = computeNextTriggerMillis(
                prefs = prefs,
                frequency = resolvedFrequency,
                customIntervalMinutes = resolvedCustomIntervalMinutes,
                afterSuccessfulSync = afterSuccessfulSync,
                preserveExistingCustomSchedule = preserveExistingCustomSchedule,
            )
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pendingIntent = createPendingIntent(context)
            alarmManager.cancel(pendingIntent)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAt,
                    pendingIntent,
                )
            } else {
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    triggerAt,
                    pendingIntent,
                )
            }

            val nextIso = toIsoString(triggerAt)
            prefs.edit().putString(flutterKey(KEY_NEXT_SYNC), nextIso).apply()
            Log.d(TAG, "后台同步已调度: $resolvedFrequency at $nextIso")
            return nextIso
        }

        fun cancel(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.cancel(createPendingIntent(context))
        }

        private fun performSync(context: Context): Boolean {
            Log.d(TAG, "开始执行后台同步")
            val prefs = flutterPrefs(context)
            val semester = prefs.getString(flutterKey(KEY_ACTIVE_SEMESTER), null)
                ?: prefs.getString(flutterKey(KEY_LAST_SEMESTER), null)
                ?: prefs.getString(flutterKey(KEY_LEGACY_SEMESTER), null)
            Log.d(TAG, "当前目标学期: ${semester ?: "<empty>"}")

            prefs.edit()
                .putString(flutterKey(KEY_LAST_ATTEMPT), toIsoString(System.currentTimeMillis()))
                .putString(flutterKey(KEY_LAST_STATE), "syncing")
                .putString(flutterKey(KEY_LAST_SOURCE), "background")
                .putString(flutterKey(KEY_LAST_MESSAGE), "后台正在同步课表...")
                .apply()

            if (semester.isNullOrBlank()) {
                Log.d(TAG, "后台同步终止: 缺少学期信息")
                writeState(
                    context,
                    state = "login_required",
                    message = "缺少学期信息，请先手动登录抓取一次",
                    error = null,
                )
                return false
            }

            val cookie = try {
                val liveCookie = readMergedLiveCookie()
                if (!liveCookie.isNullOrBlank()) {
                    prefs.edit().putString(flutterKey(KEY_COOKIE_SNAPSHOT), liveCookie).apply()
                    liveCookie
                } else {
                    prefs.getString(flutterKey(KEY_COOKIE_SNAPSHOT), null)
                }
            } catch (t: Throwable) {
                prefs.getString(flutterKey(KEY_COOKIE_SNAPSHOT), null)
            }

            if (cookie.isNullOrBlank()) {
                Log.d(TAG, "未读取到有效 cookie，尝试后台续登")
                val reloginCookie = tryBackgroundRelogin(context)
                if (!reloginCookie.isNullOrBlank()) {
                    Log.d(TAG, "后台续登成功，准备重试同步")
                    prefs.edit().putString(flutterKey(KEY_COOKIE_SNAPSHOT), reloginCookie).apply()
                    return performSync(context)
                }
                Log.d(TAG, "后台续登失败，无法继续同步")
                writeState(
                    context,
                    state = "login_required",
                    message = "后台未读取到有效登录态，请先登录并刷新课表一次",
                    error = null,
                )
                return false
            }

            val json = fetchSchedulePayload(cookie, semester)
            val responseText = json.toString()
            val code = json.optString("code")
            Log.d(TAG, "课表接口返回 code=$code")
            if (code != "0") {
                Log.d(TAG, "现有登录态无效，尝试后台续登后重试")
                val reloginCookie = tryBackgroundRelogin(context)
                if (!reloginCookie.isNullOrBlank()) {
                    Log.d(TAG, "后台续登成功，正在重试课表接口")
                    prefs.edit().putString(flutterKey(KEY_COOKIE_SNAPSHOT), reloginCookie).apply()
                    val retryJson = fetchSchedulePayload(reloginCookie, semester)
                    val retryText = retryJson.toString()
                    Log.d(TAG, "重试课表接口返回 code=${retryJson.optString("code")}")
                    if (retryJson.optString("code") == "0") {
                        val retryCourseCount = extractRows(retryJson)?.length() ?: 0
                        Log.d(TAG, "后台续登后同步成功，课程数=$retryCourseCount")
                        prefs.edit()
                            .putString(flutterKey(KEY_LAST_SCHEDULE_JSON), retryText)
                            .putString(flutterKey(KEY_LAST_FETCH), toIsoString(System.currentTimeMillis()))
                            .putString(flutterKey(KEY_LAST_STATE), "success")
                            .putString(flutterKey(KEY_LAST_SOURCE), "background")
                            .putString(flutterKey(KEY_LAST_MESSAGE), "后台续登后已同步 $retryCourseCount 门课程")
                            .remove(flutterKey(KEY_LAST_ERROR))
                            .apply()
                        persistScheduleArchive(context, semester, retryText)
                        saveWidgetPayload(context, retryJson, semester)
                        TodayScheduleWidgetProvider.refreshAll(context)
                        return true
                    }
                }
                Log.d(TAG, "后台同步失败: 登录态仍无效")
                writeState(
                    context,
                    state = "login_required",
                    message = "登录态可能已失效，请重新登录后再自动同步",
                    error = "code=$code",
                )
                return false
            }

            val courseCount = extractRows(json)?.length() ?: 0
            Log.d(TAG, "后台同步成功，课程数=$courseCount")
            prefs.edit()
                .putString(flutterKey(KEY_LAST_SCHEDULE_JSON), responseText)
                .putString(flutterKey(KEY_LAST_FETCH), toIsoString(System.currentTimeMillis()))
                .putString(flutterKey(KEY_LAST_STATE), "success")
                .putString(flutterKey(KEY_LAST_SOURCE), "background")
                .putString(flutterKey(KEY_LAST_MESSAGE), "后台已同步 $courseCount 门课程")
                .remove(flutterKey(KEY_LAST_ERROR))
                .apply()

            persistScheduleArchive(context, semester, responseText)
            saveWidgetPayload(context, json, semester)
            TodayScheduleWidgetProvider.refreshAll(context)
            return true
        }

        private fun writeState(
            context: Context,
            state: String,
            message: String,
            error: String?,
        ) {
            val editor = flutterPrefs(context).edit()
                .putString(flutterKey(KEY_LAST_STATE), state)
                .putString(flutterKey(KEY_LAST_SOURCE), "background")
                .putString(flutterKey(KEY_LAST_MESSAGE), message)

            if (error.isNullOrBlank()) {
                editor.remove(flutterKey(KEY_LAST_ERROR))
            } else {
                editor.putString(flutterKey(KEY_LAST_ERROR), error)
            }
            editor.apply()
        }

        private fun readMergedLiveCookie(): String? {
            val manager = CookieManager.getInstance()
            manager.setAcceptCookie(true)
            manager.flush()

            val merged = mergeCookieStrings(
                listOfNotNull(
                    manager.getCookie(API_URL),
                    manager.getCookie(INDEX_URL),
                    manager.getCookie(BASE_URL),
                ),
            )
            return merged.ifBlank { null }
        }

        private fun tryBackgroundRelogin(context: Context): String? {
            val credential = NativeCredentialStore.load(context) ?: return null
            return try {
                Log.d(TAG, "读取到已保存凭据，开始后台续登")
                val cookieJar = linkedMapOf<String, String>()
                val loginPage = openRequest(
                    url = INDEX_URL,
                    cookieJar = cookieJar,
                    followRedirects = true,
                )
                Log.d(TAG, "后台续登已获取登录页: ${loginPage.url}")
                val form = parseLoginForm(loginPage.url, loginPage.body) ?: return null
                Log.d(TAG, "后台续登已解析登录表单: ${form.actionUrl}")

                val fields = LinkedHashMap(form.hiddenFields)
                fields["username"] = credential.first
                fields["password"] = credential.second
                fields["passwordText"] = credential.second
                fields["rememberMe"] = "true"
                if (!fields.containsKey("_eventId")) {
                    fields["_eventId"] = "submit"
                }
                if (!fields.containsKey("cllt")) {
                    fields["cllt"] = "userNameLogin"
                }
                if (!fields.containsKey("dllt")) {
                    fields["dllt"] = "generalLogin"
                }
                if (!fields.containsKey("lt")) {
                    fields["lt"] = ""
                }

                openRequest(
                    url = form.actionUrl,
                    method = "POST",
                    body = fields.entries.joinToString("&") { (key, value) ->
                        "${urlEncode(key)}=${urlEncode(value)}"
                    },
                    referer = loginPage.url,
                    cookieJar = cookieJar,
                    followRedirects = true,
                )

                val verifyPage = openRequest(
                    url = INDEX_URL,
                    referer = form.actionUrl,
                    cookieJar = cookieJar,
                    followRedirects = true,
                )
                val verifyUrl = verifyPage.url.lowercase(Locale.ROOT)
                val loginStillRequired =
                    verifyUrl.contains("authserver") ||
                        verifyUrl.contains("login") ||
                        isMultiFactorChallenge(verifyPage.body)
                Log.d(TAG, "后台续登校验页: ${verifyPage.url}")
                if (loginStillRequired) {
                    Log.d(TAG, "后台续登校验失败，仍停留在登录页")
                    return null
                }

                val mergedCookie = mergeCookieStrings(
                    listOf(
                        cookieJar.entries.joinToString("; ") { (key, value) -> "$key=$value" },
                    ),
                ).ifBlank { null }
                Log.d(TAG, "后台续登结束，cookie可用=${!mergedCookie.isNullOrBlank()}")
                mergedCookie
            } catch (t: Throwable) {
                Log.e(TAG, "后台续登失败", t)
                null
            }
        }

        private data class LoginPage(
            val url: String,
            val body: String,
        )

        private data class LoginForm(
            val actionUrl: String,
            val hiddenFields: Map<String, String>,
        )

        private fun parseLoginForm(pageUrl: String, html: String): LoginForm? {
            val formRegex = Pattern.compile(
                "<form[^>]*action=[\"']([^\"']+)[\"'][^>]*>([\\s\\S]*?)</form>",
                Pattern.CASE_INSENSITIVE,
            )
            val matcher = formRegex.matcher(html)
            while (matcher.find()) {
                val action = matcher.group(1) ?: continue
                val formHtml = matcher.group(2) ?: continue
                val lower = formHtml.lowercase(Locale.ROOT)
                if (!lower.contains("username") && !lower.contains("password")) {
                    continue
                }

                val hiddenFields = linkedMapOf<String, String>()
                val inputRegex = Pattern.compile("<input[^>]*>", Pattern.CASE_INSENSITIVE)
                val inputMatcher = inputRegex.matcher(formHtml)
                while (inputMatcher.find()) {
                    val tag = inputMatcher.group() ?: continue
                    val name = findAttr(tag, "name") ?: continue
                    val type = findAttr(tag, "type")?.lowercase(Locale.ROOT) ?: ""
                    if (type == "hidden") {
                        hiddenFields[name] = findAttr(tag, "value") ?: ""
                    }
                }

                return LoginForm(
                    actionUrl = resolveUrl(pageUrl, action),
                    hiddenFields = hiddenFields,
                )
            }
            return null
        }

        private fun isMultiFactorChallenge(html: String): Boolean {
            val lower = html.lowercase(Locale.ROOT)
            return lower.contains("多因子认证") ||
                lower.contains("right-header-title") ||
                lower.contains("id=\"dynamiccode\"") ||
                lower.contains("name=\"dynamiccode\"") ||
                lower.contains("id=\"getdynamiccode\"") ||
                lower.contains("id=\"reauthsubmitbtn\"")
        }

        private fun findAttr(tag: String, name: String): String? {
            val regex = Pattern.compile("$name\\s*=\\s*[\"']([^\"']*)[\"']", Pattern.CASE_INSENSITIVE)
            val matcher = regex.matcher(tag)
            return if (matcher.find()) matcher.group(1) else null
        }

        private fun resolveUrl(baseUrl: String, action: String): String {
            return URL(URL(baseUrl), action).toString()
        }

        private fun urlEncode(value: String): String {
            return java.net.URLEncoder.encode(value, "UTF-8")
        }

        private fun openRequest(
            url: String,
            method: String = "GET",
            body: String? = null,
            referer: String? = null,
            cookieJar: LinkedHashMap<String, String>,
            followRedirects: Boolean,
        ): LoginPage {
            var currentUrl = url
            var currentMethod = method
            var currentBody = body
            var currentReferer = referer
            repeat(8) {
                val connection = (URL(currentUrl).openConnection() as HttpURLConnection).apply {
                    instanceFollowRedirects = false
                    requestMethod = currentMethod
                    connectTimeout = 15000
                    readTimeout = 15000
                    doInput = true
                    doOutput = currentMethod == "POST"
                    setRequestProperty("User-Agent", WEBVIEW_USER_AGENT)
                    setRequestProperty("Accept-Language", "zh-CN,zh;q=0.9")
                    setRequestProperty("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
                    if (!currentReferer.isNullOrBlank()) {
                        setRequestProperty("Referer", currentReferer)
                    }
                    val cookieHeader = cookieJar.entries.joinToString("; ") { (key, value) -> "$key=$value" }
                    if (cookieHeader.isNotBlank()) {
                        setRequestProperty("Cookie", cookieHeader)
                    }
                    if (currentMethod == "POST") {
                        setRequestProperty("Content-Type", "application/x-www-form-urlencoded; charset=UTF-8")
                    }
                }

                if (currentMethod == "POST" && currentBody != null) {
                    OutputStreamWriter(connection.outputStream, Charsets.UTF_8).use { writer ->
                        writer.write(currentBody)
                        writer.flush()
                    }
                }

                connection.headerFields["Set-Cookie"]?.forEach { raw ->
                    val firstPart = raw.substringBefore(';').trim()
                    val index = firstPart.indexOf('=')
                    if (index > 0) {
                        val key = firstPart.substring(0, index).trim()
                        val value = firstPart.substring(index + 1).trim()
                        if (key.isNotEmpty() && value.isNotEmpty()) {
                            cookieJar[key] = value
                        }
                    }
                }

                val code = connection.responseCode
                if (followRedirects && code in 300..399) {
                    val location = connection.getHeaderField("Location")
                    connection.disconnect()
                    if (!location.isNullOrBlank()) {
                        currentReferer = currentUrl
                        currentUrl = resolveUrl(currentUrl, location)
                        currentMethod = "GET"
                        currentBody = null
                        return@repeat
                    }
                }

                val stream = if (code in 200..399) connection.inputStream else connection.errorStream
                val text = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() } ?: ""
                connection.disconnect()
                return LoginPage(currentUrl, text)
            }
            throw IllegalStateException("登录重定向次数过多")
        }

        private fun mergeCookieStrings(cookies: List<String>): String {
            val pairs = linkedMapOf<String, String>()
            cookies.forEach { raw ->
                raw.split(';').forEach { part ->
                    val segment = part.trim()
                    if (segment.isEmpty()) return@forEach
                    val index = segment.indexOf('=')
                    if (index <= 0) return@forEach
                    val key = segment.substring(0, index).trim()
                    val value = segment.substring(index + 1).trim()
                    if (key.isEmpty() || value.isEmpty()) return@forEach
                    pairs[key] = value
                }
            }
            return pairs.entries.joinToString("; ") { (key, value) -> "$key=$value" }
        }

        private fun fetchSchedulePayload(cookie: String, semester: String): JSONObject {
            var mergedRoot: JSONObject? = null
            for (pageNumber in 1..MAX_PAGES) {
                val responseText = postScheduleRequest(
                    cookie = cookie,
                    semester = semester,
                    pageNumber = pageNumber,
                    pageSize = PAGE_SIZE,
                )
                val pageJson = JSONObject(responseText)
                val code = pageJson.optString("code")
                if (code != "0") {
                    if (pageNumber == 1) {
                        return pageJson
                    }
                    throw IllegalStateException("page=$pageNumber code=$code")
                }

                if (mergedRoot == null) {
                    mergedRoot = JSONObject(pageJson.toString())
                } else {
                    appendRows(mergedRoot!!, extractRows(pageJson) ?: JSONArray())
                }

                val pageRows = extractRows(pageJson) ?: JSONArray()
                if (pageNumber == MAX_PAGES && pageRows.length() >= PAGE_SIZE) {
                    throw IllegalStateException("page overflow")
                }
                if (pageRows.length() < PAGE_SIZE) {
                    break
                }
            }

            return mergedRoot ?: JSONObject().apply { put("code", "0") }
        }

        private fun postScheduleRequest(
            cookie: String,
            semester: String,
            pageNumber: Int,
            pageSize: Int,
        ): String {
            val requestUrl = "$API_URL?_=${System.currentTimeMillis()}"
            val connection = (URL(requestUrl).openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = 15000
                readTimeout = 15000
                doInput = true
                doOutput = true
                setRequestProperty("Content-Type", "application/x-www-form-urlencoded; charset=UTF-8")
                setRequestProperty("X-Requested-With", "XMLHttpRequest")
                setRequestProperty("Accept", "application/json, text/javascript, */*; q=0.01")
                setRequestProperty("Origin", BASE_URL)
                setRequestProperty("Referer", INDEX_URL)
                setRequestProperty("User-Agent", WEBVIEW_USER_AGENT)
                setRequestProperty("Accept-Language", "zh-CN,zh;q=0.9")
                setRequestProperty("Cookie", cookie)
            }

            val body = buildString {
                append("XNXQDM=")
                append(urlEncode(semester))
                append("&XH=")
                append(urlEncode(""))
                append("&pageNumber=")
                append(pageNumber)
                append("&pageSize=")
                append(pageSize)
            }
            OutputStreamWriter(connection.outputStream, Charsets.UTF_8).use { writer ->
                writer.write(body)
                writer.flush()
            }

            val code = connection.responseCode
            val stream = if (code in 200..299) connection.inputStream else connection.errorStream
            val text = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() } ?: ""
            connection.disconnect()

            if (code != 200) {
                throw IllegalStateException("HTTP $code: $text")
            }

            return text
        }

        private fun persistScheduleArchive(
            context: Context,
            semester: String,
            rawScheduleJson: String,
        ) {
            val prefs = flutterPrefs(context)
            val archiveRaw = prefs.getString(flutterKey(KEY_SCHEDULE_ARCHIVE), null)
            val archive = try {
                if (archiveRaw.isNullOrBlank()) JSONObject() else JSONObject(archiveRaw)
            } catch (_: Throwable) {
                JSONObject()
            }

            val entry = archive.optJSONObject(semester) ?: JSONObject()
            entry.put("rawScheduleJson", rawScheduleJson)
            archive.put(semester, entry)

            prefs.edit()
                .putString(flutterKey(KEY_SCHEDULE_ARCHIVE), archive.toString())
                .putString(flutterKey(KEY_ACTIVE_SEMESTER), semester)
                .putString(flutterKey(KEY_LAST_SEMESTER), semester)
                .putString(flutterKey(KEY_LEGACY_SEMESTER), semester)
                .putString(flutterKey(KEY_LAST_SCHEDULE_JSON), rawScheduleJson)
                .apply()
        }

        private fun saveWidgetPayload(context: Context, root: JSONObject, semester: String) {
            val payload = JSONObject().apply {
                put("schemaVersion", 1)
                put("generatedAt", toIsoString(System.currentTimeMillis()))
                put("semesterStart", semesterStartForCode(semester))
                put("totalWeeks", DEFAULT_TOTAL_WEEKS)
                put("classTimes", loadClassTimes(context))
                put("slots", buildSlots(root))
                put("overrides", loadOverrides(context, semester))
            }

            val widgetPrefs = context.getSharedPreferences(PREFS_HOME_WIDGET, Context.MODE_PRIVATE)
            widgetPrefs.edit().putString(HOME_WIDGET_PAYLOAD_KEY, payload.toString()).apply()
        }

        private fun loadClassTimes(context: Context): JSONArray {
            val raw = flutterPrefs(context).getString(flutterKey(KEY_SCHOOL_TIME_CONFIG), null)
            if (!raw.isNullOrBlank()) {
                try {
                    val root = JSONObject(raw)
                    val classTimes = root.optJSONArray("classTimes")
                    if (classTimes != null && classTimes.length() > 0) {
                        return classTimes
                    }
                } catch (_: Throwable) {
                }
            }
            return buildClassTimes()
        }

        private fun buildClassTimes(): JSONArray {
            val list = listOf(
                Triple(1, "07:40", "08:25"),
                Triple(2, "08:35", "09:20"),
                Triple(3, "09:45", "10:30"),
                Triple(4, "10:40", "11:25"),
                Triple(5, "14:30", "15:15"),
                Triple(6, "15:25", "16:10"),
                Triple(7, "16:35", "17:20"),
                Triple(8, "17:30", "18:15"),
                Triple(9, "19:20", "20:05"),
                Triple(10, "20:15", "21:00"),
                Triple(11, "21:10", "21:55"),
            )
            val array = JSONArray()
            list.forEach { (section, start, end) ->
                array.put(JSONObject().apply {
                    put("section", section)
                    put("startTime", start)
                    put("endTime", end)
                })
            }
            return array
        }

        private fun buildSlots(root: JSONObject): JSONArray {
            val rows = extractRows(root) ?: JSONArray()
            val array = JSONArray()
            for (i in 0 until rows.length()) {
                val row = rows.optJSONObject(i) ?: continue
                val courseId = row.optString("WID")
                val courseName = row.optString("KCMC")
                val teacher = row.optString("RKJS")
                val pksjdd = row.optString("PKSJDD")
                parseScheduleSlots(courseId, courseName, teacher, pksjdd).forEach { slot ->
                    array.put(JSONObject().apply {
                        put("courseId", slot.courseId)
                        put("courseName", slot.courseName)
                        put("teacher", slot.teacher)
                        put("location", slot.location)
                        put("weekday", slot.weekday)
                        put("startSection", slot.startSection)
                        put("endSection", slot.endSection)
                        put("activeWeeks", JSONArray(slot.activeWeeks))
                        put("color", slot.color)
                    })
                }
            }
            return array
        }

        private fun loadOverrides(context: Context, semester: String): JSONArray {
            val raw = flutterPrefs(context).getString(flutterKey(KEY_SCHEDULE_OVERRIDES), null)
            if (raw.isNullOrBlank()) return JSONArray()

            val source = try {
                JSONArray(raw)
            } catch (_: Throwable) {
                return JSONArray()
            }

            val filtered = JSONArray()
            for (i in 0 until source.length()) {
                val item = source.optJSONObject(i) ?: continue
                if (item.optString("semesterCode") != semester) continue
                filtered.put(JSONObject(item.toString()).apply {
                    if (!has("status")) {
                        put("status", "normal")
                    }
                    if (!has("color")) {
                        put("color", pickColor(optString("courseName")))
                    }
                })
            }
            return filtered
        }

        private fun parseScheduleSlots(
            courseId: String,
            courseName: String,
            teacher: String,
            raw: String,
        ): List<ParsedSlot> {
            if (raw.isBlank()) return emptyList()
            val result = mutableListOf<ParsedSlot>()
            raw.split(";").map { it.trim() }.filter { it.isNotEmpty() }.forEach { segment ->
                val weekMatch = WEEK_REGEX.matcher(segment)
                if (!weekMatch.find()) return@forEach
                val weekText = weekMatch.group(1) ?: return@forEach

                val dayMatch = DAY_REGEX.matcher(segment)
                if (!dayMatch.find()) return@forEach
                val weekday = WEEKDAY_MAP[dayMatch.group(1)] ?: return@forEach

                val sectionMatch = SECTION_REGEX.matcher(segment)
                if (!sectionMatch.find()) return@forEach
                val startSection = sectionMatch.group(1)?.toIntOrNull() ?: return@forEach
                val endSection = sectionMatch.group(2)?.toIntOrNull() ?: return@forEach
                val locationStart = sectionMatch.end()
                val location = if (locationStart < segment.length) {
                    segment.substring(locationStart).trim()
                } else {
                    ""
                }

                val activeWeeks = expandWeeks(weekText)
                result.add(
                    ParsedSlot(
                        courseId = courseId,
                        courseName = courseName,
                        teacher = teacher,
                        location = location,
                        weekday = weekday,
                        startSection = startSection,
                        endSection = endSection,
                        activeWeeks = activeWeeks,
                        color = pickColor(courseName),
                    ),
                )
            }
            return result
        }

        private fun expandWeeks(weekText: String): List<Int> {
            val weekType = when {
                weekText.contains("单") -> "odd"
                weekText.contains("双") -> "even"
                else -> "all"
            }

            val cleaned = weekText
                .replace("单周", "")
                .replace("双周", "")
                .replace("周", "")
                .trim()

            val weeks = mutableSetOf<Int>()
            cleaned.split(",")
                .map { it.trim() }
                .filter { it.isNotEmpty() }
                .forEach { part ->
                    if (part.contains("-")) {
                        val pieces = part.split("-")
                        if (pieces.size == 2) {
                            val start = pieces[0].trim().toIntOrNull()
                            val end = pieces[1].trim().toIntOrNull()
                            if (start != null && end != null) {
                                for (week in start..end) {
                                    if (matchesWeekType(week, weekType)) {
                                        weeks.add(week)
                                    }
                                }
                            }
                        }
                    } else {
                        val week = part.toIntOrNull()
                        if (week != null && matchesWeekType(week, weekType)) {
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
                val key = keys.next()
                val child = datas.optJSONObject(key) ?: continue
                val rows = child.optJSONArray("rows")
                if (rows != null) {
                    return rows
                }
            }
            return null
        }

        private fun appendRows(targetRoot: JSONObject, additionalRows: JSONArray) {
            val targetRows = extractRows(targetRoot) ?: return
            for (i in 0 until additionalRows.length()) {
                val item = additionalRows.opt(i)
                if (item != null) {
                    targetRows.put(item)
                }
            }
        }

        private fun semesterStartForCode(code: String): String {
            val startYear = code.take(4).toIntOrNull() ?: return firstMondayOnOrAfter(2026, 3, 1)
            val month = if (code.endsWith("1")) 9 else 3
            val year = if (code.endsWith("1")) startYear else startYear + 1
            return firstMondayOnOrAfter(year, month, 1)
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

        private fun pickColor(courseName: String): Int {
            if (courseName.isBlank()) return COURSE_COLORS.first()
            val index = (courseName.hashCode() and 0x7fffffff) % COURSE_COLORS.size
            return COURSE_COLORS[index]
        }

        private fun normalizeCustomIntervalMinutes(minutes: Int?): Int {
            val value = minutes ?: DEFAULT_CUSTOM_INTERVAL_MINUTES
            return value.coerceIn(MIN_CUSTOM_INTERVAL_MINUTES, MAX_CUSTOM_INTERVAL_MINUTES)
        }

        private fun computeNextTriggerMillis(
            prefs: SharedPreferences,
            frequency: String,
            customIntervalMinutes: Int?,
            afterSuccessfulSync: Boolean,
            preserveExistingCustomSchedule: Boolean,
        ): Long {
            val now = Calendar.getInstance()
            if (frequency == "custom") {
                val nowMillis = now.timeInMillis
                val intervalMillis =
                    normalizeCustomIntervalMinutes(customIntervalMinutes) * 60_000L
                if (!afterSuccessfulSync && preserveExistingCustomSchedule) {
                    val existingNextMillis = parseIsoString(
                        prefs.getString(flutterKey(KEY_NEXT_SYNC), null),
                    )
                    if (existingNextMillis != null && existingNextMillis > nowMillis) {
                        return existingNextMillis
                    }

                    val lastFetchMillis = parseIsoString(
                        prefs.getString(flutterKey(KEY_LAST_FETCH), null),
                    )
                    val lastAttemptMillis = parseIsoString(
                        prefs.getString(flutterKey(KEY_LAST_ATTEMPT), null),
                    )
                    val anchorMillis =
                        maxOf(lastFetchMillis ?: Long.MIN_VALUE, lastAttemptMillis ?: Long.MIN_VALUE)
                    if (anchorMillis != Long.MIN_VALUE) {
                        val anchoredTriggerMillis = anchorMillis + intervalMillis
                        if (anchoredTriggerMillis > nowMillis) {
                            return anchoredTriggerMillis
                        }
                    }
                }
                return nowMillis + intervalMillis
            }
            val target = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 6)
                set(Calendar.MINUTE, 30)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }

            when (frequency) {
                "weekly" -> {
                    target.set(Calendar.DAY_OF_WEEK, Calendar.MONDAY)
                    if (afterSuccessfulSync || target.timeInMillis <= now.timeInMillis) {
                        target.add(Calendar.WEEK_OF_YEAR, 1)
                    }
                }
                "monthly" -> {
                    target.set(Calendar.DAY_OF_MONTH, 1)
                    if (afterSuccessfulSync || target.timeInMillis <= now.timeInMillis) {
                        target.add(Calendar.MONTH, 1)
                        target.set(Calendar.DAY_OF_MONTH, 1)
                    }
                }
                else -> {
                    if (afterSuccessfulSync || target.timeInMillis <= now.timeInMillis) {
                        target.add(Calendar.DAY_OF_YEAR, 1)
                    }
                }
            }
            return target.timeInMillis
        }

        private fun createPendingIntent(context: Context): PendingIntent {
            val intent = Intent(context, AutoSyncScheduler::class.java).apply {
                action = ACTION_RUN
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            return PendingIntent.getBroadcast(context, REQUEST_CODE, intent, flags)
        }

        private fun flutterPrefs(context: Context) =
            context.getSharedPreferences(PREFS_FLUTTER, Context.MODE_PRIVATE)

        private fun flutterKey(key: String): String = "flutter.$key"

        private fun toIsoString(timeMillis: Long): String {
            val format = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
            format.timeZone = TimeZone.getTimeZone("UTC")
            return format.format(Date(timeMillis))
        }

        private fun parseIsoString(value: String?): Long? {
            if (value.isNullOrBlank()) return null
            return try {
                val format = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
                format.timeZone = TimeZone.getTimeZone("UTC")
                format.parse(value)?.time
            } catch (_: Throwable) {
                null
            }
        }

        private data class ParsedSlot(
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
    }
}

package com.ttm.ttm_app.widget

import android.content.Context
import android.util.Base64
import androidx.glance.appwidget.updateAll
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.time.Instant

/// 위젯에서 시작·연장·종료한 활동 상태를 Supabase worker_presence 에 반영한다.
/// (앱과 동일한 upsert — NearbyErrandsWorker 와 같은 자격증명 프리퍼런스 사용)
class ActivityPresenceWorker(
    private val appContext: Context,
    params: WorkerParameters,
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result {
        val goOnline = inputData.getBoolean(KEY_ONLINE, false)
        val untilMillis = inputData.getLong(KEY_UNTIL, 0L)

        val ok = withContext(Dispatchers.IO) { upsertPresence(goOnline, untilMillis) }
        if (ok) return Result.success()

        if (runAttemptCount >= 2) {
            // 서버 반영 실패 확정 — 켜려던 경우 위젯을 OFF 로 되돌려 오표시를 막는다.
            if (goOnline) {
                ActivityPrefs.prefs(appContext).edit()
                    .putString(ActivityPrefs.KEY_STATUS, "offline")
                    .remove(ActivityPrefs.KEY_UNTIL)
                    .apply()
                TtmActivityWidget().updateAll(appContext)
                ActivityWidgetTicker.ensureScheduled(appContext)
            }
            return Result.failure()
        }
        return Result.retry()
    }

    private fun upsertPresence(goOnline: Boolean, untilMillis: Long): Boolean {
        val prefs = ActivityPrefs.prefs(appContext)

        val supabaseUrl = prefs.getString("flutter.widget_supabase_url", null) ?: return false
        val anonKey    = prefs.getString("flutter.widget_anon_key", null)     ?: return false
        val authToken  = prefs.getString("flutter.widget_auth_token", null)   ?: return false
        val workerId   = jwtSubject(authToken) ?: return false

        return try {
            val body = JSONObject().apply {
                put("worker_id", workerId)
                put("status", if (goOnline) "online" else "offline")
                put("updated_at", Instant.now().toString())
                if (goOnline && untilMillis > 0) {
                    put("online_until", Instant.ofEpochMilli(untilMillis).toString())
                } else {
                    put("online_until", JSONObject.NULL)
                }
                if (goOnline) {
                    // 최근 앱 사용 시 저장된 좌표가 있으면 함께 갱신 (없으면 기존 geo 유지)
                    val locStr = prefs.getString("flutter.widget_location", null)
                    val parts = locStr?.split(",")
                    val lat = parts?.getOrNull(0)?.toDoubleOrNull()
                    val lng = parts?.getOrNull(1)?.toDoubleOrNull()
                    if (lat != null && lng != null && !(lat == 0.0 && lng == 0.0)) {
                        put("geo", "POINT($lng $lat)")
                        put("share_location", true)
                    }
                }
            }.toString()

            val conn = (URL("$supabaseUrl/rest/v1/worker_presence?on_conflict=worker_id")
                .openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("apikey", anonKey)
                setRequestProperty("Authorization", "Bearer $authToken")
                setRequestProperty("Prefer", "resolution=merge-duplicates")
                doOutput = true
                connectTimeout = 10_000
                readTimeout = 10_000
            }

            OutputStreamWriter(conn.outputStream, "UTF-8").use { it.write(body) }
            conn.responseCode in 200..299
        } catch (_: Exception) {
            false
        }
    }

    private fun jwtSubject(token: String): String? = try {
        val payload = token.split(".").getOrNull(1) ?: return null
        val json = String(
            Base64.decode(payload, Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP),
            Charsets.UTF_8,
        )
        JSONObject(json).optString("sub").ifEmpty { null }
    } catch (_: Exception) {
        null
    }

    companion object {
        private const val WORK_NAME = "ttm_activity_presence"
        private const val KEY_ONLINE = "online"
        private const val KEY_UNTIL = "until"

        fun enqueue(context: Context, goOnline: Boolean, untilMillis: Long = 0L) {
            val request = OneTimeWorkRequestBuilder<ActivityPresenceWorker>()
                .setInputData(
                    Data.Builder()
                        .putBoolean(KEY_ONLINE, goOnline)
                        .putLong(KEY_UNTIL, untilMillis)
                        .build(),
                )
                .setConstraints(
                    Constraints.Builder()
                        .setRequiredNetworkType(NetworkType.CONNECTED)
                        .build(),
                )
                .build()

            WorkManager.getInstance(context).enqueueUniqueWork(
                WORK_NAME,
                ExistingWorkPolicy.REPLACE,
                request,
            )
        }
    }
}

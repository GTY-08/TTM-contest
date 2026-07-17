package com.ttm.ttm_app.widget

import android.content.Context
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import androidx.glance.appwidget.updateAll
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.TimeUnit

class NearbyErrandsWorker(
    private val appContext: Context,
    params: WorkerParameters,
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result {
        val success = withContext(Dispatchers.IO) { fetchAndSave() }
        if (success) TtmBrowseWidget().updateAll(appContext)
        return if (success) Result.success() else Result.retry()
    }

    private fun fetchAndSave(): Boolean {
        val prefs = appContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        val supabaseUrl = prefs.getString("flutter.widget_supabase_url", null) ?: return false
        val anonKey    = prefs.getString("flutter.widget_anon_key", null)     ?: return false
        val authToken  = prefs.getString("flutter.widget_auth_token", null)   ?: return false
        val locStr     = prefs.getString("flutter.widget_location", null)     ?: return false

        val parts = locStr.split(",")
        if (parts.size < 2) return false
        val lat = parts[0].toDoubleOrNull() ?: return false
        val lng = parts[1].toDoubleOrNull() ?: return false
        if (lat == 0.0 && lng == 0.0) return false

        return try {
            val body = JSONObject().apply {
                put("p_lat", lat)
                put("p_lng", lng)
                put("p_max_distance_m", 2000)
                put("p_limit", 10)
                put("p_matching_mode", "general")
            }.toString()

            val conn = (URL("$supabaseUrl/rest/v1/rpc/browse_open_requests")
                .openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("apikey", anonKey)
                setRequestProperty("Authorization", "Bearer $authToken")
                doOutput = true
                connectTimeout = 10_000
                readTimeout = 10_000
            }

            OutputStreamWriter(conn.outputStream, "UTF-8").use { it.write(body) }

            if (conn.responseCode != 200) return false

            val responseText = BufferedReader(InputStreamReader(conn.inputStream, "UTF-8"))
                .use { it.readText() }

            val root = JSONObject(responseText)
            if (!root.optBoolean("ok")) return false

            val items = root.optJSONArray("items") ?: return true

            val errands = JSONArray()
            for (i in 0 until minOf(items.length(), 5)) {
                val item = items.optJSONObject(i) ?: continue
                val req  = item.optJSONObject("request") ?: continue
                val distKm = item.optDouble("distance_km", -1.0)
                val dist = when {
                    distKm < 0  -> ""
                    distKm < 1.0 -> "${(distKm * 1000).toInt()}m"
                    else         -> "${"%.1f".format(distKm)}km"
                }
                errands.put(JSONObject().apply {
                    put("taskType",  req.optString("task_type", "other"))
                    put("title",     req.optString("title").ifEmpty { req.optString("description", "") })
                    put("distance",  dist)
                    put("rewardWon", req.optInt("reward", 0))
                })
            }

            prefs.edit()
                .putString("flutter.nearby_errands", errands.toString())
                .putLong("flutter.nearby_count", items.length().toLong())
                .apply()

            true
        } catch (_: Exception) {
            false
        }
    }

    companion object {
        private const val WORK_NAME = "ttm_nearby_errands"

        fun enqueue(context: Context) {
            val request = PeriodicWorkRequestBuilder<NearbyErrandsWorker>(
                15, TimeUnit.MINUTES,
            ).setConstraints(
                Constraints.Builder()
                    .setRequiredNetworkType(NetworkType.CONNECTED)
                    .build(),
            ).build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                request,
            )
        }
    }
}

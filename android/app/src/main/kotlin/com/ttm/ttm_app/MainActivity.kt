package com.ttm.ttm_app

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import com.ttm.ttm_app.service.ActiveErrandService
import com.ttm.ttm_app.widget.TtmActivityMediumWidgetReceiver
import com.ttm.ttm_app.widget.TtmActivitySmallWidgetReceiver
import com.ttm.ttm_app.widget.TtmBrowseWidgetReceiver
import com.ttm.ttm_app.widget.TtmRequestMediumWidgetReceiver
import com.ttm.ttm_app.widget.TtmRequestSmallWidgetReceiver
import com.ttm.ttm_app.widget.TtmWorkWidgetReceiver
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.ttm.ttm_app/widgets",
        ).setMethodCallHandler { call, result ->
            if (call.method == "updateWidgets") {
                updateWidgets()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.ttm.ttm_app/active_errand",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start", "update" -> {
                    val data = mapOf(
                        ActiveErrandService.EXTRA_STAGE         to (call.argument<Int>("stage") ?: 0),
                        ActiveErrandService.EXTRA_WORKER_NAME   to (call.argument<String>("workerName") ?: "작업자"),
                        ActiveErrandService.EXTRA_WORKER_RATING to (call.argument<Double>("workerRating") ?: 0.0),
                        ActiveErrandService.EXTRA_TITLE         to (call.argument<String>("title") ?: ""),
                        ActiveErrandService.EXTRA_REWARD_WON    to (call.argument<Int>("rewardWon") ?: 0),
                        ActiveErrandService.EXTRA_ROLE          to (call.argument<String>("role") ?: "requester"),
                    )
                    ActiveErrandService.launch(this, data)
                    result.success(null)
                }
                "stop" -> {
                    ActiveErrandService.stop(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun updateWidgets() {
        val manager = AppWidgetManager.getInstance(this)
        val receivers = listOf(
            TtmRequestSmallWidgetReceiver::class.java,
            TtmRequestMediumWidgetReceiver::class.java,
            TtmBrowseWidgetReceiver::class.java,
            TtmWorkWidgetReceiver::class.java,
            TtmActivitySmallWidgetReceiver::class.java,
            TtmActivityMediumWidgetReceiver::class.java,
        )
        for (receiver in receivers) {
            val widgetComponent = ComponentName(this, receiver)
            val ids = manager.getAppWidgetIds(widgetComponent)
            if (ids.isEmpty()) continue
            val intent = Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE).apply {
                component = widgetComponent
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            sendBroadcast(intent)
        }
    }
}

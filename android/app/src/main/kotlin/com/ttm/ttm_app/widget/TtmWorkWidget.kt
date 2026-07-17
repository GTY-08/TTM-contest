package com.ttm.ttm_app.widget

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalContext
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.lazy.LazyColumn
import androidx.glance.appwidget.lazy.items
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxHeight
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.layout.wrapContentWidth
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.ttm.ttm_app.R
import org.json.JSONArray

private data class WorkItem(
    val kind: String,
    val status: String,
    val taskType: String,
    val title: String,
    val subtitle: String,
    val rewardWon: Int,
    val route: String,
)

private fun loadWorkItems(context: Context): Pair<List<WorkItem>, Int> {
    val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    val json = prefs.getString("flutter.work_items", null) ?: return Pair(emptyList(), 0)
    val count = try { prefs.getLong("flutter.work_item_count", 0L).toInt() } catch (e: Exception) { 0 }
    return try {
        val arr = JSONArray(json)
        val items = (0 until arr.length()).map { i ->
            val o = arr.getJSONObject(i)
            WorkItem(
                kind = o.optString("kind", "active"),
                status = o.optString("status", "진행중"),
                taskType = o.optString("taskType", "other"),
                title = o.optString("title", ""),
                subtitle = o.optString("subtitle", ""),
                rewardWon = o.optInt("rewardWon", 0),
                route = o.optString("route", "/home?tab=activity"),
            )
        }
        Pair(items, if (count > 0) count else arr.length())
    } catch (e: Exception) {
        Pair(emptyList(), 0)
    }
}

private val WPrimary = Color(0xFF2EA86A)
private val WDeepGreen = Color(0xFF15803F)
private val WDarkText = Color(0xFF1E2A23)
private val WSubText = Color(0xFF7C8580)
private val WMutedText = Color(0xFF9AA0A0)
private val WLightGreenBg = Color(0xFFE6F0E9)
private val WBadgeBg = Color(0xFFEEF4EF)
private val WSeparator = Color(0xFFF1EEE5)
private val WWhite = Color(0xFFFFFFFF)

private fun routeIntent(context: Context, route: String): Intent {
    val path = if (route.startsWith("/")) route else "/$route"
    return Intent(Intent.ACTION_VIEW, Uri.parse("ttm://app$path")).apply {
        `package` = context.packageName
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
    }
}

class TtmWorkWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Single

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val (items, count) = loadWorkItems(context)
        provideContent {
            WorkContent(items, count)
        }
    }
}

@Composable
private fun WorkContent(items: List<WorkItem>, count: Int) {
    val context = LocalContext.current
    Box(
        modifier = GlanceModifier
            .fillMaxSize()
            .cornerRadius(24.dp)
            .background(ColorProvider(WWhite))
            .clickable(actionStartActivity(routeIntent(context, "/home?tab=activity"))),
        contentAlignment = Alignment.TopStart,
    ) {
        Column(
            modifier = GlanceModifier
                .fillMaxSize()
                .padding(horizontal = 16.dp, vertical = 14.dp),
        ) {
            Row(
                modifier = GlanceModifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    modifier = GlanceModifier
                        .size(26.dp)
                        .cornerRadius(7.dp)
                        .background(ColorProvider(WPrimary)),
                    contentAlignment = Alignment.Center,
                ) {
                    Image(
                        provider = ImageProvider(R.drawable.ic_widget_errand),
                        contentDescription = null,
                        modifier = GlanceModifier.size(15.dp),
                    )
                }
                Spacer(modifier = GlanceModifier.width(7.dp))
                Text(
                    text = "내 작업",
                    modifier = GlanceModifier.defaultWeight(),
                    style = TextStyle(
                        color = ColorProvider(WDarkText),
                        fontSize = 17.sp,
                        fontWeight = FontWeight.Bold,
                    ),
                )
                if (count > 0) {
                    WorkCountBadge(count)
                }
            }

            Spacer(modifier = GlanceModifier.height(8.dp))

            if (items.isEmpty()) {
                WorkEmptyState()
            } else {
                LazyColumn(
                    modifier = GlanceModifier
                        .fillMaxWidth()
                        .defaultWeight(),
                ) {
                    items(items) { item ->
                        WorkRow(context, item)
                        Box(
                            modifier = GlanceModifier
                                .fillMaxWidth()
                                .height(1.dp)
                                .background(ColorProvider(WSeparator)),
                        ) {}
                    }
                }
            }
        }
    }
}

@Composable
private fun WorkCountBadge(count: Int) {
    Box(
        modifier = GlanceModifier
            .wrapContentWidth()
            .cornerRadius(20.dp)
            .background(ColorProvider(WBadgeBg))
            .padding(horizontal = 10.dp, vertical = 4.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = "${count}개",
            style = TextStyle(
                color = ColorProvider(WDeepGreen),
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
            ),
        )
    }
}

@Composable
private fun WorkRow(context: Context, item: WorkItem) {
    Row(
        modifier = GlanceModifier
            .fillMaxWidth()
            .padding(vertical = 7.dp)
            .clickable(actionStartActivity(routeIntent(context, item.route))),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = GlanceModifier
                .wrapContentWidth()
                .cornerRadius(14.dp)
                .background(ColorProvider(WLightGreenBg))
                .padding(horizontal = 8.dp, vertical = 3.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = item.status,
                style = TextStyle(
                    color = ColorProvider(WDeepGreen),
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                ),
            )
        }
        Spacer(modifier = GlanceModifier.width(9.dp))
        Column(modifier = GlanceModifier.defaultWeight()) {
            Text(
                text = item.title.ifBlank { "심부름" },
                style = TextStyle(
                    color = ColorProvider(WDarkText),
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium,
                ),
                maxLines = 1,
            )
            if (item.subtitle.isNotEmpty()) {
                Text(
                    text = item.subtitle,
                    style = TextStyle(
                        color = ColorProvider(WSubText),
                        fontSize = 11.sp,
                    ),
                    maxLines = 1,
                )
            }
        }
        Spacer(modifier = GlanceModifier.width(6.dp))
        Text(
            text = "₩${"%,d".format(item.rewardWon)}",
            style = TextStyle(
                color = ColorProvider(WPrimary),
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
            ),
        )
    }
}

@Composable
private fun WorkEmptyState() {
    Box(
        modifier = GlanceModifier
            .fillMaxWidth()
            .fillMaxHeight(),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = "진행중이거나 지원한 작업이 없어요",
            style = TextStyle(
                color = ColorProvider(WMutedText),
                fontSize = 13.sp,
            ),
        )
    }
}

class TtmWorkWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = TtmWorkWidget()
}

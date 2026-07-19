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

// ─── Data ─────────────────────────────────────────────────────────────────────

private data class NearbyErrand(
    val taskType: String,
    val title: String,
    val distance: String,
    val rewardWon: Int,
)

private fun taskTypeLabel(type: String) = when (type) {
    "delivery" -> "배달"
    "purchase" -> "구매"
    "pet" -> "돌봄"
    "waiting" -> "대기"
    "cleaning" -> "청소"
    else -> "기타"
}

private fun loadNearbyErrands(context: Context): Pair<List<NearbyErrand>, Int> {
    val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    val json = prefs.getString("flutter.nearby_errands", null) ?: return Pair(emptyList(), 0)
    val count = try { prefs.getLong("flutter.nearby_count", 0L).toInt() } catch (e: Exception) { 0 }
    return try {
        val arr = JSONArray(json)
        val items = (0 until minOf(arr.length(), 2)).map { i ->
            val o = arr.getJSONObject(i)
            NearbyErrand(
                taskType = o.optString("taskType", "other"),
                title = o.optString("title", ""),
                distance = o.optString("distance", ""),
                rewardWon = o.optInt("rewardWon", 0),
            )
        }
        Pair(items, if (count > 0) count else arr.length())
    } catch (e: Exception) {
        Pair(emptyList(), 0)
    }
}

// ─── Brand colors ─────────────────────────────────────────────────────────────

private val BPrimary = Color(0xFF2EA86A)
private val BDeepGreen = Color(0xFF15803F)
private val BDarkText = Color(0xFF1E2A23)
private val BSubText = Color(0xFF9AA0A0)
private val BLightGreenBg = Color(0xFFE6F0E9)
private val BBadgeBg = Color(0xFFEEF4EF)
private val BSeparator = Color(0xFFF1EEE5)
private val BWhite = Color(0xFFFFFFFF)

// ─── Deep-link ────────────────────────────────────────────────────────────────

private const val BROWSE_DEEP_LINK = "ttm://app/home?tab=find"

private fun browseIntent(context: Context): Intent =
    Intent(Intent.ACTION_VIEW, Uri.parse(BROWSE_DEEP_LINK)).apply {
        `package` = context.packageName
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
    }

// ═════════════════════════════════════════════════════════════════════════════
//  Widget
// ═════════════════════════════════════════════════════════════════════════════

class TtmBrowseWidget : GlanceAppWidget() {

    override val sizeMode = SizeMode.Single

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val (errands, count) = loadNearbyErrands(context)
        provideContent {
            BrowseContent(errands, count)
        }
    }
}

// ─── Medium 4×2 ───────────────────────────────────────────────────────────────

@Composable
private fun BrowseContent(errands: List<NearbyErrand>, count: Int) {
    val context = LocalContext.current
    Box(
        modifier = GlanceModifier
            .fillMaxSize()
            .cornerRadius(24.dp)
            .background(ColorProvider(BWhite))
            .clickable(actionStartActivity(browseIntent(context))),
        contentAlignment = Alignment.TopStart,
    ) {
        Column(
            modifier = GlanceModifier
                .fillMaxSize()
                .padding(horizontal = 16.dp, vertical = 14.dp),
        ) {
            // Header row
            Row(
                modifier = GlanceModifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    modifier = GlanceModifier
                        .size(26.dp)
                        .cornerRadius(7.dp)
                        .background(ColorProvider(BPrimary)),
                    contentAlignment = Alignment.Center,
                ) {
                    Image(
                        provider = ImageProvider(R.drawable.ic_widget_search),
                        contentDescription = null,
                        modifier = GlanceModifier.size(15.dp),
                    )
                }
                Spacer(modifier = GlanceModifier.width(7.dp))
                Text(
                    text = "주변 ○○",
                    modifier = GlanceModifier.defaultWeight(),
                    style = TextStyle(
                        color = ColorProvider(BDarkText),
                        fontSize = 17.sp,
                        fontWeight = FontWeight.Bold,
                    ),
                )
                if (count > 0) {
                    CountBadge(count)
                }
            }

            Spacer(modifier = GlanceModifier.height(10.dp))

            if (errands.isEmpty()) {
                EmptyState()
            } else {
                ErrandRow(errands[0])
                Spacer(modifier = GlanceModifier.height(1.dp))
                Box(
                    modifier = GlanceModifier
                        .fillMaxWidth()
                        .height(1.dp)
                        .background(ColorProvider(BSeparator)),
                ) {}
                Spacer(modifier = GlanceModifier.height(1.dp))
                if (errands.size >= 2) {
                    ErrandRow(errands[1])
                }
            }
        }
    }
}

@Composable
private fun CountBadge(count: Int) {
    Box(
        modifier = GlanceModifier
            .wrapContentWidth()
            .cornerRadius(20.dp)
            .background(ColorProvider(BBadgeBg))
            .padding(horizontal = 10.dp, vertical = 4.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = "${count}건 열림",
            style = TextStyle(
                color = ColorProvider(BDeepGreen),
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
            ),
        )
    }
}

@Composable
private fun ErrandRow(errand: NearbyErrand) {
    Row(
        modifier = GlanceModifier
            .fillMaxWidth()
            .padding(vertical = 7.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // Category badge
        Box(
            modifier = GlanceModifier
                .wrapContentWidth()
                .cornerRadius(14.dp)
                .background(ColorProvider(BLightGreenBg))
                .padding(horizontal = 8.dp, vertical = 3.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = taskTypeLabel(errand.taskType),
                style = TextStyle(
                    color = ColorProvider(BDeepGreen),
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                ),
            )
        }
        Spacer(modifier = GlanceModifier.width(10.dp))
        // Title (fills remaining space)
        Text(
            text = errand.title,
            modifier = GlanceModifier.defaultWeight(),
            style = TextStyle(
                color = ColorProvider(BDarkText),
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
            ),
            maxLines = 1,
        )
        Spacer(modifier = GlanceModifier.width(6.dp))
        // Distance
        if (errand.distance.isNotEmpty()) {
            Text(
                text = errand.distance,
                style = TextStyle(
                    color = ColorProvider(BSubText),
                    fontSize = 12.sp,
                ),
            )
            Spacer(modifier = GlanceModifier.width(8.dp))
        }
        // Reward
        Text(
            text = "₩${"%,d".format(errand.rewardWon)}",
            style = TextStyle(
                color = ColorProvider(BPrimary),
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
            ),
        )
    }
}

@Composable
private fun EmptyState() {
    Box(
        modifier = GlanceModifier
            .fillMaxWidth()
            .fillMaxHeight(),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = "탭해서 주변 ○○ 보기",
            style = TextStyle(
                color = ColorProvider(BSubText),
                fontSize = 13.sp,
            ),
        )
    }
}

// ═════════════════════════════════════════════════════════════════════════════
//  Receiver — WorkManager 등록
// ═════════════════════════════════════════════════════════════════════════════

class TtmBrowseWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = TtmBrowseWidget()

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        NearbyErrandsWorker.enqueue(context)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: android.appwidget.AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        NearbyErrandsWorker.enqueue(context)
    }
}

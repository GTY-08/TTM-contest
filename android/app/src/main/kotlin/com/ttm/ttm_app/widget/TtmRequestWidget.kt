package com.ttm.ttm_app.widget

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalContext
import androidx.glance.LocalSize
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
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.layout.wrapContentHeight
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.ttm.ttm_app.R

// ─── Sizes ────────────────────────────────────────────────────────────────────
private val SMALL_SIZE = DpSize(120.dp, 120.dp)
private val MEDIUM_SIZE = DpSize(240.dp, 120.dp)

// ─── Brand colors ─────────────────────────────────────────────────────────────
private val Primary = Color(0xFF2EA86A)
private val LightGreenBg = Color(0xFFE6F0E9)
private val LightGreenBtn = Color(0xFFF4F7F2)
private val DarkText = Color(0xFF1E2A23)
private val SubText = Color(0xFF9AA0A0)
private val White = Color(0xFFFFFFFF)
private val White80 = Color(0xCCFFFFFF)
private val White22 = Color(0x38FFFFFF)

// ─── Deep-link ────────────────────────────────────────────────────────────────
private const val DEEP_LINK = "ttm://app/request/new"

// ═════════════════════════════════════════════════════════════════════════════
//  Widget
// ═════════════════════════════════════════════════════════════════════════════

class TtmRequestWidget : GlanceAppWidget() {

    override val sizeMode = SizeMode.Responsive(setOf(SMALL_SIZE, MEDIUM_SIZE))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            val size = LocalSize.current
            if (size.width >= MEDIUM_SIZE.width) MediumContent() else SmallContent()
        }
    }
}

// ─── Small 2×2 ────────────────────────────────────────────────────────────────

@Composable
private fun SmallContent() {
    val context = LocalContext.current
    Box(
        modifier = GlanceModifier
            .fillMaxSize()
            .cornerRadius(24.dp)
            .background(ColorProvider(Primary))
            .clickable(actionStartActivity(launchIntent(context, DEEP_LINK))),
        contentAlignment = Alignment.TopStart,
    ) {
        Column(
            modifier = GlanceModifier
                .fillMaxSize()
                .padding(16.dp),
        ) {
            Row(
                modifier = GlanceModifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "틈틈",
                    modifier = GlanceModifier.defaultWeight(),
                    style = TextStyle(
                        color = ColorProvider(White),
                        fontSize = 17.sp,
                        fontWeight = FontWeight.Bold,
                    ),
                )
                Box(
                    modifier = GlanceModifier
                        .size(34.dp)
                        .cornerRadius(17.dp)
                        .background(ColorProvider(White22)),
                    contentAlignment = Alignment.Center,
                ) {
                    Image(
                        provider = ImageProvider(R.drawable.ic_widget_plus_white),
                        contentDescription = null,
                        modifier = GlanceModifier.size(18.dp),
                    )
                }
            }

            Spacer(modifier = GlanceModifier.defaultWeight())

            Text(
                text = "○○\n맡기기",
                style = TextStyle(
                    color = ColorProvider(White),
                    fontSize = 24.sp,
                    fontWeight = FontWeight.Bold,
                ),
            )
            Spacer(modifier = GlanceModifier.height(5.dp))
            Text(
                text = "탭하면 바로 요청",
                style = TextStyle(
                    color = ColorProvider(White80),
                    fontSize = 14.sp,
                ),
            )
        }
    }
}

// ─── Medium 4×2 (6 categories in 2 rows of 3) ────────────────────────────────

@Composable
private fun MediumContent() {
    val context = LocalContext.current
    Box(
        modifier = GlanceModifier
            .fillMaxSize()
            .cornerRadius(24.dp)
            .background(ColorProvider(White)),
        contentAlignment = Alignment.TopStart,
    ) {
        Column(
            modifier = GlanceModifier
                .fillMaxSize()
                .padding(horizontal = 16.dp, vertical = 14.dp),
        ) {
            // Header
            Row(
                modifier = GlanceModifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    modifier = GlanceModifier
                        .size(30.dp)
                        .cornerRadius(8.dp)
                        .background(ColorProvider(Primary)),
                    contentAlignment = Alignment.Center,
                ) {
                    Image(
                        provider = ImageProvider(R.drawable.ic_widget_logo_white),
                        contentDescription = null,
                        modifier = GlanceModifier.size(26.dp),
                    )
                }
                Spacer(modifier = GlanceModifier.width(8.dp))
                Text(
                    text = "○○ 맡기기",
                    modifier = GlanceModifier.defaultWeight(),
                    style = TextStyle(
                        color = ColorProvider(DarkText),
                        fontSize = 17.sp,
                        fontWeight = FontWeight.Bold,
                    ),
                )
                Box(
                    modifier = GlanceModifier
                        .size(34.dp)
                        .cornerRadius(17.dp)
                        .background(ColorProvider(LightGreenBg))
                        .clickable(actionStartActivity(launchIntent(context, DEEP_LINK))),
                    contentAlignment = Alignment.Center,
                ) {
                    Image(
                        provider = ImageProvider(R.drawable.ic_widget_plus_green),
                        contentDescription = "요청 추가",
                        modifier = GlanceModifier.size(18.dp),
                    )
                }
            }

            Spacer(modifier = GlanceModifier.height(10.dp))

            // Row 1: 배달, 구매, 청소
            Row(modifier = GlanceModifier.fillMaxWidth()) {
                CategoryButton(context, R.drawable.ic_widget_delivery, "배달", "delivery", GlanceModifier.defaultWeight())
                Spacer(modifier = GlanceModifier.width(6.dp))
                CategoryButton(context, R.drawable.ic_widget_purchase, "구매", "purchase", GlanceModifier.defaultWeight())
                Spacer(modifier = GlanceModifier.width(6.dp))
                CategoryButton(context, R.drawable.ic_widget_cleaning, "청소", "cleaning", GlanceModifier.defaultWeight())
            }

            Spacer(modifier = GlanceModifier.height(6.dp))

            // Row 2: 대기, 돌봄, 기타
            Row(modifier = GlanceModifier.fillMaxWidth()) {
                CategoryButton(context, R.drawable.ic_widget_waiting, "대기", "waiting", GlanceModifier.defaultWeight())
                Spacer(modifier = GlanceModifier.width(6.dp))
                CategoryButton(context, R.drawable.ic_widget_care, "돌봄", "pet", GlanceModifier.defaultWeight())
                Spacer(modifier = GlanceModifier.width(6.dp))
                CategoryButton(context, R.drawable.ic_widget_other, "기타", "other", GlanceModifier.defaultWeight())
            }
        }
    }
}

@Composable
private fun CategoryButton(
    context: Context,
    iconRes: Int,
    label: String,
    taskType: String,
    modifier: GlanceModifier = GlanceModifier,
) {
    Column(
        modifier = modifier
            .wrapContentHeight()
            .cornerRadius(12.dp)
            .background(ColorProvider(LightGreenBtn))
            .padding(vertical = 8.dp)
            .clickable(actionStartActivity(launchIntent(context, "$DEEP_LINK?taskType=$taskType"))),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Image(
            provider = ImageProvider(iconRes),
            contentDescription = label,
            modifier = GlanceModifier.size(18.dp),
        )
        Spacer(modifier = GlanceModifier.height(4.dp))
        Text(
            text = label,
            style = TextStyle(
                color = ColorProvider(DarkText),
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
            ),
        )
    }
}

// ─── Helper ───────────────────────────────────────────────────────────────────

private fun launchIntent(context: Context, uri: String): Intent =
    Intent(Intent.ACTION_VIEW, Uri.parse(uri)).apply {
        `package` = context.packageName
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
    }

// ═════════════════════════════════════════════════════════════════════════════
//  Receivers
// ═════════════════════════════════════════════════════════════════════════════

class TtmRequestSmallWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = TtmRequestWidget()
}

class TtmRequestMediumWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = TtmRequestWidget()
}

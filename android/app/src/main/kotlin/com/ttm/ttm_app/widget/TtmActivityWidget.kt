package com.ttm.ttm_app.widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
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
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.LinearProgressIndicator
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.updateAll
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
import androidx.glance.layout.wrapContentWidth
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.ttm.ttm_app.R
import kotlinx.coroutines.runBlocking
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

// ─── Sizes ────────────────────────────────────────────────────────────────────
private val SMALL_SIZE = DpSize(120.dp, 120.dp)
private val MEDIUM_SIZE = DpSize(240.dp, 120.dp)

// ─── Brand colors ─────────────────────────────────────────────────────────────
private val Primary = Color(0xFF2EA86A)
private val DarkGreenPill = Color(0xFF1E8A50)
private val DarkText = Color(0xFF1E2A23)
private val SubText = Color(0xFF7C8580)
private val MutedText = Color(0xFF9AA0A0)
private val ChipBg = Color(0xFFF4F7F2)
private val OffCircleBg = Color(0xFFF1F1EC)
private val OffChipText = Color(0xFF9AA0A0)
private val BorderTone = Color(0xFFE5E3DA)
private val White = Color(0xFFFFFFFF)
private val White80 = Color(0xCCFFFFFF)
private val White22 = Color(0x38FFFFFF)

// ═════════════════════════════════════════════════════════════════════════════
//  Prefs — Flutter shared_preferences 와 공유 (flutter. 접두사)
// ═════════════════════════════════════════════════════════════════════════════

object ActivityPrefs {
    const val STORE = "FlutterSharedPreferences"
    const val KEY_STATUS = "flutter.widget_activity_status"     // "online" | "offline"
    const val KEY_UNTIL = "flutter.widget_activity_until"       // epoch millis (문자열)
    const val KEY_TOTAL_MIN = "flutter.widget_activity_total_min"
    const val KEY_RADIUS_KM = "flutter.widget_activity_radius_km"

    fun prefs(context: Context) =
        context.getSharedPreferences(STORE, Context.MODE_PRIVATE)
}

data class ActivityState(
    val isOn: Boolean,
    val untilMillis: Long,
    val totalMinutes: Int,
    val radiusKm: String?,
) {
    val remainingMillis: Long
        get() = (untilMillis - System.currentTimeMillis()).coerceAtLeast(0L)

    /// 진행 링·바에 쓰는 "남은 비율" (1.0 = 방금 시작).
    val remainingFraction: Float
        get() {
            val total = totalMinutes * 60_000L
            if (total <= 0) return 0f
            return (remainingMillis.toFloat() / total.toFloat()).coerceIn(0f, 1f)
        }
}

fun loadActivityState(context: Context): ActivityState {
    val prefs = ActivityPrefs.prefs(context)
    val status = prefs.getString(ActivityPrefs.KEY_STATUS, null)
    val until = prefs.getString(ActivityPrefs.KEY_UNTIL, null)?.toLongOrNull() ?: 0L
    val total = prefs.getString(ActivityPrefs.KEY_TOTAL_MIN, null)?.toIntOrNull() ?: 0
    val radius = prefs.getString(ActivityPrefs.KEY_RADIUS_KM, null)
        ?.removeSuffix(".0")?.takeIf { it.isNotBlank() }
    val isOn = (status == "online" || status == "busy") &&
        until > System.currentTimeMillis()
    return ActivityState(isOn, until, total, radius)
}

// ═════════════════════════════════════════════════════════════════════════════
//  분 단위 카운트다운 틱 (AlarmManager — 활동 중일 때만 체인)
// ═════════════════════════════════════════════════════════════════════════════

object ActivityWidgetTicker {
    const val ACTION_TICK = "com.ttm.ttm_app.ACTIVITY_WIDGET_TICK"
    private const val REQUEST_CODE = 9102

    private fun tickIntent(context: Context): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            Intent(context, TtmActivitySmallWidgetReceiver::class.java)
                .setAction(ACTION_TICK),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    fun ensureScheduled(context: Context) {
        val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val state = loadActivityState(context)
        if (!state.isOn) {
            alarm.cancel(tickIntent(context))
            return
        }
        val now = System.currentTimeMillis()
        val next = minOf(now + 60_000L, state.untilMillis + 1_000L)
        alarm.set(AlarmManager.RTC, next, tickIntent(context))
    }

    fun onTick(context: Context) {
        val prefs = ActivityPrefs.prefs(context)
        val status = prefs.getString(ActivityPrefs.KEY_STATUS, null)
        val until = prefs.getString(ActivityPrefs.KEY_UNTIL, null)?.toLongOrNull() ?: 0L
        if (status == "online" && until <= System.currentTimeMillis()) {
            // 설정 시간 만료 → 자동 OFF + 서버 동기화
            prefs.edit()
                .putString(ActivityPrefs.KEY_STATUS, "offline")
                .remove(ActivityPrefs.KEY_UNTIL)
                .apply()
            ActivityPresenceWorker.enqueue(context, goOnline = false)
        }
        runBlocking { TtmActivityWidget().updateAll(context) }
        ensureScheduled(context)
    }
}

// ═════════════════════════════════════════════════════════════════════════════
//  위젯 액션 — 시작 / 연장 / 종료 (위젯 표면에서 앱 없이 처리)
// ═════════════════════════════════════════════════════════════════════════════

val durationMinParam = ActionParameters.Key<Int>("durationMin")

class StartActivityAction : ActionCallback {
    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters,
    ) {
        val minutes = parameters[durationMinParam] ?: 60
        val until = System.currentTimeMillis() + minutes * 60_000L
        ActivityPrefs.prefs(context).edit()
            .putString(ActivityPrefs.KEY_STATUS, "online")
            .putString(ActivityPrefs.KEY_UNTIL, until.toString())
            .putString(ActivityPrefs.KEY_TOTAL_MIN, minutes.toString())
            .apply()
        ActivityPresenceWorker.enqueue(context, goOnline = true, untilMillis = until)
        TtmActivityWidget().updateAll(context)
        ActivityWidgetTicker.ensureScheduled(context)
    }
}

class ExtendActivityAction : ActionCallback {
    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters,
    ) {
        val prefs = ActivityPrefs.prefs(context)
        val now = System.currentTimeMillis()
        val stored = prefs.getString(ActivityPrefs.KEY_UNTIL, null)?.toLongOrNull() ?: now
        val until = maxOf(now, stored) + 30 * 60_000L
        val total = (prefs.getString(ActivityPrefs.KEY_TOTAL_MIN, null)?.toIntOrNull() ?: 0) + 30
        prefs.edit()
            .putString(ActivityPrefs.KEY_STATUS, "online")
            .putString(ActivityPrefs.KEY_UNTIL, until.toString())
            .putString(ActivityPrefs.KEY_TOTAL_MIN, total.toString())
            .apply()
        ActivityPresenceWorker.enqueue(context, goOnline = true, untilMillis = until)
        TtmActivityWidget().updateAll(context)
        ActivityWidgetTicker.ensureScheduled(context)
    }
}

class StopActivityAction : ActionCallback {
    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters,
    ) {
        ActivityPrefs.prefs(context).edit()
            .putString(ActivityPrefs.KEY_STATUS, "offline")
            .remove(ActivityPrefs.KEY_UNTIL)
            .apply()
        ActivityPresenceWorker.enqueue(context, goOnline = false)
        TtmActivityWidget().updateAll(context)
        ActivityWidgetTicker.ensureScheduled(context)
    }
}

// ═════════════════════════════════════════════════════════════════════════════
//  Widget
// ═════════════════════════════════════════════════════════════════════════════

class TtmActivityWidget : GlanceAppWidget() {

    override val sizeMode = SizeMode.Responsive(setOf(SMALL_SIZE, MEDIUM_SIZE))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val state = loadActivityState(context)
        provideContent {
            val size = LocalSize.current
            val medium = size.width >= MEDIUM_SIZE.width
            when {
                medium && state.isOn -> MediumOnContent(state)
                medium -> MediumOffContent()
                state.isOn -> SmallOnContent(state)
                else -> SmallOffContent()
            }
        }
    }
}

private fun homeIntent(context: Context, query: String = ""): Intent =
    Intent(Intent.ACTION_VIEW, Uri.parse("ttm://app/home$query")).apply {
        `package` = context.packageName
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
    }

private fun formatEndTime(untilMillis: Long): String =
    SimpleDateFormat("H:mm", Locale.KOREA).format(Date(untilMillis))

private fun remainingLabel(remainMillis: Long): String {
    val totalMin = ((remainMillis + 59_999L) / 60_000L).toInt().coerceAtLeast(0)
    val h = totalMin / 60
    val m = totalMin % 60
    return if (h > 0) "${h}시간 ${m}분" else "${m}분"
}

// ─── Small 2×2 · OFF ─────────────────────────────────────────────────────────

@Composable
private fun SmallOffContent() {
    Box(
        modifier = GlanceModifier
            .fillMaxSize()
            .cornerRadius(24.dp)
            .background(ColorProvider(White))
            .clickable(
                actionRunCallback<StartActivityAction>(
                    actionParametersOf(durationMinParam to 60),
                ),
            ),
    ) {
        Column(
            modifier = GlanceModifier.fillMaxSize().padding(14.dp),
            horizontalAlignment = Alignment.Start,
        ) {
            Row(
                modifier = GlanceModifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "활동 OFF",
                    modifier = GlanceModifier.defaultWeight(),
                    style = TextStyle(
                        color = ColorProvider(DarkText),
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold,
                    ),
                )
                // 꺼진 토글 그래픽
                Box(
                    modifier = GlanceModifier
                        .size(34.dp, 20.dp)
                        .cornerRadius(10.dp)
                        .background(ColorProvider(Color(0xFFE8E8E3)))
                        .padding(2.dp),
                    contentAlignment = Alignment.CenterStart,
                ) {
                    Box(
                        modifier = GlanceModifier
                            .size(16.dp)
                            .cornerRadius(8.dp)
                            .background(ColorProvider(White)),
                    ) {}
                }
            }
            Spacer(modifier = GlanceModifier.defaultWeight())
            Box(
                modifier = GlanceModifier
                    .size(44.dp)
                    .cornerRadius(22.dp)
                    .background(ColorProvider(OffCircleBg)),
                contentAlignment = Alignment.Center,
            ) {
                Image(
                    provider = ImageProvider(R.drawable.ic_widget_bell_off),
                    contentDescription = null,
                    modifier = GlanceModifier.size(22.dp),
                )
            }
            Spacer(modifier = GlanceModifier.height(8.dp))
            Text(
                text = "알림 받기 꺼짐",
                style = TextStyle(
                    color = ColorProvider(DarkText),
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                ),
            )
            Text(
                text = "탭하여 켜기",
                style = TextStyle(
                    color = ColorProvider(MutedText),
                    fontSize = 11.sp,
                ),
            )
        }
    }
}

// ─── Small 2×2 · ON ──────────────────────────────────────────────────────────

@Composable
private fun SmallOnContent(state: ActivityState) {
    val context = LocalContext.current
    Box(
        modifier = GlanceModifier
            .fillMaxSize()
            .cornerRadius(24.dp)
            .background(ColorProvider(Primary))
            .clickable(actionStartActivity(homeIntent(context))),
    ) {
        Column(
            modifier = GlanceModifier.fillMaxSize().padding(12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Row(
                modifier = GlanceModifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    modifier = GlanceModifier
                        .size(7.dp)
                        .cornerRadius(4.dp)
                        .background(ColorProvider(White)),
                ) {}
                Spacer(modifier = GlanceModifier.width(5.dp))
                Text(
                    text = "활동 중",
                    style = TextStyle(
                        color = ColorProvider(White),
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                    ),
                )
            }
            Spacer(modifier = GlanceModifier.defaultWeight())
            Box(contentAlignment = Alignment.Center) {
                Image(
                    provider = ImageProvider(ringBitmap(state.remainingFraction)),
                    contentDescription = null,
                    modifier = GlanceModifier.size(76.dp),
                )
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = shortRemainingLabel(state.remainingMillis),
                        style = TextStyle(
                            color = ColorProvider(White),
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold,
                        ),
                    )
                    Text(
                        text = "남음",
                        style = TextStyle(
                            color = ColorProvider(White80),
                            fontSize = 10.sp,
                        ),
                    )
                }
            }
            Spacer(modifier = GlanceModifier.defaultWeight())
            Text(
                text = "${formatEndTime(state.untilMillis)} 종료 예정",
                style = TextStyle(
                    color = ColorProvider(White80),
                    fontSize = 10.sp,
                ),
            )
        }
    }
}

private fun shortRemainingLabel(remainMillis: Long): String {
    val totalMin = ((remainMillis + 59_999L) / 60_000L).toInt().coerceAtLeast(0)
    val h = totalMin / 60
    val m = totalMin % 60
    return if (h > 0) "%d:%02d".format(h, m) else "${m}분"
}

private fun ringBitmap(remainingFraction: Float): Bitmap {
    val px = 240
    val stroke = 24f
    val bitmap = Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = stroke
        strokeCap = Paint.Cap.ROUND
    }
    val rect = RectF(stroke / 2, stroke / 2, px - stroke / 2, px - stroke / 2)
    paint.color = 0x38FFFFFF
    canvas.drawArc(rect, 0f, 360f, false, paint)
    paint.color = 0xFFFFFFFF.toInt()
    canvas.drawArc(rect, -90f, 360f * remainingFraction.coerceIn(0f, 1f), false, paint)
    return bitmap
}

// ─── Medium 4×2 · OFF ────────────────────────────────────────────────────────

@Composable
private fun MediumOffContent() {
    val context = LocalContext.current
    Box(
        modifier = GlanceModifier
            .fillMaxSize()
            .cornerRadius(24.dp)
            .background(ColorProvider(White)),
    ) {
        Column(
            modifier = GlanceModifier
                .fillMaxSize()
                .padding(horizontal = 16.dp, vertical = 12.dp),
        ) {
            Row(
                modifier = GlanceModifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    modifier = GlanceModifier
                        .size(7.dp)
                        .cornerRadius(4.dp)
                        .background(ColorProvider(Color(0xFFB9C0BB))),
                ) {}
                Spacer(modifier = GlanceModifier.width(6.dp))
                Text(
                    text = "활동 OFF",
                    modifier = GlanceModifier.defaultWeight(),
                    style = TextStyle(
                        color = ColorProvider(DarkText),
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold,
                    ),
                )
                Box(
                    modifier = GlanceModifier
                        .wrapContentWidth()
                        .cornerRadius(12.dp)
                        .background(ColorProvider(OffCircleBg))
                        .padding(horizontal = 9.dp, vertical = 3.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "꺼짐",
                        style = TextStyle(
                            color = ColorProvider(OffChipText),
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                        ),
                    )
                }
            }
            Spacer(modifier = GlanceModifier.height(2.dp))
            Text(
                text = "시간을 선택하면 바로 활동을 시작해요",
                style = TextStyle(
                    color = ColorProvider(SubText),
                    fontSize = 11.sp,
                ),
            )
            Spacer(modifier = GlanceModifier.defaultWeight())
            Row(modifier = GlanceModifier.fillMaxWidth()) {
                DurationChip(label = "30분", minutes = 30)
                Spacer(modifier = GlanceModifier.width(6.dp))
                DurationChip(label = "1시간", minutes = 60)
                Spacer(modifier = GlanceModifier.width(6.dp))
                DurationChip(label = "2시간", minutes = 120)
                Spacer(modifier = GlanceModifier.width(6.dp))
                DurationChip(label = "4시간", minutes = 240)
            }
            Spacer(modifier = GlanceModifier.height(8.dp))
            // 얇은 테두리 흉내: 톤 배경 위 1dp 패딩 + 흰 상자
            Box(
                modifier = GlanceModifier
                    .fillMaxWidth()
                    .height(34.dp)
                    .cornerRadius(12.dp)
                    .background(ColorProvider(BorderTone))
                    .padding(1.dp)
                    .clickable(
                        actionStartActivity(homeIntent(context, "?activitySheet=1")),
                    ),
            ) {
                Box(
                    modifier = GlanceModifier
                        .fillMaxSize()
                        .cornerRadius(11.dp)
                        .background(ColorProvider(White)),
                    contentAlignment = Alignment.Center,
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Image(
                            provider = ImageProvider(R.drawable.ic_widget_clock),
                            contentDescription = null,
                            modifier = GlanceModifier.size(13.dp),
                        )
                        Spacer(modifier = GlanceModifier.width(5.dp))
                        Text(
                            text = "직접 시간 설정",
                            style = TextStyle(
                                color = ColorProvider(Color(0xFF3A443E)),
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Medium,
                            ),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun androidx.glance.layout.RowScope.DurationChip(label: String, minutes: Int) {
    Box(
        modifier = GlanceModifier
            .defaultWeight()
            .height(32.dp)
            .cornerRadius(12.dp)
            .background(ColorProvider(ChipBg))
            .clickable(
                actionRunCallback<StartActivityAction>(
                    actionParametersOf(durationMinParam to minutes),
                ),
            ),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            style = TextStyle(
                color = ColorProvider(DarkText),
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
            ),
        )
    }
}

// ─── Medium 4×2 · ON ─────────────────────────────────────────────────────────

@Composable
private fun MediumOnContent(state: ActivityState) {
    Box(
        modifier = GlanceModifier
            .fillMaxSize()
            .cornerRadius(24.dp)
            .background(ColorProvider(Primary)),
    ) {
        Column(
            modifier = GlanceModifier
                .fillMaxSize()
                .padding(horizontal = 16.dp, vertical = 12.dp),
        ) {
            Row(
                modifier = GlanceModifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    modifier = GlanceModifier
                        .size(7.dp)
                        .cornerRadius(4.dp)
                        .background(ColorProvider(White)),
                ) {}
                Spacer(modifier = GlanceModifier.width(6.dp))
                Text(
                    text = "활동 중",
                    modifier = GlanceModifier.defaultWeight(),
                    style = TextStyle(
                        color = ColorProvider(White),
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold,
                    ),
                )
                Box(
                    modifier = GlanceModifier
                        .wrapContentWidth()
                        .cornerRadius(12.dp)
                        .background(ColorProvider(DarkGreenPill))
                        .padding(horizontal = 9.dp, vertical = 3.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = state.radiusKm?.let { "${it}km 수신 중" } ?: "수신 중",
                        style = TextStyle(
                            color = ColorProvider(White),
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                        ),
                    )
                }
            }
            Spacer(modifier = GlanceModifier.height(4.dp))
            Text(
                text = "남은 시간",
                style = TextStyle(
                    color = ColorProvider(White80),
                    fontSize = 11.sp,
                ),
            )
            Row(
                modifier = GlanceModifier.fillMaxWidth(),
                verticalAlignment = Alignment.Bottom,
            ) {
                Text(
                    text = remainingLabel(state.remainingMillis),
                    modifier = GlanceModifier.defaultWeight(),
                    style = TextStyle(
                        color = ColorProvider(White),
                        fontSize = 24.sp,
                        fontWeight = FontWeight.Bold,
                    ),
                )
                Text(
                    text = "${formatEndTime(state.untilMillis)} 종료 예정",
                    style = TextStyle(
                        color = ColorProvider(White80),
                        fontSize = 11.sp,
                    ),
                )
            }
            Spacer(modifier = GlanceModifier.height(6.dp))
            LinearProgressIndicator(
                modifier = GlanceModifier.fillMaxWidth().height(5.dp).cornerRadius(3.dp),
                progress = state.remainingFraction,
                color = ColorProvider(White),
                backgroundColor = ColorProvider(White22),
            )
            Spacer(modifier = GlanceModifier.defaultWeight())
            Row(modifier = GlanceModifier.fillMaxWidth()) {
                Box(
                    modifier = GlanceModifier
                        .defaultWeight()
                        .height(36.dp)
                        .cornerRadius(18.dp)
                        .background(ColorProvider(White22))
                        .clickable(actionRunCallback<ExtendActivityAction>()),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "+30분 연장",
                        style = TextStyle(
                            color = ColorProvider(White),
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Bold,
                            textAlign = TextAlign.Center,
                        ),
                    )
                }
                Spacer(modifier = GlanceModifier.width(8.dp))
                Box(
                    modifier = GlanceModifier
                        .defaultWeight()
                        .height(36.dp)
                        .cornerRadius(18.dp)
                        .background(ColorProvider(White))
                        .clickable(actionRunCallback<StopActivityAction>()),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "활동 종료",
                        style = TextStyle(
                            color = ColorProvider(Primary),
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Bold,
                            textAlign = TextAlign.Center,
                        ),
                    )
                }
            }
        }
    }
}

// ═════════════════════════════════════════════════════════════════════════════
//  Receivers
// ═════════════════════════════════════════════════════════════════════════════

class TtmActivitySmallWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = TtmActivityWidget()

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ActivityWidgetTicker.ACTION_TICK) {
            ActivityWidgetTicker.onTick(context)
            return
        }
        super.onReceive(context, intent)
        ActivityWidgetTicker.ensureScheduled(context)
    }
}

class TtmActivityMediumWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = TtmActivityWidget()

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        ActivityWidgetTicker.ensureScheduled(context)
    }
}

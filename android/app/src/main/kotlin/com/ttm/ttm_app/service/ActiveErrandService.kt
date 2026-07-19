package com.ttm.ttm_app.service

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.ttm.ttm_app.MainActivity
import com.ttm.ttm_app.R

class ActiveErrandService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                @Suppress("DEPRECATION")
                stopForeground(true)
                stopSelf()
            }
            else -> {
                val stage      = intent?.getIntExtra(EXTRA_STAGE, 0) ?: 0
                val worker     = intent?.getStringExtra(EXTRA_WORKER_NAME) ?: "작업자"
                val rating     = intent?.getDoubleExtra(EXTRA_WORKER_RATING, 0.0) ?: 0.0
                val title      = intent?.getStringExtra(EXTRA_TITLE) ?: ""
                val reward     = intent?.getIntExtra(EXTRA_REWARD_WON, 0) ?: 0
                val role       = intent?.getStringExtra(EXTRA_ROLE) ?: "requester"
                startForeground(NOTIF_ID, buildNotification(stage, worker, rating, title, reward, role))
            }
        }
        return START_NOT_STICKY
    }

    // ── Notification ──────────────────────────────────────────────────────────

    private fun buildNotification(
        stage: Int,
        workerName: String,
        workerRating: Double,
        title: String,
        rewardWon: Int,
        role: String,
    ): android.app.Notification {
        val stageLabel  = STAGE_LABELS.getOrElse(stage) { "진행 중" }
        val ratingStr   = if (workerRating > 0) " ★${"%.1f".format(workerRating)}" else ""
        val rewardStr   = "₩${"%,d".format(rewardWon)}"
        val stages      = STAGE_LABELS.mapIndexed { i, s -> if (i == stage) "[$s]" else s }.joinToString(" › ")

        val launchPi = pendingIntent(0)
        val chatPi   = pendingIntent(1)

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_ttm)
            .setColor(Color.parseColor("#2EA86A"))
            .setContentTitle("진행 중 ○○")
            .setContentText("$stageLabel  ·  ${workerName}님$ratingStr")
            .setSubText(title)
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .setBigContentTitle("진행 중 ○○")
                    .bigText("$stages\n${workerName}님$ratingStr  ·  $title  ·  $rewardStr"),
            )
            .setContentIntent(launchPi)
            .setOngoing(stage < 4)
            .setAutoCancel(stage == 4)
            .setShowWhen(false)
            .addAction(R.drawable.ic_widget_chat, "채팅 열기", chatPi)

        val showAction =
            (role == "worker" && stage == 2) || (role == "requester" && stage == 3)
        if (showAction) {
            val label = if (role == "worker") "작업 인증하기" else "인증 검토하기"
            builder.addAction(R.drawable.ic_widget_verify, label, pendingIntent(2))
        }

        return builder.build()
    }

    private fun pendingIntent(requestCode: Int): PendingIntent {
        val intent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            this,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "진행 중 ○○",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "현재 진행 중인 ○○ 상태를 표시합니다"
                setShowBadge(false)
            }
            (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }
    }

    companion object {
        private const val NOTIF_ID   = 9001
        private const val CHANNEL_ID = "ttm_active_errand"

        const val ACTION_STOP         = "com.ttm.ttm_app.ACTIVE_ERRAND_STOP"
        const val EXTRA_STAGE         = "stage"
        const val EXTRA_WORKER_NAME   = "worker_name"
        const val EXTRA_WORKER_RATING = "worker_rating"
        const val EXTRA_TITLE         = "title"
        const val EXTRA_REWARD_WON    = "reward_won"
        const val EXTRA_ROLE          = "role"

        private val STAGE_LABELS = listOf("찾는 중", "수락됨", "수행 중", "확인 대기", "완료")

        fun buildIntent(context: Context, data: Map<String, Any?>): Intent =
            Intent(context, ActiveErrandService::class.java).apply {
                data.forEach { (k, v) ->
                    when (v) {
                        is Int    -> putExtra(k, v)
                        is Double -> putExtra(k, v)
                        is String -> putExtra(k, v)
                        else      -> Unit
                    }
                }
            }

        fun launch(context: Context, data: Map<String, Any?>) {
            val intent = buildIntent(context, data)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, ActiveErrandService::class.java))
        }
    }
}

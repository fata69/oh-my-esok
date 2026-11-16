package com.habib.jadwal

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Paint
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.TypedValue
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject
import java.util.Locale
import kotlin.math.roundToInt

class TaskWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (appWidgetId in appWidgetIds) {
            appWidgetManager.updateAppWidget(appWidgetId, buildViews(context, appWidgetId))
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        appWidgetManager.updateAppWidget(appWidgetId, buildViews(context, appWidgetId))
    }

    companion object {
        private const val DEFAULT_WIDTH_DP = 320
        private const val DEFAULT_HEIGHT_DP = 160

        private const val REFERENCE_WIDTH_DP = 320f
        private const val REFERENCE_HEIGHT_DP = 160f
        private const val MIN_SCALE = 0.85f
        private const val MAX_SCALE = 1.9f

        private data class Metrics(
            val labelSp: Float,
            val counterSp: Float,
            val titleSp: Float,
            val timeSp: Float,
            val emptySp: Float,
            val paddingDp: Int,
            val rowHeightDp: Int,
            val checkSizeDp: Int,
            val maxRows: Int,
        )

        private fun metricsFor(widthDp: Int, heightDp: Int): Metrics {
            val widthScale = widthDp / REFERENCE_WIDTH_DP
            val heightScale = heightDp / REFERENCE_HEIGHT_DP
            val weighted = widthScale * 0.6f + heightScale * 0.4f
            val widthCap = widthDp / 240f
            val scale = minOf(weighted, widthCap).coerceIn(MIN_SCALE, MAX_SCALE)

            val labelSp = 12f * scale
            val counterSp = 13f * scale
            val titleSp = 16f * scale
            val timeSp = 12.5f * scale
            val emptySp = 14f * scale
            val paddingDp = (16f * scale).roundToInt().coerceAtLeast(10)
            val rowHeightDp = (44f * scale).roundToInt().coerceAtLeast(36)

            val headerHeightDp = labelSp * 1.6f + 8f
            val availableDp = heightDp - paddingDp * 2 - headerHeightDp
            val maxRows = (availableDp / rowHeightDp).toInt().coerceIn(1, 8)

            return Metrics(
                labelSp = labelSp,
                counterSp = counterSp,
                titleSp = titleSp,
                timeSp = timeSp,
                emptySp = emptySp,
                paddingDp = paddingDp,
                rowHeightDp = rowHeightDp,
                checkSizeDp = rowHeightDp,
                maxRows = maxRows,
            )
        }

        private fun dp(context: Context, value: Int): Int =
            (value * context.resources.displayMetrics.density).roundToInt()

        private fun applyFrame(context: Context, views: RemoteViews, metrics: Metrics) {
            val padding = dp(context, metrics.paddingDp)
            views.setViewPadding(R.id.widget_root, padding, padding, padding, padding)
            views.setTextViewTextSize(
                R.id.widget_label,
                TypedValue.COMPLEX_UNIT_SP,
                metrics.labelSp,
            )
            views.setTextViewTextSize(
                R.id.widget_counter,
                TypedValue.COMPLEX_UNIT_SP,
                metrics.counterSp,
            )
        }

        private fun applyRow(row: RemoteViews, metrics: Metrics) {
            row.setTextViewTextSize(
                R.id.task_title,
                TypedValue.COMPLEX_UNIT_SP,
                metrics.titleSp,
            )
            row.setTextViewTextSize(
                R.id.task_time,
                TypedValue.COMPLEX_UNIT_SP,
                metrics.timeSp,
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                row.setViewLayoutHeight(
                    R.id.task_row,
                    metrics.rowHeightDp.toFloat(),
                    TypedValue.COMPLEX_UNIT_DIP,
                )
                row.setViewLayoutWidth(
                    R.id.task_check,
                    metrics.checkSizeDp.toFloat(),
                    TypedValue.COMPLEX_UNIT_DIP,
                )
                row.setViewLayoutHeight(
                    R.id.task_check,
                    metrics.checkSizeDp.toFloat(),
                    TypedValue.COMPLEX_UNIT_DIP,
                )
            }
        }

        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, TaskWidgetProvider::class.java),
            )
            for (id in ids) {
                manager.updateAppWidget(id, buildViews(context, id))
            }
        }

        fun buildViews(context: Context, appWidgetId: Int): RemoteViews {
            val options = try {
                AppWidgetManager.getInstance(context).getAppWidgetOptions(appWidgetId)
            } catch (error: Exception) {
                Bundle()
            }
            val widthDp = options
                .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
                .takeIf { it > 0 } ?: DEFAULT_WIDTH_DP
            val heightDp = options
                .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
                .takeIf { it > 0 } ?: DEFAULT_HEIGHT_DP
            val metrics = metricsFor(widthDp, heightDp)

            val views = RemoteViews(context.packageName, R.layout.task_widget)
            applyFrame(context, views, metrics)
            val ink = context.getColor(R.color.widget_ink)
            val muted = context.getColor(R.color.widget_muted)
            val doneColor = context.getColor(R.color.widget_positive)

            val prefs = HomeWidgetPlugin.getData(context)
            val raw = prefs.getString("tasks_json", "{}") ?: "{}"
            val root = try {
                JSONObject(raw)
            } catch (error: Exception) {
                JSONObject()
            }
            val dates = root.keys().asSequence().sorted().toList()
            var selected: JSONObject? = null
            var selectedDate = ""
            for (key in dates) {
                val day = root.optJSONObject(key) ?: continue
                if (day.optInt("total", 0) > 0) {
                    selected = day
                    selectedDate = key
                    break
                }
            }
            val items = selected?.optJSONArray("tasks") ?: JSONArray()
            val total = selected?.optInt("total", items.length()) ?: 0
            var done = 0
            var shown = 0
            val dayLabel = selected?.optString("label", "") ?: ""

            views.removeAllViews(R.id.widget_rows)

            for (index in 0 until items.length()) {
                val item = items.optJSONObject(index) ?: continue
                if (item.optBoolean("done", false)) done++
            }

            val maxRows = minOf(3, metrics.maxRows)
            for (index in 0 until minOf(items.length(), maxRows)) {
                val item = items.optJSONObject(index) ?: continue
                val isDone = item.optBoolean("done", false)
                shown++

                val row = RemoteViews(context.packageName, R.layout.task_widget_item)
                applyRow(row, metrics)
                row.setTextViewText(R.id.task_title, item.optString("title"))
                row.setTextViewText(
                    R.id.task_time,
                    item.optString("time").replace(":", "."),
                )
                if (isDone) {
                    row.setTextColor(R.id.task_title, muted)
                    row.setInt(
                        R.id.task_title,
                        "setPaintFlags",
                        Paint.ANTI_ALIAS_FLAG or Paint.STRIKE_THRU_TEXT_FLAG,
                    )
                    row.setImageViewResource(R.id.task_check, R.drawable.widget_check_on)
                } else {
                    row.setTextColor(R.id.task_title, ink)
                    row.setImageViewResource(R.id.task_check, R.drawable.widget_check_off)
                }

                val taskId = item.optString("id")
                val toggleIntent = Intent(context, TaskToggleReceiver::class.java).apply {
                    action = TaskToggleReceiver.ACTION_TOGGLE
                    putExtra(TaskToggleReceiver.EXTRA_TASK_ID, taskId)
                    putExtra(TaskToggleReceiver.EXTRA_DONE, !isDone)
                }
                val togglePending = PendingIntent.getBroadcast(
                    context,
                    taskId.hashCode(),
                    toggleIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                row.setOnClickPendingIntent(R.id.task_check, togglePending)

                val openIntent = Intent(context, MainActivity::class.java).apply {
                    data = Uri.parse("jadwal://task/$taskId")
                    action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }
                val openPending = PendingIntent.getActivity(
                    context,
                    taskId.hashCode() + 7,
                    openIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                row.setOnClickPendingIntent(R.id.task_body, openPending)

                views.addView(R.id.widget_rows, row)
            }

            if (items.length() > shown) {
                val more = RemoteViews(context.packageName, R.layout.task_widget_more)
                more.setTextViewText(
                    R.id.widget_more,
                    "+${items.length() - shown} lagi",
                )
                more.setTextViewTextSize(
                    R.id.widget_more,
                    TypedValue.COMPLEX_UNIT_SP,
                    metrics.timeSp,
                )
                views.addView(R.id.widget_rows, more)
            }

            if (shown == 0) {
                val empty = RemoteViews(context.packageName, R.layout.task_widget_empty)
                empty.setTextViewText(R.id.widget_empty_text, "Tidak ada catatan")
                empty.setTextViewTextSize(
                    R.id.widget_empty_text,
                    TypedValue.COMPLEX_UNIT_SP,
                    metrics.emptySp,
                )
                views.addView(R.id.widget_rows, empty)
            }

            if (selected == null) {
                views.setTextViewText(R.id.widget_label, "TIDAK ADA CATATAN")
                views.setTextColor(R.id.widget_label, muted)
            } else if (done == total) {
                views.setTextViewText(R.id.widget_label, "✓ Semua selesai")
                views.setTextColor(R.id.widget_label, doneColor)
            } else {
                views.setTextViewText(
                    R.id.widget_label,
                    dayLabel.uppercase(Locale("id", "ID")),
                )
                views.setTextColor(R.id.widget_label, muted)
            }
            views.setTextViewText(
                R.id.widget_counter,
                if (selected == null) "" else "$done/$total",
            )

            val headerIntent = if (selectedDate.isNotEmpty()) {
                Intent(context, MainActivity::class.java).apply {
                    data = Uri.parse("jadwal://day/$selectedDate")
                    action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }
            } else {
                Intent(context, MainActivity::class.java).apply {
                    action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }
            }
            views.setOnClickPendingIntent(
                R.id.widget_header,
                PendingIntent.getActivity(
                    context,
                    100,
                    headerIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )

            return views
        }
    }
}

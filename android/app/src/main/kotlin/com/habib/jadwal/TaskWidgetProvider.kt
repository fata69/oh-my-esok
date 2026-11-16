package com.habib.jadwal

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
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
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            refreshAll(context)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (appWidgetId in appWidgetIds) {
            appWidgetManager.updateAppWidget(appWidgetId, buildViews(context, appWidgetId))
            appWidgetManager.notifyAppWidgetViewDataChanged(
                appWidgetId,
                R.id.widget_list,
            )
        }
        super.onUpdate(context, appWidgetManager, appWidgetIds)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        appWidgetManager.updateAppWidget(appWidgetId, buildViews(context, appWidgetId))
        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_list)
    }

    companion object {
        private const val DEFAULT_WIDTH_DP = 320
        private const val DEFAULT_HEIGHT_DP = 160

        private const val REFERENCE_WIDTH_DP = 320f
        private const val REFERENCE_HEIGHT_DP = 160f
        private const val MIN_SCALE = 0.85f
        private const val MAX_SCALE = 1.9f

        internal data class Metrics(
            val labelSp: Float,
            val counterSp: Float,
            val titleSp: Float,
            val timeSp: Float,
            val emptySp: Float,
            val paddingDp: Int,
            val rowHeightDp: Int,
            val checkSizeDp: Int,
        )

        internal data class TaskDay(
            val date: String,
            val label: String,
            val tasks: JSONArray,
            val total: Int,
            val done: Int,
        )

        internal fun metricsFor(widthDp: Int, heightDp: Int): Metrics {
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

            return Metrics(
                labelSp = labelSp,
                counterSp = counterSp,
                titleSp = titleSp,
                timeSp = timeSp,
                emptySp = emptySp,
                paddingDp = paddingDp,
                rowHeightDp = rowHeightDp,
                checkSizeDp = rowHeightDp,
            )
        }

        internal fun metricsForWidget(context: Context, appWidgetId: Int): Metrics {
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
            return metricsFor(widthDp, heightDp)
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
            views.setTextViewTextSize(
                R.id.widget_empty,
                TypedValue.COMPLEX_UNIT_SP,
                metrics.emptySp,
            )
        }

        internal fun applyRow(row: RemoteViews, metrics: Metrics) {
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

        internal fun selectedDay(context: Context): TaskDay? {
            val raw = HomeWidgetPlugin.getData(context).getString("tasks_json", "{}") ?: "{}"
            val root = try {
                JSONObject(raw)
            } catch (error: Exception) {
                JSONObject()
            }
            val dates = root.keys().asSequence().sorted().toList()
            for (key in dates) {
                val day = root.optJSONObject(key) ?: continue
                val total = day.optInt("total", 0)
                if (total <= 0) continue
                val tasks = day.optJSONArray("tasks") ?: JSONArray()
                var done = 0
                for (index in 0 until tasks.length()) {
                    if (tasks.optJSONObject(index)?.optBoolean("done", false) == true) {
                        done++
                    }
                }
                return TaskDay(
                    date = key,
                    label = day.optString("label", ""),
                    tasks = tasks,
                    total = total,
                    done = done,
                )
            }
            return null
        }

        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, TaskWidgetProvider::class.java),
            )
            for (id in ids) {
                manager.updateAppWidget(id, buildViews(context, id))
                manager.notifyAppWidgetViewDataChanged(id, R.id.widget_list)
            }
        }

        fun buildViews(context: Context, appWidgetId: Int): RemoteViews {
            val metrics = metricsForWidget(context, appWidgetId)
            val views = RemoteViews(context.packageName, R.layout.task_widget)
            applyFrame(context, views, metrics)

            val muted = context.getColor(R.color.widget_muted)
            val doneColor = context.getColor(R.color.widget_positive)
            val day = selectedDay(context)

            val serviceIntent = Intent(context, TaskWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            views.setRemoteAdapter(R.id.widget_list, serviceIntent)
            views.setEmptyView(R.id.widget_list, R.id.widget_empty)

            var templateFlags = PendingIntent.FLAG_UPDATE_CURRENT
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                templateFlags = templateFlags or PendingIntent.FLAG_MUTABLE
            }
            views.setPendingIntentTemplate(
                R.id.widget_list,
                PendingIntent.getActivity(
                    context,
                    200 + appWidgetId,
                    Intent(context, TaskWidgetActionActivity::class.java),
                    templateFlags,
                ),
            )

            if (day == null) {
                views.setTextViewText(R.id.widget_label, "TIDAK ADA CATATAN")
                views.setTextColor(R.id.widget_label, muted)
                views.setTextViewText(R.id.widget_counter, "")
            } else {
                if (day.done == day.total) {
                    views.setTextViewText(R.id.widget_label, "✓ Semua selesai")
                    views.setTextColor(R.id.widget_label, doneColor)
                } else {
                    views.setTextViewText(
                        R.id.widget_label,
                        day.label.uppercase(Locale("id", "ID")),
                    )
                    views.setTextColor(R.id.widget_label, muted)
                }
                views.setTextViewText(R.id.widget_counter, "${day.done}/${day.total}")
            }

            val headerIntent = Intent(context, MainActivity::class.java).apply {
                if (day != null) {
                    data = Uri.parse("ohmyesok://day/${day.date}")
                }
                action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
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

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
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONException
import org.json.JSONObject
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeParseException
import java.util.Locale

class TaskWidgetProvider : AppWidgetProvider() {
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) refreshAll(context)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) update(context, appWidgetManager, id)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        update(context, appWidgetManager, appWidgetId, newOptions)
    }

    companion object {
        private const val TALL_HEIGHT_DP = 206
        private val dateLabel = DateTimeFormatter.ofPattern("EEE, d MMM", Locale.forLanguageTag("id-ID"))

        internal data class Upcoming(val date: LocalDate, val item: JSONObject)

        internal data class Agenda(
            val date: LocalDate,
            val tasks: List<JSONObject>,
            val next: Upcoming?,
        ) {
            private val firstOpen = tasks.firstOrNull { !it.optBoolean("done") }
            val done = tasks.count { it.optBoolean("done") }

            fun rows(tall: Boolean): List<JSONObject> = when {
                tall -> tasks
                firstOpen != null -> listOf(firstOpen)
                next != null -> emptyList()
                else -> tasks.takeLast(1)
            }

            fun showsNext(tall: Boolean): Boolean = next != null && (tall || firstOpen == null)
        }

        internal fun agenda(context: Context): Agenda {
            val data = HomeWidgetPlugin.getData(context)
            return agendaFromSnapshot(
                data.getString("tasks_json", "{}").orEmpty(),
                LocalDate.now(),
                data.getString("pending_toggles", "{}").orEmpty(),
            )
        }

        internal fun agendaFromSnapshot(
            raw: String,
            today: LocalDate,
            pendingToggles: String = "{}",
        ): Agenda {
            val snapshot = parseObject(raw)
            val pending = parseObject(pendingToggles)
            val date = today.toString()
            val current = tasksFrom(snapshot, date, pending)
            val next = snapshot.keys().asSequence()
                .filter { it > date }
                .sorted()
                .firstNotNullOfOrNull { key ->
                    val day = try {
                        LocalDate.parse(key)
                    } catch (_: DateTimeParseException) {
                        return@firstNotNullOfOrNull null
                    }
                    tasksFrom(snapshot, key, pending)
                        .firstOrNull { !it.optBoolean("done") }
                        ?.let { Upcoming(day, it) }
                }
            return Agenda(today, current, next)
        }

        private fun parseObject(raw: String) = try {
            JSONObject(raw)
        } catch (_: JSONException) {
            JSONObject()
        }

        private fun tasksFrom(snapshot: JSONObject, date: String, pending: JSONObject): List<JSONObject> {
            val items = snapshot.optJSONObject(date)?.optJSONArray("tasks") ?: return emptyList()
            return (0 until items.length())
                .mapNotNull { items.optJSONObject(it) }
                .filter { it.optString("id").isNotBlank() }
                .onEach { item ->
                    // A Dart snapshot refresh can finish before a widget tap is
                    // drained to SQLite. Keep displaying the pending choice.
                    (pending.opt(item.optString("id")) as? Boolean)?.let { item.put("done", it) }
                }
                .sortedWith(compareBy({ it.optString("time").isBlank() }, { it.optString("time") }))
        }

        private fun isTall(options: Bundle) =
            options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT) >= TALL_HEIGHT_DP

        internal fun isTallWidget(context: Context, appWidgetId: Int) =
            isTall(AppWidgetManager.getInstance(context).getAppWidgetOptions(appWidgetId))

        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, TaskWidgetProvider::class.java))
            for (id in ids) update(context, manager, id)
        }

        private fun update(
            context: Context,
            manager: AppWidgetManager,
            id: Int,
            options: Bundle = manager.getAppWidgetOptions(id),
        ) {
            manager.updateAppWidget(id, buildViews(context, id, isTall(options)))
            manager.notifyAppWidgetViewDataChanged(id, R.id.widget_list)
        }

        private fun visibility(visible: Boolean) = if (visible) View.VISIBLE else View.GONE

        private fun dayIntent(
            context: Context,
            id: Int,
            date: LocalDate,
            add: Boolean = false,
        ): PendingIntent {
            val uri = Uri.Builder().scheme("ohmyesok").authority("day").appendPath(date.toString())
            if (add) uri.appendQueryParameter("add", "1")
            val launch = Intent(context, MainActivity::class.java).apply {
                data = uri.build()
                action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            return PendingIntent.getActivity(
                context,
                id,
                launch,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private fun buildViews(context: Context, id: Int, tall: Boolean): RemoteViews {
            val agenda = agenda(context)
            val views = RemoteViews(context.packageName, R.layout.task_widget)
            val current = agenda.rows(tall)
            val showNext = agenda.showsNext(tall)
            val date = agenda.date.format(dateLabel)
            val title = if (agenda.tasks.isEmpty() && !showNext) R.string.widget_agenda else R.string.widget_today
            val description = if (agenda.tasks.isEmpty()) {
                date
            } else {
                context.getString(R.string.widget_progress, date, agenda.done, agenda.tasks.size)
            }
            views.setTextViewText(R.id.widget_label, context.getText(title))
            views.setTextViewText(R.id.widget_counter, description)
            views.setOnClickPendingIntent(R.id.widget_header, dayIntent(context, id, agenda.date))
            views.setOnClickPendingIntent(R.id.widget_add, dayIntent(context, id, agenda.date, add = true))

            val service = Intent(context, TaskWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            views.setRemoteAdapter(R.id.widget_list, service)
            val listAction = Intent(context, TaskWidgetActionActivity::class.java).apply {
                data = Uri.parse("ohmyesok://widget/$id")
            }
            val mutability = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
            views.setPendingIntentTemplate(
                R.id.widget_list,
                PendingIntent.getActivity(context, id, listAction, PendingIntent.FLAG_UPDATE_CURRENT or mutability),
            )
            views.setViewVisibility(R.id.widget_list, visibility(current.isNotEmpty()))
            views.setViewVisibility(R.id.widget_empty, visibility(current.isEmpty() && !showNext))
            val next = agenda.next
            views.setViewVisibility(R.id.widget_next, visibility(showNext))
            if (showNext && next != null) {
                views.setTextViewText(
                    R.id.widget_next_date,
                    context.getString(R.string.widget_next, next.date.format(dateLabel)),
                )
                views.setTextViewText(R.id.widget_next_title, next.item.optString("title"))
                views.setTextViewText(R.id.widget_next_time, next.item.optString("time").replace(':', '.'))
                views.setOnClickPendingIntent(R.id.widget_next, dayIntent(context, id, next.date))
            }
            return views
        }
    }
}

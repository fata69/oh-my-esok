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
import android.text.SpannableString
import android.text.Spanned
import android.text.style.StrikethroughSpan
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
            val done = tasks.count { it.optBoolean("done") }

            fun showsNext(tall: Boolean): Boolean = next != null && (tall || tasks.isEmpty())
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

        internal fun doneLabel(title: String): CharSequence =
            if (title.isNotEmpty()) SpannableString(title).apply {
                setSpan(StrikethroughSpan(), 0, length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            } else title

        internal fun toggleExtras(item: JSONObject, date: LocalDate) = Intent().apply {
            putExtra(TaskToggleReceiver.EXTRA_TASK_ID, item.getString("id"))
            putExtra(TaskToggleReceiver.EXTRA_TASK_DAY, date.toString())
            putExtra(TaskToggleReceiver.EXTRA_DONE, !item.optBoolean("done"))
        }

        private fun toggleIntent(context: Context, widgetId: Int, vararg path: String) =
            Intent(context, TaskToggleReceiver::class.java).apply {
                action = TaskToggleReceiver.ACTION_TOGGLE
                val uri = Uri.Builder().scheme("ohmyesok").authority("widget").appendPath(widgetId.toString())
                for (segment in path) uri.appendPath(segment)
                data = uri.build()
            }

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
            val single = agenda.tasks.singleOrNull()
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

            // A standalone row uses a direct broadcast and can animate in place.
            // Multiple tasks use a scrollable collection with one broadcast per row.
            if (single != null) {
                val title = single.optString("title")
                val done = single.optBoolean("done")
                views.setTextViewText(R.id.widget_single_title, title)
                views.setTextViewText(R.id.widget_single_done_title, doneLabel(title))
                views.setTextViewText(R.id.widget_single_time, single.optString("time").replace(':', '.'))
                views.setDisplayedChild(R.id.widget_single_titles, if (done) 1 else 0)
                views.setImageViewResource(
                    R.id.widget_single_check,
                    if (done) R.drawable.widget_check_on else R.drawable.widget_check_off,
                )
                views.setContentDescription(
                    R.id.widget_single,
                    context.getString(if (done) R.string.widget_uncheck_task else R.string.widget_check_task, title),
                )
                val toggle = toggleIntent(context, id, agenda.date.toString(), single.getString("id"))
                    .putExtras(toggleExtras(single, agenda.date))
                views.setOnClickPendingIntent(
                    R.id.widget_single,
                    PendingIntent.getBroadcast(
                        context, id, toggle, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    ),
                )
            } else if (agenda.tasks.size > 1) {
                val service = Intent(context, TaskWidgetService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
                    data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
                }
                views.setRemoteAdapter(R.id.widget_list, service)
                val mutability = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
                views.setPendingIntentTemplate(
                    R.id.widget_list,
                    PendingIntent.getBroadcast(
                        context, id, toggleIntent(context, id), PendingIntent.FLAG_UPDATE_CURRENT or mutability,
                    ),
                )
            }
            views.setViewVisibility(R.id.widget_single, visibility(single != null))
            views.setViewVisibility(R.id.widget_list, visibility(agenda.tasks.size > 1))
            views.setViewVisibility(R.id.widget_empty, visibility(agenda.tasks.isEmpty() && !showNext))
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

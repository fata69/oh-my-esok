package com.habib.jadwal

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Paint
import android.net.Uri
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONObject

class TaskWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        TaskWidgetFactory(applicationContext, intent)
}

private class TaskWidgetFactory(
    private val context: Context,
    intent: Intent,
) : RemoteViewsService.RemoteViewsFactory {
    private val appWidgetId = intent.getIntExtra(
        AppWidgetManager.EXTRA_APPWIDGET_ID,
        AppWidgetManager.INVALID_APPWIDGET_ID,
    )
    private var tasks: List<JSONObject> = emptyList()

    override fun onCreate() {
        reload()
    }

    override fun onDataSetChanged() {
        reload()
    }

    private fun reload() {
        val tall = TaskWidgetProvider.isTallWidget(context, appWidgetId)
        tasks = TaskWidgetProvider.agenda(context).rows(tall)
    }

    override fun getCount(): Int = tasks.size

    override fun getViewAt(position: Int): RemoteViews {
        val row = RemoteViews(context.packageName, R.layout.task_widget_item)
        val item = tasks.getOrNull(position) ?: return row
        val isDone = item.optBoolean("done", false)
        val title = item.optString("title")
        row.setTextViewText(R.id.task_title, title)
        row.setTextViewText(R.id.task_time, item.optString("time").replace(":", "."))
        val tint = if (isDone) R.color.agenda_widget_muted else R.color.agenda_widget_ink
        row.setTextColor(R.id.task_title, context.getColor(tint))
        val strike = if (isDone) Paint.STRIKE_THRU_TEXT_FLAG else 0
        row.setInt(R.id.task_title, "setPaintFlags", Paint.ANTI_ALIAS_FLAG or strike)
        row.setImageViewResource(
            R.id.task_check,
            if (isDone) R.drawable.widget_check_on else R.drawable.widget_check_off,
        )
        row.setContentDescription(
            R.id.task_check,
            context.getString(if (isDone) R.string.widget_uncheck_task else R.string.widget_check_task, title),
        )

        val taskId = item.optString("id")
        val toggleFill = Intent().apply {
            putExtra(
                TaskWidgetActionActivity.EXTRA_ACTION,
                TaskWidgetActionActivity.ACTION_TOGGLE,
            )
            putExtra(TaskToggleReceiver.EXTRA_TASK_ID, taskId)
            putExtra(TaskToggleReceiver.EXTRA_DONE, !isDone)
        }
        row.setOnClickFillInIntent(R.id.task_check, toggleFill)

        val openFill = Intent().apply {
            putExtra(
                TaskWidgetActionActivity.EXTRA_ACTION,
                TaskWidgetActionActivity.ACTION_OPEN,
            )
            val uri = Uri.Builder().scheme("ohmyesok").authority("task").appendPath(taskId).build()
            putExtra(TaskWidgetActionActivity.EXTRA_URI, uri.toString())
        }
        row.setOnClickFillInIntent(R.id.task_body, openFill)
        row.setOnClickFillInIntent(R.id.task_row, openFill)

        return row
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = false

    override fun onDestroy() {}
}

package com.habib.jadwal

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService

class TaskWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        TaskWidgetFactory(applicationContext)
}

private class TaskWidgetFactory(
    private val context: Context,
) : RemoteViewsService.RemoteViewsFactory {
    @Volatile private var agenda = TaskWidgetProvider.agenda(context)

    override fun onCreate() {}

    override fun onDataSetChanged() {
        agenda = TaskWidgetProvider.agenda(context)
    }

    override fun getCount(): Int = agenda.tasks.size

    override fun getViewAt(position: Int): RemoteViews {
        val row = RemoteViews(context.packageName, R.layout.task_widget_item)
        val snapshot = agenda
        val item = snapshot.tasks.getOrNull(position) ?: return row
        val done = item.optBoolean("done")
        val title = item.optString("title")
        row.setTextViewText(R.id.task_title, title)
        row.setTextViewText(R.id.task_done_title, TaskWidgetProvider.doneLabel(title))
        row.setDisplayedChild(R.id.task_titles, if (done) 1 else 0)
        row.setTextViewText(R.id.task_time, item.optString("time").replace(':', '.'))
        row.setImageViewResource(
            R.id.task_check,
            if (done) R.drawable.widget_check_on else R.drawable.widget_check_off,
        )
        row.setContentDescription(
            R.id.task_item,
            TaskWidgetProvider.taskDescription(context, item),
        )
        row.setOnClickFillInIntent(R.id.task_item, TaskWidgetProvider.toggleExtras(item, snapshot.date))
        return row
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long =
        agenda.tasks.getOrNull(position)?.optString("id")?.hashCode()?.toLong() ?: -1
    override fun hasStableIds(): Boolean = true
    override fun onDestroy() {}
}

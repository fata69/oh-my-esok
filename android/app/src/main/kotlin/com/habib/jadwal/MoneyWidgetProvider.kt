package com.habib.jadwal

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONObject
import java.text.NumberFormat
import java.util.Locale

abstract class MoneyWidgetProviderBase : AppWidgetProvider() {
    protected abstract val layoutId: Int

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (appWidgetId in appWidgetIds) {
            appWidgetManager.updateAppWidget(
                appWidgetId,
                buildMoneyWidgetViews(context, layoutId),
            )
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        appWidgetManager.updateAppWidget(
            appWidgetId,
            buildMoneyWidgetViews(context, layoutId),
        )
    }
}

class MoneyWidgetProvider : MoneyWidgetProviderBase() {
    override val layoutId: Int = R.layout.money_widget_square
}

class MoneyWidgetBarProvider : MoneyWidgetProviderBase() {
    override val layoutId: Int = R.layout.money_widget_bar
}

object MoneyWidgetRefresher {
    fun refreshAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        for ((provider, layoutId) in listOf(
            MoneyWidgetProvider::class.java to R.layout.money_widget_square,
            MoneyWidgetBarProvider::class.java to R.layout.money_widget_bar,
        )) {
            val ids = manager.getAppWidgetIds(
                android.content.ComponentName(context, provider),
            )
            for (id in ids) {
                manager.updateAppWidget(id, buildMoneyWidgetViews(context, layoutId))
            }
        }
    }
}

private fun buildMoneyWidgetViews(context: Context, layoutId: Int): RemoteViews {
    val views = RemoteViews(context.packageName, layoutId)
    val prefs = HomeWidgetPlugin.getData(context)
    val raw = prefs.getString("money_summary_json", "{}") ?: "{}"
    val json = try {
        JSONObject(raw)
    } catch (error: Exception) {
        JSONObject()
    }

    val masked = json.optBoolean("masked", false)
    val today = json.optLong("today", 0L)
    val month = json.optLong("month", 0L)
    val format = NumberFormat.getNumberInstance(Locale("id", "ID"))

    fun amount(value: Long): String =
        if (masked) "•••••" else "Rp ${format.format(value)}"

    views.setTextViewText(R.id.money_today, amount(today))
    views.setTextViewText(R.id.money_month, amount(month))

    val openApp = Intent(context, MainActivity::class.java).apply {
        data = Uri.parse("jadwal://money")
        action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
    }
    val openCatat = Intent(context, MainActivity::class.java).apply {
        data = Uri.parse("jadwal://money/new")
        action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
    }
    val rootPending = PendingIntent.getActivity(
        context,
        300 + layoutId,
        openApp,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
    val plusPending = PendingIntent.getActivity(
        context,
        310 + layoutId,
        openCatat,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
    views.setOnClickPendingIntent(R.id.money_root, rootPending)
    views.setOnClickPendingIntent(R.id.money_plus, plusPending)

    return views
}

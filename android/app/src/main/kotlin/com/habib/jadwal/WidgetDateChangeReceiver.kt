package com.habib.jadwal

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class WidgetDateChangeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED -> {
                TaskWidgetProvider.refreshAll(context)
                MoneyWidgetRefresher.refreshAll(context)
            }
        }
    }
}

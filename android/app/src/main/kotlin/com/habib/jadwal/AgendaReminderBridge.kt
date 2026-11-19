package com.habib.jadwal

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneId

/** App and widget share the same Android alarm identities and delivery guard. */
internal object AgendaReminders {
    private const val ALARM = "io.github.fata69.ohmyesok.AGENDA_REMINDER"
    private const val PREFS = "esok_agenda_reminders"
    private const val PLAN = "plan"
    private const val TAG_PREFIX = "agenda:"
    private const val KEY = "alarm_key"
    private const val WHEN = "alarm_time"
    private const val LEGACY_PREFS = "scheduled_notifications"

    private fun plan(context: Context) = readObject(
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(PLAN, null),
    )

    private fun save(context: Context, plan: JSONObject) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(PLAN, plan.toString()).apply()
    }

    private fun reminders(plan: JSONObject) = plan.keys().asSequence()
        .mapNotNull { key -> plan.optJSONObject(key)?.let { key to it } }

    private fun alarmKey(taskId: String, slot: Int) = "$slot:$taskId"

    private fun pendingIntentFor(context: Context, key: String, whenMillis: Long?, flags: Int): PendingIntent? {
        return PendingIntent.getBroadcast(
            context,
            0,
            Intent(context, AgendaReminderReceiver::class.java).apply {
                action = ALARM
                data = Uri.Builder().scheme("esok-reminder").authority("alarm")
                    .appendPath(key).build()
                putExtra(KEY, key)
                whenMillis?.let { putExtra(WHEN, it) }
            },
            flags or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun arm(context: Context, key: String, record: JSONObject) {
        val whenMillis = record.getLong("when")
        if (whenMillis <= System.currentTimeMillis()) return
        val intent = pendingIntentFor(context, key, whenMillis, PendingIntent.FLAG_UPDATE_CURRENT)
            ?: return
        val alarm = context.getSystemService(AlarmManager::class.java)
        try {
            alarm.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenMillis, intent)
        } catch (_: SecurityException) {
            alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenMillis, intent)
        }
    }

    private fun disarm(context: Context, key: String) {
        val intent = pendingIntentFor(context, key, null, PendingIntent.FLAG_NO_CREATE) ?: return
        context.getSystemService(AlarmManager::class.java).cancel(intent)
        intent.cancel()
    }

    private fun hide(context: Context, taskId: String) {
        val notifications = context.getSystemService(NotificationManager::class.java)
        notifications.cancel("$TAG_PREFIX$taskId", 1)
        notifications.cancel("$TAG_PREFIX$taskId", 2)
    }

    fun cancelTask(context: Context, taskId: String) {
        val plan = plan(context)
        for (slot in 1..2) {
            val key = alarmKey(taskId, slot)
            plan.remove(key)
            disarm(context, key)
        }
        save(context, plan)
        hide(context, taskId)
    }

    fun replace(context: Context, records: List<*>) {
        val previous = plan(context)
        val next = JSONObject()
        for (row in records.filterIsInstance<Map<*, *>>()) {
            val taskId = row["taskId"] as? String ?: continue
            val slot = row["slot"] as? Int ?: continue
            next.put(alarmKey(taskId, slot), JSONObject(row))
        }
        save(context, next)
        reminders(previous).forEach { (key, _) ->
            if (!next.has(key)) disarm(context, key)
        }
        val toggles = WidgetAgendaToggles.read(context)
        reminders(next).forEach { (key, record) ->
            val taskId = record.getString("taskId")
            if (toggles.done(taskId) ?: record.optBoolean("done")) {
                hide(context, taskId)
                disarm(context, key)
            } else {
                arm(context, key, record)
            }
        }
    }

    fun updateTask(context: Context, taskId: String, done: Boolean, rows: List<*>) {
        val plan = plan(context)
        for (slot in 1..2) {
            val key = alarmKey(taskId, slot)
            plan.remove(key)
            disarm(context, key)
        }
        for (row in rows.filterIsInstance<Map<*, *>>()) {
            val slot = row["slot"] as? Int ?: continue
            plan.put(alarmKey(taskId, slot), JSONObject(row))
        }
        save(context, plan)
        applyToggle(context, taskId, WidgetAgendaToggles.read(context).done(taskId) ?: done)
    }

    fun applyToggle(context: Context, taskId: String, done: Boolean) {
        val plan = plan(context)
        var changed = false
        for (slot in 1..2) {
            val key = alarmKey(taskId, slot)
            val record = plan.optJSONObject(key)
            if (record != null && record.optBoolean("done") != done) {
                record.put("done", done)
                changed = true
            }
            if (done) {
                disarm(context, key)
            } else {
                record?.let { arm(context, key, it) }
            }
        }
        if (changed) save(context, plan)
        if (done) hide(context, taskId)
    }

    fun clear(context: Context) {
        val plan = plan(context)
        save(context, JSONObject())
        reminders(plan).forEach { (key, _) -> disarm(context, key) }
        val notifications = context.getSystemService(NotificationManager::class.java)
        notifications.activeNotifications.filter { it.tag?.startsWith(TAG_PREFIX) == true }
            .forEach { notifications.cancel(it.tag, it.id) }
    }

    fun restoreAfterBoot(context: Context) {
        val toggles = WidgetAgendaToggles.read(context)
        reminders(plan(context)).forEach { (key, record) ->
            if (!(toggles.done(record.getString("taskId")) ?: record.optBoolean("done"))) {
                arm(context, key, record)
            }
        }
    }

    fun deliver(context: Context, intent: Intent) {
        if (intent.action != ALARM) return
        val key = intent.getStringExtra(KEY) ?: return
        val plan = plan(context)
        val record = plan.optJSONObject(key) ?: return
        if (intent.getLongExtra(WHEN, 0) != record.getLong("when")) return
        val taskId = record.getString("taskId")
        val day = record.getString("day")
        val time = record.getString("time")
        val queued = WidgetAgendaToggles.read(context).done(taskId)
        if (!canDeliver(context, taskId, day, time, queued)) return
        plan.remove(key)
        save(context, plan)

        val slot = record.getInt("slot")
        val title = record.getString("title")
        val body = record.getString("body")
        val openTask = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java).apply {
                action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
                data = Uri.Builder().scheme("ohmyesok").authority("task").appendPath(taskId).build()
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = NotificationCompat.Builder(context, record.getString("channel"))
            .setSmallIcon(R.drawable.ic_stat_esok)
            .setContentTitle(title)
            .setContentText(body)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(openTask)
            .setAutoCancel(true)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            builder.setSound(Uri.parse("android.resource://${context.packageName}/raw/${record.getString("sound")}"))
        }
        context.getSystemService(NotificationManager::class.java)
            .notify("$TAG_PREFIX$taskId", slot, builder.build())
    }

    /** The old Flutter receiver is gone. Preserve valid cached alarms on OTA
     * before the user first opens the new Flutter build. */
    fun migrateLegacySchedule(context: Context) {
        val prefs = context.getSharedPreferences(LEGACY_PREFS, Context.MODE_PRIVATE)
        val raw = prefs.getString(LEGACY_PREFS, null) ?: return
        val rows = try { JSONArray(raw) } catch (_: JSONException) { return }
        if (rows.length() == 0) return
        val now = System.currentTimeMillis()
        val plan = plan(context)
        val toggles = WidgetAgendaToggles.read(context)
        val notificationManager = context.getSystemService(NotificationManager::class.java)
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        val leadMinutes = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .all["flutter.lead_minutes"] as? Number ?: 60
        for (index in 0 until rows.length()) {
            val row = rows.optJSONObject(index) ?: continue
            val oldId = row.optInt("id", -1)
            if (oldId < 0) continue
            val oldIntent = PendingIntent.getBroadcast(
                context, oldId, Intent(context, ScheduledNotificationReceiver::class.java),
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
            )
            if (oldIntent != null) {
                alarmManager.cancel(oldIntent)
                oldIntent.cancel()
            }
            notificationManager.cancel(oldId)

            val taskId = row.optString("payload")
            val body = row.optString("body")
            val time = reminderTime.find(body)?.value?.replace('.', ':') ?: continue
            val localTime = runCatching { LocalDateTime.parse(row.getString("scheduledDateTime")) }
                .getOrNull() ?: continue
            val whenMillis = runCatching {
                localTime.atZone(ZoneId.of(row.getString("timeZoneName"))).toInstant().toEpochMilli()
            }.getOrNull() ?: continue
            if (taskId.isEmpty() || whenMillis <= now) continue
            val slot = if (body.startsWith("Pengingat awal")) 2 else 1
            val timeOfDay = runCatching { LocalTime.parse(time) }.getOrNull() ?: continue
            val regular = if (slot == 1) localTime else localTime.plusMinutes(leadMinutes.toLong())
            if (regular.toLocalTime() != timeOfDay) continue
            val day = regular.toLocalDate().toString()
            val key = alarmKey(taskId, slot)
            if (plan.has(key)) continue
            val queued = toggles.done(taskId)
            val eligible = canDeliver(context, taskId, day, time, queued)
            if (!eligible && !canDeliver(context, taskId, day, time, false)) continue
            plan.put(key, JSONObject().put("taskId", taskId).put("day", day).put("time", time)
                .put("title", row.optString("title")).put("body", body)
                .put("channel", row.optString("channelId", "esok_reminders_coin"))
                .put("sound", row.optString("sound", "coin")).put("slot", slot)
                .put("when", whenMillis).put("done", !eligible))
        }
        save(context, plan)
        prefs.edit().remove(LEGACY_PREFS).apply()
    }

    private val reminderTime = Regex("\\d{2}[.:]\\d{2}")

    private fun canDeliver(
        context: Context, taskId: String, day: String, time: String, queued: Boolean?,
    ): Boolean {
        if (queued == true) return false
        return SQLiteDatabase.openDatabase(
            context.getDatabasePath("esok.db").path,
            null,
            SQLiteDatabase.OPEN_READONLY or SQLiteDatabase.NO_LOCALIZED_COLLATORS,
        ).use { db ->
            val stored = db.rawQuery(
                "SELECT scheduled_date, scheduled_time, is_done, is_skipped, series_id FROM tasks WHERE id = ?",
                arrayOf(taskId),
            ).use rows@ { rows ->
                if (!rows.moveToFirst()) return@rows null
                ReminderTask(rows.getString(0), rows.getString(1), rows.getInt(2) != 0,
                    rows.getInt(3) != 0, rows.getString(4))
            }
            shouldDeliverReminder(taskId, day, time, queued, stored) { series ->
                db.rawQuery(
                    "SELECT scheduled_date, repeat_until, repeat_weekdays, scheduled_time FROM tasks " +
                        "WHERE (id = ? OR series_id = ?) AND id NOT LIKE 'occ:%' AND repeat_weekdays IS NOT NULL",
                    arrayOf(series, series),
                ).use { rules ->
                    buildList {
                        while (rules.moveToNext()) {
                            add(ReminderRule(rules.getString(0), rules.getString(1), rules.getString(2), rules.getString(3)))
                        }
                    }
                }
            }
        }
    }
}

class AgendaReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            if (intent.action == Intent.ACTION_BOOT_COMPLETED || intent.action == Intent.ACTION_MY_PACKAGE_REPLACED ||
                intent.action == "android.intent.action.QUICKBOOT_POWERON" ||
                intent.action == "com.htc.intent.action.QUICKBOOT_POWERON") {
                try {
                    AgendaReminders.migrateLegacySchedule(context)
                } finally {
                    AgendaReminders.restoreAfterBoot(context)
                }
            } else {
                AgendaReminders.deliver(context, intent)
            }
        } catch (error: Exception) {
            Log.w("EsokReminders", "Agenda reminder could not be delivered or restored", error)
        }
    }
}

internal class AgendaReminderBridge(context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "esok/agenda-reminders")

    init {
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "replace" -> AgendaReminders.replace(context, call.arguments as List<*>)
                    "updateTask" -> AgendaReminders.updateTask(
                        context,
                        call.argument<String>("taskId")!!,
                        call.argument<Boolean>("done")!!,
                        call.argument<List<*>>("records")!!,
                    )
                    "cancel" -> AgendaReminders.cancelTask(context, call.arguments as String)
                    "clear" -> AgendaReminders.clear(context)
                    "readWidgetToggles" -> {
                        result.success(WidgetAgendaToggles.read(context).snapshot())
                        return@setMethodCallHandler
                    }
                    "ackWidgetToggles" -> WidgetAgendaToggles.acknowledge(context, call.arguments as Map<*, *>)
                    else -> {
                        result.notImplemented()
                        return@setMethodCallHandler
                    }
                }
                result.success(null)
            } catch (error: Exception) {
                result.error("agenda_reminder_failed", "Jadwal pengingat belum bisa diperbarui.", null)
                Log.w("EsokReminders", "Agenda reminder operation failed", error)
            }
        }
    }

    fun dispose() = channel.setMethodCallHandler(null)
}

internal fun readObject(raw: String?) = try {
    JSONObject(raw ?: "{}")
} catch (_: JSONException) {
    JSONObject()
}

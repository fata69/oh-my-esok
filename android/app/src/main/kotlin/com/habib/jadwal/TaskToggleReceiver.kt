package com.habib.jadwal

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.media.MediaPlayer
import android.util.Log
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONException
import org.json.JSONObject
import java.io.File
import java.time.LocalDate

class TaskToggleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_TOGGLE) return
        val taskId = intent.getStringExtra(EXTRA_TASK_ID) ?: return
        val today = LocalDate.now().toString()
        val tappedDay = intent.getStringExtra(EXTRA_TASK_DAY)
        if (tappedDay != null && tappedDay != today) {
            TaskWidgetProvider.refreshAll(context)
            return
        }
        if (!intent.hasExtra(EXTRA_DONE)) return
        val newDone = intent.getBooleanExtra(EXTRA_DONE, false)

        val prefs = HomeWidgetPlugin.getData(context)
        val raw = prefs.getString("tasks_json", "{}") ?: "{}"
        val snapshot = try {
            JSONObject(raw)
        } catch (_: JSONException) {
            return
        }
        val day = snapshot.optJSONObject(today) ?: return
        val items = day.optJSONArray("tasks") ?: return
        val tasks = (0 until items.length()).mapNotNull { items.optJSONObject(it) }
        val task = tasks.firstOrNull { it.optString("id") == taskId } ?: return
        val pending = WidgetAgendaToggles.read(context)
        val previousDone = pending.done(taskId) ?: task.optBoolean("done")
        if (previousDone == newDone) return

        pending.put(taskId, newDone)
        for (item in tasks) {
            val queued = pending.done(item.optString("id")) ?: continue
            item.put("done", queued)
        }
        val doneCount = tasks.count { it.optBoolean("done") }
        day.put("done", doneCount)
        day.put("total", tasks.size)

        pending.save(prefs.edit().putString("tasks_json", snapshot.toString()))
        try {
            AgendaReminders.applyToggle(context, taskId, newDone)
        } catch (error: Exception) {
            // Delivery also checks the persisted queue if cancelling fails.
            Log.w("EsokReminders", "Could not apply widget completion to Android alarms", error)
        }

        TaskWidgetProvider.refreshAll(context)
        playToggleSound(context, newDone, newDone && doneCount == tasks.size)
    }

    /**
     * Bunyi dimainkan di sini, bukan di Dart, supaya tetap terdengar saat
     * aplikasi sedang tidak terbuka. Sumber utama adalah SharedPreferences
     * Flutter agar pilihan terbaru langsung terpakai; data widget hanya
     * cadangan untuk versi lama.
     */
    private fun playToggleSound(
        context: Context,
        done: Boolean,
        completedAll: Boolean,
    ) {
        val widgetPrefs = HomeWidgetPlugin.getData(context)
        val appPrefs = context.getSharedPreferences(
            "FlutterSharedPreferences",
            Context.MODE_PRIVATE,
        )
        val enabled = appPrefs.getBoolean(
            "flutter.sound_enabled",
            widgetPrefs.getBoolean("sound_enabled", true),
        )
        if (!enabled) return

        val audio = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        if (audio?.ringerMode == AudioManager.RINGER_MODE_SILENT) return

        val suffix = when {
            completedAll -> "complete"
            done -> "check"
            else -> "uncheck"
        }
        val idKey = when (suffix) {
            "complete" -> "flutter.sound_complete_id"
            "check" -> "flutter.sound_check_id"
            else -> "flutter.sound_uncheck_id"
        }
        var selectedId = appPrefs.getString(idKey, null)
        if (selectedId == null && suffix == "check") {
            selectedId = appPrefs.getString("flutter.sound_done_id", null)
        }

        var rawName = ""
        var filePath = ""
        if (selectedId != null) {
            when {
                selectedId == "none" -> return
                selectedId.startsWith("file:") -> {
                    filePath = selectedId.removePrefix("file:").trim()
                }
                selectedId.startsWith("asset:") -> {
                    rawName = selectedId.removePrefix("asset:")
                        .substringAfterLast('/')
                        .substringBeforeLast('.')
                        .trim()
                }
            }
        }

        if (rawName.isEmpty() && filePath.isEmpty()) {
            rawName = widgetPrefs.getString("sound_${suffix}_raw", null)
                ?.trim()
                .orEmpty()
            filePath = widgetPrefs.getString("sound_${suffix}_file", null)
                ?.trim()
                .orEmpty()
        }
        if (rawName.isEmpty() && filePath.isEmpty()) {
            rawName = when (suffix) {
                "complete" -> "coin"
                "check" -> "chime"
                else -> "pop"
            }
        }

        if (filePath.isNotEmpty() && !File(filePath).isFile) {
            filePath = ""
        }
        if (rawName.isEmpty() && filePath.isEmpty()) return

        try {
            player?.release()
            player = null

            val created = if (filePath.isNotEmpty()) {
                MediaPlayer().apply {
                    setDataSource(filePath)
                    prepare()
                }
            } else {
                val resId = context.resources.getIdentifier(
                    rawName,
                    "raw",
                    context.packageName,
                )
                if (resId == 0) return
                MediaPlayer.create(context, resId)
            } ?: return

            player = created
            created.setOnCompletionListener {
                it.release()
                if (player === it) player = null
            }
            created.start()
        } catch (error: Exception) {
            player?.release()
            player = null
        }
    }

    companion object {
        const val ACTION_TOGGLE = "io.github.fata69.ohmyesok.ACTION_TOGGLE"
        const val EXTRA_TASK_ID = "task_id"
        const val EXTRA_TASK_DAY = "task_day"
        const val EXTRA_DONE = "done"
        private var player: MediaPlayer? = null
    }
}

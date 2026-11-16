package com.habib.jadwal

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.media.MediaPlayer
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

class TaskToggleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_TOGGLE) return
        val taskId = intent.getStringExtra(EXTRA_TASK_ID) ?: return
        val newDone = intent.getBooleanExtra(EXTRA_DONE, false)

        val prefs = HomeWidgetPlugin.getData(context)
        val raw = prefs.getString("tasks_json", "{}") ?: "{}"
        val serialized: String = if (raw.trimStart().startsWith("[")) {
            val items = try {
                JSONArray(raw)
            } catch (error: Exception) {
                JSONArray()
            }
            for (index in 0 until items.length()) {
                val item = items.optJSONObject(index) ?: continue
                if (item.optString("id") == taskId) {
                    item.put("done", newDone)
                }
            }
            items.toString()
        } else {
            val root = try {
                JSONObject(raw)
            } catch (error: Exception) {
                JSONObject()
            }
            for (key in root.keys()) {
                val day = root.optJSONObject(key) ?: continue
                val items = day.optJSONArray("tasks") ?: continue
                var changed = false
                for (index in 0 until items.length()) {
                    val item = items.optJSONObject(index) ?: continue
                    if (item.optString("id") == taskId) {
                        item.put("done", newDone)
                        changed = true
                    }
                }
                if (changed) {
                    var doneCount = 0
                    for (index in 0 until items.length()) {
                        if (items.optJSONObject(index)?.optBoolean("done", false) == true) {
                            doneCount++
                        }
                    }
                    day.put("done", doneCount)
                    day.put("total", items.length())
                }
            }
            root.toString()
        }

        val pendingRaw = prefs.getString("pending_toggles", "{}") ?: "{}"
        val pending = try {
            JSONObject(pendingRaw)
        } catch (error: Exception) {
            JSONObject()
        }
        pending.put(taskId, newDone)

        prefs.edit()
            .putString("tasks_json", serialized)
            .putString("pending_toggles", pending.toString())
            .apply()

        TaskWidgetProvider.refreshAll(context)
        playToggleSound(context, newDone)
    }

    /**
     * Bunyi dimainkan di sini, bukan di Dart, supaya tetap terdengar saat
     * aplikasi sedang tidak terbuka. Sumber utama adalah SharedPreferences
     * Flutter agar pilihan terbaru langsung terpakai; data widget hanya
     * cadangan untuk versi lama.
     */
    private fun playToggleSound(context: Context, done: Boolean) {
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

        val suffix = if (done) "check" else "uncheck"
        val selectedId = appPrefs.getString(
            if (done) "flutter.sound_check_id" else "flutter.sound_uncheck_id",
            null,
        ) ?: if (done) appPrefs.getString("flutter.sound_done_id", null) else null

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
            rawName = if (done) "chime" else "pop"
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
        const val ACTION_TOGGLE = "com.habib.jadwal.ACTION_TOGGLE"
        const val EXTRA_TASK_ID = "task_id"
        const val EXTRA_DONE = "done"
        private var player: MediaPlayer? = null
    }
}

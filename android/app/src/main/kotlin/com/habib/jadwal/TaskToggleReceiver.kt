package com.habib.jadwal

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.media.MediaPlayer
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject

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
     * aplikasi sedang tidak terbuka. Konfigurasi nada dikirim oleh WidgetSync.
     */
    private fun playToggleSound(context: Context, done: Boolean) {
        val prefs = HomeWidgetPlugin.getData(context)
        if (!prefs.getBoolean("sound_enabled", true)) return

        val audio = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        if (audio?.ringerMode == AudioManager.RINGER_MODE_SILENT) return

        val key = if (done) "sound_check_raw" else "sound_uncheck_raw"
        val name = prefs.getString(key, null)?.takeIf { it.isNotEmpty() } ?: return
        val resId = context.resources.getIdentifier(name, "raw", context.packageName)
        if (resId == 0) return

        try {
            player?.release()
            val created = MediaPlayer.create(context, resId) ?: return
            player = created
            created.setOnCompletionListener {
                it.release()
                if (player === it) player = null
            }
            created.start()
        } catch (error: Exception) {
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

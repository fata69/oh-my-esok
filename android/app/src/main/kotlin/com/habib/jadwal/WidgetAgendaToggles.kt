package com.habib.jadwal

import android.content.Context
import android.content.SharedPreferences
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONObject
import java.util.UUID

/** The home widget owns writes. Flutter removes only the exact entries it applied. */
internal class WidgetAgendaToggles private constructor(private val prefs: SharedPreferences) {
    private val values = readObject(prefs.getString(VALUES, null))
    private val versions = readObject(prefs.getString(VERSIONS, null))

    fun done(id: String) = values.opt(id) as? Boolean

    private fun token(id: String) = versions.opt(id) as? String

    fun put(id: String, done: Boolean) {
        values.put(id, done)
        versions.put(id, UUID.randomUUID().toString())
    }

    fun save(editor: SharedPreferences.Editor = prefs.edit()) {
        editor.putString(VALUES, values.toString())
            .putString(VERSIONS, versions.toString()).apply()
    }

    fun snapshot(): Map<String, Map<String, Any?>> = values.keys().asSequence()
        .mapNotNull { id -> done(id)?.let { id to mapOf("done" to it, "token" to token(id)) } }.toMap()

    companion object {
        private const val VALUES = "pending_toggles"
        private const val VERSIONS = "pending_toggle_versions"

        fun read(context: Context) = WidgetAgendaToggles(HomeWidgetPlugin.getData(context))

        fun acknowledge(context: Context, acknowledged: Map<*, *>) {
            val queue = read(context)
            for ((key, value) in acknowledged) {
                val id = key as? String ?: continue
                val row = value as? Map<*, *> ?: continue
                val done = row["done"] as? Boolean ?: continue
                if (queue.done(id) == done && queue.token(id) == row["token"]) {
                    queue.values.remove(id)
                    queue.versions.remove(id)
                }
            }
            queue.save()
        }
    }
}

package com.habib.jadwal

import java.time.LocalDate

internal data class ReminderTask(
    val day: String,
    val time: String?,
    val done: Boolean,
    val skipped: Boolean,
    val series: String?,
)

internal data class ReminderRule(
    val starts: String,
    val ends: String?,
    val weekdays: String,
    val time: String?,
) {
    fun covers(day: String) = day >= starts && (ends == null || day < ends)
}

private val occurrenceId = Regex("^occ:(.+):(\\d{4}-\\d{2}-\\d{2})$")

internal fun shouldDeliverReminder(
    taskId: String,
    day: String,
    time: String,
    queuedDone: Boolean?,
    stored: ReminderTask?,
    rulesFor: (String) -> List<ReminderRule>,
): Boolean {
    if (queuedDone == true) return false
    if (stored != null) {
        if (stored.skipped || (queuedDone ?: stored.done) || stored.day != day || stored.time != time) {
            return false
        }
        if (stored.series == null) return true
    }

    val occurrence = occurrenceId.matchEntire(taskId) ?: return false
    val (series, originalDay) = occurrence.destructured
    if (stored == null && originalDay != day) return false
    val weekday = LocalDate.parse(originalDay).dayOfWeek.value.toString()
    val rules = rulesFor(series)
    val showsOriginal = rules.any { rule ->
        rule.covers(originalDay) && weekday in rule.weekdays.split(',') &&
            (stored != null || rule.time == time)
    }
    return showsOriginal && rules.any { it.covers(day) }
}

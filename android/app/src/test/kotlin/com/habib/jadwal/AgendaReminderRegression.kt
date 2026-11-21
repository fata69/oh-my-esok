package com.habib.jadwal

fun main() {
    val monday = "2026-11-23"
    val tuesday = "2026-11-24"
    val time = "08:00"
    val weekdays = ReminderRule(monday, null, "1,2,3,4,5", time)
    val notDone = ReminderTask(monday, time, false, false, null)
    val done = notDone.copy(done = true)
    val recurringDone = done.copy(series = "absen")

    fun delivers(
        id: String, day: String, stored: ReminderTask?, widgetDone: Boolean? = null,
        rules: List<ReminderRule> = listOf(weekdays),
    ) = shouldDeliverReminder(id, day, time, widgetDone, stored) { rules }

    check(delivers("one-off", monday, notDone))
    check(!delivers("one-off", monday, done))
    check(!delivers("one-off", monday, notDone, true))
    check(delivers("one-off", monday, done, false))
    check(!delivers("one-off", monday, null))
    check(!delivers("one-off", monday, notDone.copy(time = "10:00")))
    check(!delivers("one-off", monday, notDone.copy(skipped = true), false))

    val absenMonday = "occ:absen:$monday"
    val absenTuesday = "occ:absen:$tuesday"
    check(!delivers(absenMonday, monday, recurringDone))
    check(!delivers(absenMonday, monday, null, true))
    check(delivers(absenMonday, monday, recurringDone, false))
    check(delivers(absenTuesday, tuesday, null))
    check(!delivers(absenTuesday, tuesday, null, rules = emptyList()))
    check(!delivers(absenTuesday, tuesday, null, rules = listOf(weekdays.copy(ends = tuesday))))
    check(!delivers(absenTuesday, tuesday, null, rules = listOf(weekdays.copy(time = "09:00"))))
    println("Agenda reminder eligibility cases passed")
}

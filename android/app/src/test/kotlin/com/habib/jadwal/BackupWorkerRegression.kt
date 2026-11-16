package com.habib.jadwal

import java.io.IOException
import java.util.concurrent.LinkedBlockingQueue

/** Standalone JVM regression: no Android runtime, device, emulator, or Gradle. */
fun main() {
    val cases = listOf(
        IllegalArgumentException("Volume external_primary not found") to "storage_unavailable",
        SecurityException("private provider detail") to "storage_permission",
        IOException("private file content") to "backup_failed",
        IllegalStateException("provider process failed") to "backup_failed",
        BackupOperationException("read_failed", "Berkas cadangan tidak dapat dibaca.") to "read_failed",
    )
    val caller = Thread.currentThread()
    for ((failure, expectedCode) in cases) {
        val posted = LinkedBlockingQueue<() -> Unit>()
        val replies = mutableListOf<BackupOutcome>()
        var worker: Thread? = null
        var uncaught: Throwable? = null
        BackupWorker.dispatch(
            operation = { throw failure },
            post = { posted.add(it) },
            reply = {
                check(Thread.currentThread() === caller)
                replies.add(it)
            },
            launch = { action ->
                worker = Thread(action).apply {
                    uncaughtExceptionHandler = Thread.UncaughtExceptionHandler { _, error ->
                        uncaught = error
                    }
                    start()
                }
            },
        )
        worker!!.join()
        check(uncaught == null) { "Provider error escaped the worker thread" }
        check(replies.isEmpty()) { "Result was delivered on the worker thread" }
        check(posted.size == 1)
        posted.remove().invoke()
        val reply = replies.single() as BackupOutcome.Failure
        check(reply.code == expectedCode)
        check(!reply.message.contains("private"))
        check(!reply.message.contains("external_primary"))
    }
    for (value in listOf(null, true, "synthetic JSON", 123L)) {
        val replies = mutableListOf<BackupOutcome>()
        BackupWorker.dispatch(
            operation = { value },
            post = { it() },
            reply = { replies.add(it) },
            launch = { it() },
        )
        check((replies.single() as BackupOutcome.Success).value == value)
    }
    val replies = mutableListOf<BackupOutcome>()
    BackupWorker.dispatch(
        operation = { error("Must not execute after thread start failure") },
        post = { error("Must not post after thread start failure") },
        reply = { replies.add(it) },
        launch = { throw SecurityException("cannot start thread") },
    )
    check((replies.single() as BackupOutcome.Failure).code == "storage_permission")
    println("PASS: 5 worker failures, 4 success values, 1 thread-start failure")
}

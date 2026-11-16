package com.habib.jadwal

internal class BackupOperationException(val code: String, message: String) : Exception(message)

internal sealed class BackupOutcome {
    data class Success(val value: Any?) : BackupOutcome()
    data class Failure(val code: String, val message: String) : BackupOutcome()
}

/** Keeps provider/IO errors out of uncaught background-thread exceptions. */
internal object BackupWorker {
    fun dispatch(
        operation: () -> Any?,
        post: (() -> Unit) -> Unit,
        reply: (BackupOutcome) -> Unit,
        launch: (() -> Unit) -> Unit = { action -> Thread(action, "EsokBackup").start() },
    ) {
        try {
            launch {
                val outcome = try {
                    BackupOutcome.Success(operation())
                } catch (error: Exception) {
                    failure(error)
                }
                post { reply(outcome) }
            }
        } catch (error: Exception) {
            // Thread creation can fail too; this call is already on the UI thread.
            reply(failure(error))
        }
    }

    private fun failure(error: Exception): BackupOutcome.Failure = when (error) {
        is BackupOperationException -> BackupOutcome.Failure(error.code, error.message!!)
        is SecurityException -> BackupOutcome.Failure(
            "storage_permission",
            "Akses berkas cadangan ditolak. Periksa izin atau pilih impor berkas.",
        )
        is IllegalArgumentException -> BackupOutcome.Failure(
            "storage_unavailable",
            "Penyimpanan unduhan belum tersedia. Coba lagi nanti.",
        )
        else -> BackupOutcome.Failure(
            "backup_failed",
            "Operasi cadangan gagal. Periksa penyimpanan lalu coba lagi.",
        )
    }
}

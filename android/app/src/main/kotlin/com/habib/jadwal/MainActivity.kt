package com.habib.jadwal

import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var receiptInbox: ReceiptInboxBridge? = null
    private var agendaReminders: AgendaReminderBridge? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // A completed import lives on disk across Activity and process recreation.
        if (savedInstanceState == null) receiptInbox?.accept(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        receiptInbox?.accept(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        UpdateBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        receiptInbox = ReceiptInboxBridge(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        agendaReminders = AgendaReminderBridge(applicationContext, flutterEngine.dartExecutor.binaryMessenger)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "esok/settings",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openBatterySettings" -> {
                    try {
                        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            Intent(
                                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                Uri.parse("package:$packageName"),
                            )
                        } else {
                            Intent(Settings.ACTION_SETTINGS)
                        }
                        startActivity(intent)
                        result.success(null)
                    } catch (error: Exception) {
                        try {
                            startActivity(
                                Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
                            )
                            result.success(null)
                        } catch (fallback: Exception) {
                            result.error("unavailable", fallback.message, null)
                        }
                    }
                }

                "openExactAlarmSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            startActivity(
                                Intent(
                                    Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                                    Uri.parse("package:$packageName"),
                                ),
                            )
                        } else {
                            startActivity(Intent(Settings.ACTION_SETTINGS))
                        }
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("unavailable", error.message, null)
                    }
                }

                "writeBackup" -> {
                    val arguments = call.arguments as? Map<*, *>
                    val name = arguments?.get("name") as? String
                    val content = arguments?.get("content") as? String
                    if (name == null || content == null) {
                        result.error("invalid", "name dan content wajib", null)
                        return@setMethodCallHandler
                    }
                    runBackupOperation(result) {
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                            throw BackupOperationException(
                                "unsupported_sdk",
                                "Cadangan otomatis butuh Android 10 atau lebih baru.",
                            )
                        }
                        writeBackup(name, content)
                        true
                    }
                }

                "readBackup" -> {
                    val name = (call.arguments as? Map<*, *>)?.get("name") as? String
                    if (name == null) {
                        result.error("invalid", "name wajib", null)
                        return@setMethodCallHandler
                    }
                    runBackupOperation(result) { readBackup(name) }
                }

                "backupModifiedAt" -> {
                    val name = (call.arguments as? Map<*, *>)?.get("name") as? String
                    if (name == null) {
                        result.error("invalid", "name wajib", null)
                        return@setMethodCallHandler
                    }
                    runBackupOperation(result) { backupModifiedAt(name) }
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        receiptInbox?.dispose()
        receiptInbox = null
        agendaReminders?.dispose()
        agendaReminders = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private val backupFolder = "Oh My Esok"

    private fun runBackupOperation(result: MethodChannel.Result, operation: () -> Any?) {
        BackupWorker.dispatch(
            operation = operation,
            post = { action -> runOnUiThread(action) },
            reply = { outcome ->
                when (outcome) {
                    is BackupOutcome.Success -> result.success(outcome.value)
                    is BackupOutcome.Failure ->
                        result.error(outcome.code, outcome.message, null)
                }
            },
        )
    }

    private fun collection(): Uri? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        if (Environment.getExternalStorageState() != Environment.MEDIA_MOUNTED ||
            MediaStore.VOLUME_EXTERNAL_PRIMARY !in MediaStore.getExternalVolumeNames(this)) {
            throw BackupOperationException(
                "storage_unavailable",
                "Penyimpanan unduhan belum tersedia. Coba cadangkan lagi nanti.",
            )
        }
        return MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
    }

    private fun findBackupUri(name: String): Uri? {
        val downloads = collection() ?: return null
        val projection = arrayOf(MediaStore.MediaColumns._ID)
        val selection =
            "${MediaStore.MediaColumns.DISPLAY_NAME}=? AND " +
                "${MediaStore.MediaColumns.RELATIVE_PATH}=?"
        val args = arrayOf(
            name,
            "${Environment.DIRECTORY_DOWNLOADS}/$backupFolder/",
        )
        val cursor = contentResolver.query(downloads, projection, selection, args, null)
            ?: throw BackupOperationException(
                "provider_unavailable",
                "Penyedia berkas cadangan tidak dapat dibaca. Coba lagi nanti.",
            )
        cursor.use {
            if (cursor.moveToFirst()) {
                return ContentUris.withAppendedId(downloads, cursor.getLong(0))
            }
        }
        return null
    }

    private fun writeBackup(name: String, content: String) {
        val downloads = collection() ?: throw BackupOperationException(
            "unsupported_sdk",
            "Cadangan otomatis butuh Android 10 atau lebih baru.",
        )
        // A failed query must propagate; only an actually empty cursor means
        // no previous backup exists and allows inserting a new row.
        val uri = findBackupUri(name) ?: run {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                put(MediaStore.MediaColumns.MIME_TYPE, "application/json")
                put(
                    MediaStore.MediaColumns.RELATIVE_PATH,
                    "${Environment.DIRECTORY_DOWNLOADS}/$backupFolder",
                )
            }
            contentResolver.insert(downloads, values) ?: throw BackupOperationException(
                "write_failed",
                "Berkas cadangan tidak dapat dibuat.",
            )
        }
        val stream = contentResolver.openOutputStream(uri, "wt")
            ?: throw BackupOperationException("write_failed", "Berkas cadangan tidak dapat ditulis.")
        stream.use {
            it.write(content.toByteArray(Charsets.UTF_8))
        }
        if (backupModifiedAt(name) == null) {
            throw BackupOperationException(
                "write_failed",
                "Berkas cadangan tidak ditemukan setelah ditulis.",
            )
        }
    }

    private fun readBackup(name: String): String? {
        val uri = findBackupUri(name) ?: return null
        val stream = contentResolver.openInputStream(uri)
            ?: throw BackupOperationException("read_failed", "Berkas cadangan tidak dapat dibaca.")
        return stream.bufferedReader().use { it.readText() }
    }

    private fun backupModifiedAt(name: String): Long? {
        val uri = findBackupUri(name) ?: return null
        val projection = arrayOf(MediaStore.MediaColumns.DATE_MODIFIED)
        val cursor = contentResolver.query(uri, projection, null, null, null)
            ?: throw BackupOperationException(
                "provider_unavailable",
                "Informasi berkas cadangan tidak dapat dibaca.",
            )
        cursor.use {
            if (!cursor.moveToFirst() || cursor.isNull(0)) {
                throw BackupOperationException(
                    "read_failed",
                    "Informasi berkas cadangan tidak lengkap. Coba lagi nanti.",
                )
            }
            return cursor.getLong(0) * 1000L
        }
    }
}

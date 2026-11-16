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
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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
                    val name = call.argument<String>("name")
                    val content = call.argument<String>("content")
                    if (name == null || content == null) {
                        result.error("invalid", "name dan content wajib", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        val ok = writeBackup(name, content)
                        runOnUiThread { result.success(ok) }
                    }.start()
                }

                "readBackup" -> {
                    val name = call.argument<String>("name")
                    if (name == null) {
                        result.error("invalid", "name wajib", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        val content = readBackup(name)
                        runOnUiThread { result.success(content) }
                    }.start()
                }

                "backupModifiedAt" -> {
                    val name = call.argument<String>("name")
                    Thread {
                        val value = if (name == null) null else backupModifiedAt(name)
                        runOnUiThread { result.success(value) }
                    }.start()
                }

                else -> result.notImplemented()
            }
        }
    }

    private val backupFolder = "Esok"

    private fun collection(): Uri? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
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
        contentResolver.query(downloads, projection, selection, args, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                return ContentUris.withAppendedId(downloads, cursor.getLong(0))
            }
        }
        return null
    }

    private fun writeBackup(name: String, content: String): Boolean {
        val downloads = collection() ?: return false
        val uri = findBackupUri(name) ?: run {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                put(MediaStore.MediaColumns.MIME_TYPE, "application/json")
                put(
                    MediaStore.MediaColumns.RELATIVE_PATH,
                    "${Environment.DIRECTORY_DOWNLOADS}/$backupFolder",
                )
            }
            contentResolver.insert(downloads, values) ?: return false
        }
        return try {
            contentResolver.openOutputStream(uri, "wt")?.use {
                it.write(content.toByteArray(Charsets.UTF_8))
            }
            true
        } catch (error: Exception) {
            false
        }
    }

    private fun readBackup(name: String): String? {
        val uri = findBackupUri(name) ?: return null
        return try {
            contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() }
        } catch (error: Exception) {
            null
        }
    }

    private fun backupModifiedAt(name: String): Long? {
        val uri = findBackupUri(name) ?: return null
        val projection = arrayOf(MediaStore.MediaColumns.DATE_MODIFIED)
        contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                return cursor.getLong(0) * 1000L
            }
        }
        return null
    }
}

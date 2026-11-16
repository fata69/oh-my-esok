package com.habib.jadwal

import android.app.Activity
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.lang.ref.WeakReference

class UpdateBridge(private val activity: Activity, messenger: BinaryMessenger) {
    companion object {
        private var currentActivity: WeakReference<Activity>? = null
        @Volatile private var pendingConfirmation: Intent? = null

        fun confirmWhenActive(confirmation: Intent): Boolean {
            pendingConfirmation = confirmation
            val owner = currentActivity?.get() ?: return false
            if (!owner.hasWindowFocus() || owner.isFinishing || owner.isDestroyed) return false
            owner.startActivity(confirmation)
            pendingConfirmation = null
            return true
        }
    }

    init {
        currentActivity = WeakReference(activity)
        MethodChannel(messenger, "ohmyesok/update").setMethodCallHandler { call, result ->
            when (call.method) {
                "canInstall" -> result.success(Build.VERSION.SDK_INT < 26 || activity.packageManager.canRequestPackageInstalls())
                "openSources" -> try {
                    activity.startActivity(if (Build.VERSION.SDK_INT >= 26) Intent(
                        Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                        Uri.parse("package:${activity.packageName}"),
                    ) else Intent(Settings.ACTION_SECURITY_SETTINGS))
                    result.success(null)
                } catch (_: Exception) {
                    result.error("settings", "Setelan pemasangan tidak tersedia.", null)
                }
                "installStatus" -> result.success(activity.getSharedPreferences("updates", 0).getString("status", null))
                "checkApk", "install" -> Thread {
                    try {
                        val apk = checkedFile(call)
                        val pending = pendingConfirmation
                        if (call.method == "install" && pending != null) {
                            activity.runOnUiThread {
                                try {
                                    require(confirmWhenActive(pending)) { "Buka aplikasi untuk melanjutkan pemasangan." }
                                    result.success(null)
                                } catch (_: Exception) {
                                    result.error("confirmation", "Konfirmasi Android tidak dapat dibuka. Coba lagi.", null)
                                }
                            }
                            return@Thread
                        }
                        if (call.method == "install") install(apk)
                        activity.runOnUiThread { result.success(null) }
                    } catch (error: Exception) {
                        activity.runOnUiThread { result.error("invalid_apk", error.message ?: "APK tidak dapat dipasang.", null) }
                    }
                }.start()
                else -> result.notImplemented()
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun checkedFile(call: MethodCall): File {
        val path = call.argument<String>("path") ?: error("Berkas pembaruan tidak ada.")
        val version = call.argument<Number>("versionCode")?.toLong() ?: error("Versi tidak ada.")
        val expectedSize = call.argument<Number>("sizeBytes")?.toLong() ?: error("Ukuran tidak ada.")
        val expectedHash = call.argument<String>("sha256") ?: error("Checksum tidak ada.")
        val file = File(path).canonicalFile
        val allowed = File(activity.cacheDir, "updates").canonicalFile
        require(file.parentFile == allowed && file.name == "update.apk" && file.isFile) { "Lokasi APK tidak sesuai." }
        require(file.length() == expectedSize && expectedSize in 1..(300L * 1024 * 1024)) { "Ukuran APK tidak sesuai." }
        val hash = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(64 * 1024)
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                hash.update(buffer, 0, read)
            }
        }
        require(hash.digest().joinToString("") { "%02x".format(it.toInt() and 0xff) } == expectedHash) { "Checksum APK tidak sesuai." }
        val manager = activity.packageManager
        val flags = if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES
        val candidate = manager.getPackageArchiveInfo(file.path, flags) ?: error("APK tidak terbaca oleh Android.")
        val installed = manager.getPackageInfo(activity.packageName, flags)
        require(activity.packageName == "io.github.fata69.ohmyesok" && candidate.packageName == activity.packageName) { "APK bukan Oh My Esok." }
        fun code(info: PackageInfo): Long = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
        require(code(candidate) == version && version > code(installed)) { "Versi APK bukan pembaruan yang lebih baru." }
        require((candidate.applicationInfo?.minSdkVersion ?: Int.MAX_VALUE) <= Build.VERSION.SDK_INT) { "Versi Android tidak didukung APK ini." }
        fun certificates(info: PackageInfo): Set<String> {
            val signatures = if (Build.VERSION.SDK_INT >= 28) info.signingInfo?.apkContentsSigners else info.signatures
            return signatures?.map { signature ->
                MessageDigest.getInstance("SHA-256").digest(signature.toByteArray()).joinToString("") { "%02x".format(it.toInt() and 0xff) }
            }?.toSet() ?: emptySet()
        }
        val current = certificates(installed)
        require(current.isNotEmpty() && current == certificates(candidate)) { "Penandatangan APK berbeda dari aplikasi terpasang." }
        return file
    }

    private fun install(file: File) {
        require(Build.VERSION.SDK_INT < 26 || activity.packageManager.canRequestPackageInstalls()) { "Izinkan pemasangan dari aplikasi ini di setelan Android." }
        val installer = activity.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
        params.setAppPackageName(activity.packageName)
        params.setSize(file.length())
        if (Build.VERSION.SDK_INT >= 31) params.setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_REQUIRED)
        val id = installer.createSession(params)
        try {
            installer.openSession(id).use { session ->
                file.inputStream().use { input -> session.openWrite("base.apk", 0, file.length()).use { output ->
                    input.copyTo(output)
                    session.fsync(output)
                } }
                val callback = Intent(activity, UpdateInstallReceiver::class.java)
                    .setAction("${activity.packageName}.UPDATE_STATUS")
                val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                    (if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0)
                val sender = PendingIntent.getBroadcast(activity, id, callback, flags)
                activity.getSharedPreferences("updates", 0).edit().putString("status", "pending").apply()
                session.commit(sender.intentSender)
            }
        } catch (error: Exception) {
            installer.abandonSession(id)
            throw error
        }
    }
}

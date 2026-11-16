package com.habib.jadwal

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build

class UpdateInstallReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val preferences = context.getSharedPreferences("updates", 0)
        when (intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                val confirmation = if (Build.VERSION.SDK_INT >= 33) {
                    intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)
                }
                try {
                    requireNotNull(confirmation)
                    if (!UpdateBridge.confirmWhenActive(confirmation)) {
                        preferences.edit().putString("status", "awaiting_user").apply()
                    }
                } catch (_: Exception) {
                    preferences.edit().putString("status", "failed").apply()
                }
            }
            PackageInstaller.STATUS_SUCCESS -> preferences.edit().putString("status", "success").apply()
            else -> preferences.edit().putString("status", "failed").apply()
        }
    }
}

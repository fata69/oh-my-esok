package com.habib.jadwal

import android.content.Context
import android.content.Intent
import android.content.res.AssetFileDescriptor
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import android.widget.Toast
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.util.UUID
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.ScheduledThreadPoolExecutor
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

internal class ReceiptInboxBridge(
    private val context: Context,
    messenger: BinaryMessenger,
) : EventChannel.StreamHandler {
    private val rpc = MethodChannel(messenger, "esok/receipt-inbox")
    private val events = EventChannel(messenger, "esok/receipt-inbox/changes")
    private val directory = File(context.filesDir, "receipt-inbox")
    private var sink: EventChannel.EventSink? = null
    private val emitChange: () -> Unit = { sink?.success(null) }

    init {
        listeners.add(emitChange)
        events.setStreamHandler(this)
        rpc.setMethodCallHandler { call, result ->
            when (call.method) {
                "pendingImages" -> result.success(images(directory).map(File::getAbsolutePath))
                "discard" -> {
                    val name = call.arguments as? String
                    if (name == null || !entryName.matches(name)) {
                        result.error("invalid_receipt", "Draf struk tidak valid.", null)
                    } else {
                        val file = File(directory, name)
                        if (!file.exists()) {
                            result.success(null)
                        } else if (file.delete()) {
                            result.success(null)
                            notifyChanged()
                        } else {
                            result.error("delete_failed", "Draf belum bisa dihapus.", null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    fun dispose() {
        listeners.remove(emitChange)
        sink = null
        events.setStreamHandler(null)
        rpc.setMethodCallHandler(null)
    }

    fun accept(intent: Intent?) {
        if (intent?.action != Intent.ACTION_SEND) return
        if (intent.type?.startsWith("image/", ignoreCase = true) != true) return
        val uri = try {
            imageUri(intent)
        } catch (_: RuntimeException) {
            null
        }
        val authority = uri?.authority?.substringAfter('@')
        if (uri?.scheme != "content" || authority.isNullOrEmpty() ||
            authority.equals(context.packageName, ignoreCase = true) ||
            authority.startsWith("${context.packageName}.", ignoreCase = true)) {
            showError("Foto struk tidak bisa dibuka. Pilih ulang dari Galeri.")
            return
        }

        try {
            copies.execute {
                try {
                    copyImage(uri)
                    main.post { notifyChanged() }
                } catch (error: InboxException) {
                    showError(error.message!!)
                } catch (_: Exception) {
                    showError("Foto struk tidak bisa dibuka. Pilih ulang dari Galeri.")
                }
            }
        } catch (_: RejectedExecutionException) {
            showError("Struk lain sedang disiapkan. Coba lagi sebentar.")
        }
    }

    @Suppress("DEPRECATION")
    private fun imageUri(intent: Intent): Uri? {
        val stream = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
        }
        val clip = intent.clipData
        return stream ?: if (clip?.itemCount == 1) clip.getItemAt(0).uri else null
    }

    private fun copyImage(uri: Uri) {
        if (!directory.isDirectory && !directory.mkdirs()) throw IOException()
        // A process killed before rename can leave an incomplete file.
        directory.listFiles()?.filter { partName.matches(it.name) }?.forEach(File::delete)
        if (images(directory).size >= maxPending) {
            throw InboxException("Kotak struk penuh. Selesaikan atau hapus draf yang ada.")
        }
        val name = "receipt-${UUID.randomUUID()}"
        val temporary = File(directory, "$name.part")
        val descriptor = AtomicReference<AssetFileDescriptor?>()
        val cancel = CancellationSignal()
        val timeout = timeouts.schedule({
            try {
                cancel.cancel()
            } finally {
                descriptor.get()?.close()
            }
        }, 12, TimeUnit.SECONDS)

        try {
            val source = context.contentResolver.openAssetFileDescriptor(uri, "r", cancel)
                ?: throw IOException()
            descriptor.set(source)
            source.use { input ->
                if (input.length > maxBytes) throw tooLarge()
                input.createInputStream().use { stream ->
                    temporary.outputStream().use { output ->
                        var written = 0L
                        val buffer = ByteArray(32 * 1024)
                        while (true) {
                            cancel.throwIfCanceled()
                            val count = stream.read(buffer)
                            if (count == -1) break
                            written += count
                            if (written > maxBytes) throw tooLarge()
                            output.write(buffer, 0, count)
                        }
                    }
                }
            }
            descriptor.set(null)
            cancel.throwIfCanceled()
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(temporary.absolutePath, bounds)
            if (bounds.outMimeType !in supportedImages || bounds.outWidth <= 0 ||
                bounds.outHeight <= 0 || bounds.outWidth.toLong() * bounds.outHeight > maxPixels) {
                throw InboxException("Gunakan foto JPG, PNG, atau WebP yang bisa dibuka.")
            }
            cancel.throwIfCanceled()
            if (!temporary.renameTo(File(directory, "$name.img"))) throw IOException()
        } finally {
            descriptor.set(null)
            timeout.cancel(false)
            temporary.delete()
        }
    }

    private fun tooLarge() = InboxException("Ukuran foto struk maksimal 12 MB.")

    private fun showError(message: String) {
        main.post { Toast.makeText(context, message, Toast.LENGTH_LONG).show() }
    }

    private class InboxException(message: String) : Exception(message)

    companion object {
        private const val maxPending = 4
        private const val maxBytes = 12L * 1024 * 1024
        private const val maxPixels = 32_000_000L
        private val supportedImages = setOf("image/jpeg", "image/png", "image/webp")
        private val entryName = Regex("receipt-[0-9a-f-]{36}\\.img")
        private val partName = Regex("receipt-[0-9a-f-]{36}\\.part")
        private val main = Handler(Looper.getMainLooper())
        private val listeners = mutableSetOf<() -> Unit>()
        private val copies = ThreadPoolExecutor(
            1, 1, 20, TimeUnit.SECONDS, ArrayBlockingQueue(2),
            { action -> Thread(action, "EsokReceiptCopy") },
        ).apply { allowCoreThreadTimeOut(true) }
        private val timeouts = ScheduledThreadPoolExecutor(1).apply {
            removeOnCancelPolicy = true
        }

        private fun images(directory: File): List<File> = directory.listFiles()
            ?.filter { it.isFile && entryName.matches(it.name) }
            ?.sortedWith(compareByDescending<File> { it.lastModified() }.thenBy { it.name })
            .orEmpty()

        private fun notifyChanged() = listeners.forEach { it() }
    }
}

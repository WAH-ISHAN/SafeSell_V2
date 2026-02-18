package com.safeshell

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbManager
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import android.content.ContentUris
import android.database.Cursor
import android.net.Uri
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL_PROTECTION = "com.safeshell/screen_protection"
    private val CHANNEL_MEDIA = "com.safeshell/media_store"
    private val CHANNEL_USB = "com.safeshell/usb_events"
    private val CHANNEL_INTENT = "com.safeshell/intent"

    private var usbEventSink: EventChannel.EventSink? = null
    private var usbReceiver: BroadcastReceiver? = null

    // Stores the ACTION_VIEW uri/mime from the launching intent until Flutter queries it.
    private var pendingViewUri: String? = null
    private var pendingViewMime: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        extractViewIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        extractViewIntent(intent)
    }

    private fun extractViewIntent(intent: Intent?) {
        if (intent?.action == Intent.ACTION_VIEW) {
            pendingViewUri = intent.data?.toString()
            pendingViewMime = intent.type
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Intent channel — lets Flutter check if the app was opened via ACTION_VIEW
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_INTENT).setMethodCallHandler { call, result ->
            when (call.method) {
                "getViewIntent" -> {
                    if (pendingViewUri != null) {
                        result.success(mapOf(
                            "uri" to pendingViewUri,
                            "mime" to pendingViewMime
                        ))
                        // Consume so it is not replayed on resume
                        pendingViewUri = null
                        pendingViewMime = null
                    } else {
                        result.success(null)
                    }
                }
                "readContentUri" -> {
                    val uri = call.argument<String>("uri")
                    if (uri == null) {
                        result.error("INVALID_URI", "URI cannot be null", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val parsedUri = Uri.parse(uri)
                        val bytes = contentResolver.openInputStream(parsedUri)?.use { it.readBytes() }
                        if (bytes != null) {
                            result.success(bytes)
                        } else {
                            result.error("READ_FAILED", "Could not read content URI", null)
                        }
                    } catch (e: Exception) {
                        result.error("READ_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_PROTECTION).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableSecure" -> {
                    window.setFlags(
                        WindowManager.LayoutParams.FLAG_SECURE,
                        WindowManager.LayoutParams.FLAG_SECURE
                    )
                    result.success(true)
                }
                "disableSecure" -> {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_MEDIA).setMethodCallHandler { call, result ->
             when (call.method) {
                "deleteFile" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        deleteFile(path, result)
                    } else {
                        result.error("INVALID_PATH", "Path cannot be null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // USB Events EventChannel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_USB).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    usbEventSink = events
                    registerUsbReceiver()
                }

                override fun onCancel(arguments: Any?) {
                    usbEventSink = null
                    unregisterUsbReceiver()
                }
            }
        )
    }

    private fun registerUsbReceiver() {
        if (usbReceiver != null) return
        usbReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
                        usbEventSink?.success(mapOf("type" to "usb_attached"))
                    }
                    UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                        usbEventSink?.success(mapOf("type" to "usb_detached"))
                    }
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(usbReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(usbReceiver, filter)
        }
    }

    private fun unregisterUsbReceiver() {
        usbReceiver?.let {
            try { unregisterReceiver(it) } catch (_: Exception) {}
            usbReceiver = null
        }
    }

    override fun onDestroy() {
        unregisterUsbReceiver()
        super.onDestroy()
    }

    private fun deleteFile(path: String, result: MethodChannel.Result) {
        try {
            val file = File(path)
            if (file.exists() && file.delete()) {
                result.success(true)
                return
            }

            // Try MediaStore if standard delete failed (likely due to Scoped Storage)
            val contentResolver = context.contentResolver
            val mediaUri = getMediaUriFromPath(path)
            
            if (mediaUri != null) {
                val rows = contentResolver.delete(mediaUri, null, null)
                if (rows > 0) {
                    result.success(true)
                } else {
                    result.error("DELETE_FAILED", "Could not delete file via MediaStore", null)
                }
            } else {
                result.error("NOT_FOUND", "File not found or not in MediaStore", null)
            }
        } catch (e: SecurityException) {
            // Handle RecoverableSecurityException for Android 10+ scoped storage
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && e is android.app.RecoverableSecurityException) {
                // Send the intent sender back to Flutter (or handle with Activity result)
                result.error("RECOVERABLE", "User confirmation required to delete file", null)
            } else {
                result.error("PERMISSION_DENIED", e.message, null)
            }
        } catch (e: Exception) {
            result.error("ERROR", e.message, null)
        }
    }

    private fun getMediaUriFromPath(path: String): Uri? {
        val extension = path.substringAfterLast('.', "")
        val volume = if (android.os.Build.VERSION.SDK_INT >= 29) {
            MediaStore.VOLUME_EXTERNAL
        } else {
            "external"
        }

        val uri = when (extension.lowercase()) {
            "jpg", "jpeg", "png", "gif", "bmp" -> MediaStore.Images.Media.getContentUri(volume)
            "mp4", "mkv", "avi" -> MediaStore.Video.Media.getContentUri(volume)
            "mp3", "wav" -> MediaStore.Audio.Media.getContentUri(volume)
            else -> MediaStore.Files.getContentUri(volume)
        }

        val projection = arrayOf(MediaStore.MediaColumns._ID)
        val selection = "${MediaStore.MediaColumns.DATA} = ?"
        val selectionArgs = arrayOf(path)

        context.contentResolver.query(uri, projection, selection, selectionArgs, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val id = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID))
                return ContentUris.withAppendedId(uri, id)
            }
        }
        return null
    }
}

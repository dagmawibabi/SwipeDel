package com.example.swipedel

import android.app.Activity
import android.content.ContentUris
import android.content.Intent
import android.content.IntentSender
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Native channel for operating on items already in the system trash.
 *
 * photo_manager can move media to the trash but can't address it afterwards
 * (its delete path resolves URIs through a MediaStore query, which hides
 * trashed rows). Here we build the content URIs directly from id + type, so we
 * can permanently delete or restore trashed items via the platform's own
 * confirmation dialogs.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "swipedel/trash"
    private val requestCode = 51001

    private var pendingResult: MethodChannel.Result? = null
    private var pendingIds: List<String>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "deleteForever" -> handleTrashAction(call, result, restore = false)
                    "restore" -> handleTrashAction(call, result, restore = true)
                    else -> result.notImplemented()
                }
            }
    }

    private fun handleTrashAction(
        call: MethodCall,
        result: MethodChannel.Result,
        restore: Boolean,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            result.error("unsupported", "Requires Android 11+", null)
            return
        }
        if (pendingResult != null) {
            result.error("busy", "Another trash action is in progress", null)
            return
        }

        val ids = call.argument<List<String>>("ids") ?: emptyList()
        val videos = call.argument<List<Boolean>>("videos") ?: emptyList()
        if (ids.isEmpty()) {
            result.success(emptyList<String>())
            return
        }

        val uris = ids.mapIndexedNotNull { i, idStr ->
            val id = idStr.toLongOrNull() ?: return@mapIndexedNotNull null
            val isVideo = videos.getOrNull(i) ?: false
            val base: Uri = if (isVideo) {
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI
            } else {
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI
            }
            ContentUris.withAppendedId(base, id)
        }
        if (uris.isEmpty()) {
            result.success(emptyList<String>())
            return
        }

        val pendingIntent = if (restore) {
            MediaStore.createTrashRequest(contentResolver, uris, false)
        } else {
            MediaStore.createDeleteRequest(contentResolver, uris)
        }

        pendingResult = result
        pendingIds = ids
        try {
            startIntentSenderForResult(
                pendingIntent.intentSender, requestCode, null, 0, 0, 0,
            )
        } catch (e: IntentSender.SendIntentException) {
            pendingResult = null
            pendingIds = null
            result.error("intent", e.message, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != this.requestCode) return
        val result = pendingResult
        val ids = pendingIds
        pendingResult = null
        pendingIds = null
        if (result == null) return
        if (resultCode == Activity.RESULT_OK) {
            result.success(ids ?: emptyList<String>())
        } else {
            result.success(emptyList<String>())
        }
    }
}

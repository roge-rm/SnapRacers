package com.rm.snapracers.net

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.net.Uri

/**
 * Sending courses and cups to other apps with Android's share sheet, as a
 * share code or as a file, and picking a file to open. A file being sent is
 * written to the app's cache and handed out through [SharedFiles], since
 * other apps can't read the game's own files. What a picked file holds comes
 * back to the game as a "picked" event, with its "text", or "" and "why".
 */
class Sharing(private val plugin: SnapRacersNet) {
    companion object {
        const val PICK_REQUEST = 7310
        /** The most of a picked file that's read, so a huge one can't fill memory. */
        const val MOST_BYTES = 1 shl 20
    }

    fun shareText(text: String, title: String) {
        val activity = plugin.currentActivity ?: return
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
        }
        activity.startActivity(Intent.createChooser(send, title))
    }

    fun shareFile(name: String, contents: String, title: String) {
        val activity = plugin.currentActivity ?: return
        val file = SharedFiles.fileFor(activity, name) ?: return
        file.writeText(contents)
        val uri = SharedFiles.uriFor(activity, file)
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "application/json"
            putExtra(Intent.EXTRA_STREAM, uri)
            clipData = ClipData.newRawUri(name, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        activity.startActivity(Intent.createChooser(send, title))
    }

    fun pickFile() {
        val activity = plugin.currentActivity ?: return
        val pick = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            // Chat apps and file managers label .json files all sorts of ways.
            type = "*/*"
        }
        activity.startActivityForResult(pick, PICK_REQUEST)
    }

    fun onResult(resultCode: Int, data: Intent?) {
        val uri: Uri? = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            plugin.tell("picked", "text" to "", "why" to "")
            return
        }
        try {
            val bytes = plugin.currentActivity?.contentResolver?.openInputStream(uri)?.use { input ->
                val out = java.io.ByteArrayOutputStream()
                val buffer = ByteArray(8192)
                while (true) {
                    val read = input.read(buffer)
                    if (read < 0) break
                    out.write(buffer, 0, read)
                    if (out.size() > MOST_BYTES) return@use null
                }
                out.toByteArray()
            }
            if (bytes == null) {
                plugin.tell("picked", "text" to "", "why" to "That file's too big.")
            } else {
                plugin.tell("picked", "text" to String(bytes, Charsets.UTF_8), "why" to "")
            }
        } catch (e: Exception) {
            plugin.tell("picked", "text" to "", "why" to "I couldn't open that file.")
        }
    }
}

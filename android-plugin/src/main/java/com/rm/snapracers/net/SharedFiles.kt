package com.rm.snapracers.net

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import java.io.File

/**
 * Hands the files in the cache's "shared" folder to whichever app a course or
 * cup is sent to (see [Sharing]), and nothing else. Only apps the share sheet
 * gives permission to can read them, and nothing can write.
 */
class SharedFiles : ContentProvider() {
    companion object {
        private const val FOLDER = "shared"

        fun authority(context: Context) = context.packageName + ".shared"

        /** Where a file with this name goes, or null for a name that isn't plain. */
        fun fileFor(context: Context, name: String): File? {
            if (name.isEmpty() || name.contains('/') || name.startsWith(".")) return null
            val folder = File(context.cacheDir, FOLDER)
            folder.mkdirs()
            return File(folder, name)
        }

        fun uriFor(context: Context, file: File): Uri =
            Uri.Builder().scheme("content").authority(authority(context)).appendPath(file.name).build()
    }

    private fun fileOf(uri: Uri): File? {
        val context = context ?: return null
        val name = uri.lastPathSegment ?: return null
        val file = fileFor(context, name) ?: return null
        return if (file.isFile) file else null
    }

    override fun onCreate() = true

    override fun getType(uri: Uri) = "application/json"

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor? {
        if (mode != "r") return null
        val file = fileOf(uri) ?: return null
        return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
    }

    /** The name and size, which some apps ask for before they read a file. */
    override fun query(uri: Uri, projection: Array<out String>?, selection: String?, selectionArgs: Array<out String>?, sortOrder: String?): Cursor? {
        val file = fileOf(uri) ?: return null
        val columns = projection ?: arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE)
        val row = columns.map {
            when (it) {
                OpenableColumns.DISPLAY_NAME -> file.name
                OpenableColumns.SIZE -> file.length()
                else -> null
            }
        }
        return MatrixCursor(columns).apply { addRow(row) }
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?) = 0
    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?) = 0
}

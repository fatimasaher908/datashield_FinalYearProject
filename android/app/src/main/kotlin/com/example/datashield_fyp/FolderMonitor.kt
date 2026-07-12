package com.example.datashield_fyp

import android.content.Context
import android.net.Uri
import android.util.Log
import androidx.documentfile.provider.DocumentFile
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class FolderMonitor(
    private val context: Context
) {

    companion object {
        private const val TAG = "FolderMonitor"
    }

    fun scanFolder(folderUri: String) {

        CoroutineScope(Dispatchers.IO).launch {

            val folder = DocumentFile.fromTreeUri(
                context,
                Uri.parse(folderUri)
            )

            if (folder == null) {
                Log.e(
                    TAG,
                    "Cannot access folder"
                )
                return@launch
            }

            for (file in folder.listFiles()) {

                if (!file.isFile) {
                    continue
                }

                // Ignore already encrypted files
                if (file.name?.endsWith(".dsenc") == true) {
                    continue
                }

                // Only encrypt image files
                val type = file.type ?: ""
                if (!type.startsWith("image")) {
                    continue
                }

                Log.d(
                    TAG,
                    "New image detected: ${file.name}"
                )

                val encryptedFile =
                    EncryptionManager.encryptSingleImage(
                        context,
                        file,
                        folder
                    )

                if (encryptedFile != null) {

                    Log.d(
                        TAG,
                        "Encrypted: ${encryptedFile.name}"
                    )

                    if (file.delete()) {

                        Log.d(
                            TAG,
                            "Original deleted."
                        )

                    } else {

                        Log.e(
                            TAG,
                            "Failed to delete original."
                        )

                    }

                } else {

                    Log.e(
                        TAG,
                        "Encryption failed: ${file.name}"
                    )

                }
            }
        }
    }
}
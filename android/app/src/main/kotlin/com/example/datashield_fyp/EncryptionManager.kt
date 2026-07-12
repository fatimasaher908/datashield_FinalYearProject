package com.example.datashield_fyp

import android.content.Context
import android.net.Uri
import android.util.Log
import androidx.documentfile.provider.DocumentFile

object EncryptionManager {

    private const val TAG = "DataShield"

    /**
     * Encrypt a single image.
     * Used by FolderMonitor when a new image is detected.
     */
    fun encryptSingleImage(
        context: Context,
        image: DocumentFile,
        parent: DocumentFile
    ): DocumentFile? {

        return EncryptionEngine.encryptImage(
            context,
            image,
            parent
        )
    }

    /**
     * Encrypt all images inside the selected folder.
     * Used only once during the initial setup.
     */
    fun encryptFolder(
        context: Context,
        folderUri: Uri
    ) {

        val folder = DocumentFile.fromTreeUri(
            context,
            folderUri
        )

        if (folder == null) {

            Log.e(TAG, "Cannot access folder")
            return
        }

        var imageCount = 0
        var encryptedCount = 0
        var videoCount = 0

        scanFolder(

            folder,

            onImage = { image, parent ->

                imageCount++

                Log.d(TAG, "IMAGE: ${image.name}")

                val encryptedFile =
                    encryptSingleImage(
                        context,
                        image,
                        parent
                    )

                if (encryptedFile != null) {

                    encryptedCount++

                    Log.d(
                        TAG,
                        "Encrypted: ${encryptedFile.name}"
                    )

                    if (image.delete()) {

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
                        "Encryption failed: ${image.name}"
                    )

                }

            },

            onVideo = { video ->

                videoCount++

                Log.d(
                    TAG,
                    "VIDEO: ${video.name}"
                )

            }

        )

        Log.d(TAG, "====================")
        Log.d(TAG, "Images Found: $imageCount")
        Log.d(TAG, "Images Encrypted: $encryptedCount")
        Log.d(TAG, "Videos Found: $videoCount")
    }

    /**
     * Recursively scan folders.
     */
    private fun scanFolder(

        folder: DocumentFile,

        onImage: (DocumentFile, DocumentFile) -> Unit,

        onVideo: (DocumentFile) -> Unit

    ) {

        folder.listFiles().forEach { file ->

            if (file.isDirectory) {

                scanFolder(
                    file,
                    onImage,
                    onVideo
                )

            } else if (file.isFile) {

                val type = file.type ?: ""

                when {

                    type.startsWith("image") ||
                            type == "application/octet-stream" -> {

                        // Ignore already encrypted files
                        if (file.name?.endsWith(".dsenc") == true)
                            return@forEach

                        onImage(
                            file,
                            folder
                        )
                    }

                    type.startsWith("video") -> {

                        onVideo(file)

                    }

                }

            }

        }

    }

}
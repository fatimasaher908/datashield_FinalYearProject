package com.example.datashield_fyp

import android.content.Context
import android.net.Uri
import android.util.Log
import androidx.documentfile.provider.DocumentFile

object DecryptionManager {

    private const val TAG = "DecryptionManager"

    // ============================================================
    // GET ENCRYPTED MEDIA FROM PICTURES + DCIM
    //
    // Returns:
    // {
    //     "uri": "...",
    //     "name": "photo.jpg.dsenc",
    //     "type": "image"
    // }
    //
    // or:
    //
    // {
    //     "uri": "...",
    //     "name": "video.mp4.dsenc",
    //     "type": "video"
    // }
    // ============================================================

    fun getEncryptedMedia(
        context: Context,
        picturesUri: Uri?,
        dcimUri: Uri?
    ): List<Map<String, String>> {

        val encryptedFiles =
            mutableListOf<Map<String, String>>()

        // Used as an extra safety layer in case the same
        // document is reachable through more than one path.
        val seenUris =
            mutableSetOf<String>()

        // ========================================================
        // PICTURES
        // ========================================================

        if (picturesUri != null) {

            Log.d(
                TAG,
                "Scanning Pictures for encrypted media: $picturesUri"
            )

            scanTree(
                context,
                picturesUri,
                encryptedFiles,
                seenUris
            )
        }

        // ========================================================
        // DCIM
        // ========================================================

        if (dcimUri != null) {

            Log.d(
                TAG,
                "Scanning DCIM for encrypted media: $dcimUri"
            )

            scanTree(
                context,
                dcimUri,
                encryptedFiles,
                seenUris
            )
        }

        Log.d(
            TAG,
            "Total encrypted media found: ${encryptedFiles.size}"
        )

        return encryptedFiles
    }

    // ============================================================
    // BACKWARDS COMPATIBILITY
    // ============================================================

    fun getEncryptedImages(
        context: Context,
        folderUri: Uri
    ): List<String> {

        val encryptedFiles =
            mutableListOf<Map<String, String>>()

        val seenUris =
            mutableSetOf<String>()

        scanTree(
            context,
            folderUri,
            encryptedFiles,
            seenUris
        )

        return encryptedFiles.mapNotNull {
            it["uri"]
        }
    }

    // ============================================================
    // SCAN SAF TREE
    // ============================================================

    private fun scanTree(
        context: Context,
        folderUri: Uri,
        result: MutableList<Map<String, String>>,
        seenUris: MutableSet<String>
    ) {

        try {

            val folder =
                DocumentFile.fromTreeUri(
                    context,
                    folderUri
                )

            if (folder == null) {

                Log.e(
                    TAG,
                    "Could not open folder: $folderUri"
                )

                return
            }

            if (!folder.exists()) {

                Log.e(
                    TAG,
                    "Folder does not exist: $folderUri"
                )

                return
            }

            if (!folder.isDirectory) {

                Log.e(
                    TAG,
                    "URI is not a directory: $folderUri"
                )

                return
            }

            scanFolder(
                folder,
                result,
                seenUris
            )

        } catch (e: Exception) {

            Log.e(
                TAG,
                "Error scanning encrypted media: $folderUri",
                e
            )
        }
    }

    // ============================================================
    // RECURSIVE FOLDER SCAN
    // ============================================================

    private fun scanFolder(
        folder: DocumentFile,
        result: MutableList<Map<String, String>>,
        seenUris: MutableSet<String>
    ) {

        // ========================================================
        // NEVER SCAN HIDDEN ROOT/SUBFOLDERS
        // ========================================================

        val currentFolderName =
            folder.name ?: ""

        if (isHiddenName(currentFolderName)) {

            Log.d(
                TAG,
                "Skipping hidden folder: $currentFolderName"
            )

            return
        }

        val files =
            try {

                folder.listFiles()

            } catch (e: Exception) {

                Log.e(
                    TAG,
                    "Could not list folder: ${folder.name}",
                    e
                )

                return
            }

        for (file in files) {

            try {

                // ==================================================
                // SUBFOLDER
                // ==================================================

                if (file.isDirectory) {

                    val folderName =
                        file.name ?: ""

                    // ----------------------------------------------
                    // SKIP HIDDEN / SYSTEM FOLDERS
                    //
                    // Examples:
                    // .thumbnails
                    // .Gallery2
                    // .hidden
                    // .cache
                    // .recycle
                    // ----------------------------------------------

                    if (isHiddenName(folderName)) {

                        Log.d(
                            TAG,
                            "Skipping hidden folder: $folderName"
                        )

                        continue
                    }

                    scanFolder(
                        file,
                        result,
                        seenUris
                    )

                    continue
                }

                // ==================================================
                // FILE
                // ==================================================

                if (!file.isFile) {
                    continue
                }

                val name =
                    file.name ?: continue

                // ==================================================
                // SKIP HIDDEN FILES
                // ==================================================

                if (isHiddenName(name)) {

                    Log.d(
                        TAG,
                        "Skipping hidden file: $name"
                    )

                    continue
                }

                // ==================================================
                // ONLY ENCRYPTED FILES
                // ==================================================

                if (
                    !name.endsWith(
                        ".dsenc",
                        ignoreCase = true
                    )
                ) {
                    continue
                }

                // ==================================================
                // DETERMINE ORIGINAL MEDIA TYPE
                //
                // photo.jpg.dsenc
                //       ↓
                // photo.jpg
                //       ↓
                // jpg
                //       ↓
                // image
                // ==================================================

                val originalName =
                    name.replaceFirst(
                        Regex(
                            "\\.dsenc$",
                            RegexOption.IGNORE_CASE
                        ),
                        ""
                    )

                val extension =
                    originalName
                        .substringAfterLast(
                            '.',
                            ""
                        )
                        .lowercase()

                val mediaType =
                    when {

                        isImageExtension(extension) ->
                            "image"

                        isVideoExtension(extension) ->
                            "video"

                        else -> {

                            Log.d(
                                TAG,
                                "Unknown media type: $name"
                            )

                            continue
                        }
                    }

                // ==================================================
                // GET ACTUAL URI
                // ==================================================

                val uriString =
                    file.uri.toString()

                // ==================================================
                // DUPLICATE URI PROTECTION
                // ==================================================

                if (!seenUris.add(uriString)) {

                    Log.d(
                        TAG,
                        "Duplicate encrypted URI skipped: $uriString"
                    )

                    continue
                }

                // ==================================================
                // ADD MEDIA
                // ==================================================

                result.add(
                    mapOf(
                        "uri" to uriString,
                        "name" to name,
                        "type" to mediaType
                    )
                )

                Log.d(
                    TAG,
                    "Encrypted $mediaType found: $name"
                )

            } catch (e: Exception) {

                Log.e(
                    TAG,
                    "Error scanning file: ${file.name}",
                    e
                )
            }
        }
    }

    // ============================================================
    // CHECK HIDDEN FILE / FOLDER
    // ============================================================

    private fun isHiddenName(
        name: String
    ): Boolean {

        return name.isNotBlank() &&
                name.startsWith(".")
    }

    // ============================================================
    // IMAGE EXTENSIONS
    // ============================================================

    private fun isImageExtension(
        extension: String
    ): Boolean {

        return extension in setOf(
            "jpg",
            "jpeg",
            "png",
            "webp",
            "gif",
            "bmp",
            "heic",
            "heif",
            "tif",
            "tiff"
        )
    }

    // ============================================================
    // VIDEO EXTENSIONS
    // ============================================================

    private fun isVideoExtension(
        extension: String
    ): Boolean {

        return extension in setOf(
            "mp4",
            "mov",
            "avi",
            "mkv",
            "webm",
            "3gp",
            "m4v",
            "3g2",
            "ts"
        )
    }
}
package com.example.datashield_fyp

import android.content.Context
import android.net.Uri
import android.util.Log
import androidx.documentfile.provider.DocumentFile

object EncryptionManager {

    private const val TAG = "EncryptionManager"

    /**
     * Encrypt a single file.
     *
     * Used by FolderMonitor for both images and videos.
     */
    fun encryptSingleFile(
        context: Context,
        file: DocumentFile,
        parent: DocumentFile,
        keyBytes: ByteArray
    ): DocumentFile? {

        return EncryptionEngine.encryptFile(
            context,
            file,
            parent,
            keyBytes
        )
    }

    /**
     * Backwards-compatible image method.
     */
    fun encryptSingleImage(
        context: Context,
        file: DocumentFile,
        parent: DocumentFile,
        keyBytes: ByteArray
    ): DocumentFile? {

        return encryptSingleFile(
            context,
            file,
            parent,
            keyBytes
        )
    }

    /**
     * Encrypt all supported media inside a folder.
     *
     * Supported:
     *
     * Images:
     * jpg
     * jpeg
     * png
     * gif
     * webp
     * bmp
     * heic
     * heif
     *
     * Videos:
     * mp4
     * mov
     * mkv
     * avi
     * webm
     * 3gp
     * m4v
     *
     * Subfolders are scanned recursively.
     */
    fun encryptFolder(
        context: Context,
        folderUri: Uri,
        keyBytes: ByteArray
    ) {

        if (keyBytes.isEmpty()) {

            Log.e(
                TAG,
                "Cannot encrypt folder: encryption key is empty."
            )

            return
        }

        val rootFolder =
            DocumentFile.fromTreeUri(
                context,
                folderUri
            )

        if (rootFolder == null) {

            Log.e(
                TAG,
                "Could not open media folder: $folderUri"
            )

            return
        }

        if (!rootFolder.exists()) {

            Log.e(
                TAG,
                "Pictures folder does not exist."
            )

            return
        }

        if (!rootFolder.isDirectory) {

            Log.e(
                TAG,
                "Provided URI is not a directory."
            )

            return
        }

        Log.d(
            TAG,
            "========== START FOLDER ENCRYPTION =========="
        )

        Log.d(
            TAG,
            "Folder URI: $folderUri"
        )

        scanAndEncrypt(
            context,
            rootFolder,
            keyBytes
        )

        Log.d(
            TAG,
            "========== FOLDER ENCRYPTION COMPLETE =========="
        )
    }

    /**
     * Recursively scan a folder.
     */
    private fun scanAndEncrypt(
        context: Context,
        folder: DocumentFile,
        keyBytes: ByteArray
    ) {

        val children =
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

        for (child in children) {

            try {

                // ------------------------------------------------
                // SUBDIRECTORY
                // ------------------------------------------------

                if (child.isDirectory) {

                    Log.d(
                        TAG,
                        "Scanning subfolder: ${child.name}"
                    )

                    scanAndEncrypt(
                        context,
                        child,
                        keyBytes
                    )

                    continue
                }

                // ------------------------------------------------
                // FILE
                // ------------------------------------------------

                if (!child.isFile) {
                    continue
                }

                val fileName =
                    child.name ?: continue

                // Never process .dsenc files
                if (
                    fileName.endsWith(
                        ".dsenc",
                        ignoreCase = true
                    )
                ) {

                    Log.d(
                        TAG,
                        "Skipping encrypted file: $fileName"
                    )

                    continue
                }

                // ------------------------------------------------
                // CHECK MEDIA TYPE
                // ------------------------------------------------

                if (!isSupportedMedia(child)) {

                    Log.d(
                        TAG,
                        "Skipping unsupported file: $fileName"
                    )

                    continue
                }

                Log.d(
                    TAG,
                    "Encrypting: $fileName"
                )

                // ------------------------------------------------
                // ENCRYPT
                // ------------------------------------------------

                encryptSingleFile(
                    context,
                    child,
                    folder,
                    keyBytes
                )

            } catch (e: Exception) {

                Log.e(
                    TAG,
                    "Error processing file: ${child.name}",
                    e
                )
            }
        }
    }

    /**
     * Determine whether a file is an image or video.
     */
    private fun isSupportedMedia(
        file: DocumentFile
    ): Boolean {

        // --------------------------------------------------------
        // MIME TYPE
        // --------------------------------------------------------

        val mimeType =
            file.type?.lowercase()

        if (
            mimeType != null &&
            (
                mimeType.startsWith("image/") ||
                mimeType.startsWith("video/")
            )
        ) {

            return true
        }

        // --------------------------------------------------------
        // FILE EXTENSION FALLBACK
        // --------------------------------------------------------

        val name =
            file.name?.lowercase()
                ?: return false

        val imageExtensions =
            setOf(
                ".jpg",
                ".jpeg",
                ".png",
                ".gif",
                ".webp",
                ".bmp",
                ".heic",
                ".heif",
                ".tif",
                ".tiff"
            )

        val videoExtensions =
            setOf(
                ".mp4",
                ".mov",
                ".mkv",
                ".avi",
                ".webm",
                ".3gp",
                ".m4v",
                ".3g2",
                ".ts"
            )

        return imageExtensions.any {
            name.endsWith(it)
        } || videoExtensions.any {
            name.endsWith(it)
        }
    }

    /**
     * Scan a folder without encrypting.
     *
     * Kept for compatibility with older project code.
     */
    fun scanFolder(
        context: Context,
        folder: DocumentFile
    ): List<DocumentFile> {

        val results =
            mutableListOf<DocumentFile>()

        scanFolderRecursive(
            folder,
            results
        )

        return results
    }

    /**
     * Recursive folder scanner.
     */
    private fun scanFolderRecursive(
        folder: DocumentFile,
        results: MutableList<DocumentFile>
    ) {

        val children =
            try {
                folder.listFiles()
            } catch (e: Exception) {

                Log.e(
                    TAG,
                    "Could not scan folder: ${folder.name}",
                    e
                )

                return
            }

        for (child in children) {

            if (child.isDirectory) {

                scanFolderRecursive(
                    child,
                    results
                )

            } else if (
                child.isFile &&
                !child.name
                    .orEmpty()
                    .endsWith(
                        ".dsenc",
                        ignoreCase = true
                    ) &&
                isSupportedMedia(child)
            ) {

                results.add(child)
            }
        }
    }
}
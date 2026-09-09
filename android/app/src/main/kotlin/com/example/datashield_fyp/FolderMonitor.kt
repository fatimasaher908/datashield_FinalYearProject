package com.example.datashield_fyp

import android.content.Context
import android.net.Uri
import android.util.Log
import androidx.documentfile.provider.DocumentFile
import java.io.File
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking

class FolderMonitor(
    private val context: Context
) {

    companion object {

        private const val TAG = "FolderMonitor"

        // ============================================================
        // SUPPORTED IMAGE EXTENSIONS
        // ============================================================

        private val IMAGE_EXTENSIONS = setOf(
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

        // ============================================================
        // SUPPORTED VIDEO EXTENSIONS
        // ============================================================

        private val VIDEO_EXTENSIONS = setOf(
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

        // ============================================================
        // TEMPORARY / DOWNLOADING FILES
        // ============================================================

        private val TEMP_EXTENSIONS = setOf(
            "tmp",
            "crdownload",
            "part",
            "pending",
            "download"
        )

        // ============================================================
        // FILE STABILITY SETTINGS
        // ============================================================

        // Number of consecutive times the file size must remain
        // unchanged before we consider it ready for encryption.
        private const val STABLE_CHECKS = 3

        // Time between stability checks.
        private const val STABILITY_DELAY_MS = 2000L
    }


    // ============================================================
    // SCAN FOLDER
    // ============================================================

    fun scanFolder(
        folderUri: String,
        keyBytes: ByteArray
    ) {

        Log.d(
            TAG,
            "========== scanFolder START =========="
        )

        Log.d(
            TAG,
            "Folder target: $folderUri"
        )

        if (folderUri.startsWith("content://")) {

            scanSafFolder(
                folderUri,
                keyBytes
            )

        } else {

            scanFileFolder(
                File(folderUri),
                keyBytes
            )
        }

        Log.d(
            TAG,
            "========== scanFolder END =========="
        )
    }


    // ============================================================
    // SAF TREE SCANNING
    // ============================================================

    private fun scanSafFolder(
        uriString: String,
        keyBytes: ByteArray
    ) {

        val targetUri =
            Uri.parse(uriString)

        // ========================================================
        // CHECK PERSISTED PERMISSION
        // ========================================================

        val hasPermission =
            context.contentResolver
                .persistedUriPermissions
                .any {
                    it.uri == targetUri &&
                            it.isReadPermission &&
                            it.isWritePermission
                }

        if (!hasPermission) {

            Log.w(
                TAG,
                "Persisted URI permission missing for: $uriString"
            )
        }

        // ========================================================
        // OPEN SAF FOLDER
        // ========================================================

        val folder =
            DocumentFile.fromTreeUri(
                context,
                targetUri
            )

        if (
            folder == null ||
            !folder.exists()
        ) {

            Log.e(
                TAG,
                "Cannot access SAF folder: $uriString"
            )

            return
        }

        Log.d(
            TAG,
            "SAF Folder opened successfully"
        )

        // ========================================================
        // LIST FILES
        // ========================================================

        val files = try {

            folder.listFiles()

        } catch (e: Exception) {

            Log.e(
                TAG,
                "Unable to list SAF folder contents",
                e
            )

            return
        }

        Log.d(
            TAG,
            "Files found in SAF folder: ${files.size}"
        )

        // ========================================================
        // PROCESS ROOT FILES + SUBFOLDERS
        // ========================================================

        for (file in files) {

            try {

                if (file.isDirectory) {

                    val folderName =
                        file.name ?: ""

                    if (isHiddenName(folderName)) {

                        Log.d(
                            TAG,
                            "Skipping hidden SAF folder: $folderName"
                        )

                        continue
                    }

                    scanDocumentSubfolder(
                        file,
                        keyBytes
                    )

                } else if (file.isFile) {

                    val fileName =
                        file.name ?: ""

                    if (isHiddenName(fileName)) {

                        Log.d(
                            TAG,
                            "Skipping hidden SAF file: $fileName"
                        )

                        continue
                    }

                    processSafFile(
                        file,
                        folder,
                        keyBytes
                    )
                }

            } catch (e: Exception) {

                Log.e(
                    TAG,
                    "Error processing SAF file: ${file.name}",
                    e
                )
            }
        }
    }


    // ============================================================
    // RECURSIVELY SCAN SAF SUBFOLDERS
    // ============================================================

    private fun scanDocumentSubfolder(
        folder: DocumentFile,
        keyBytes: ByteArray
    ) {

        val folderName =
            folder.name ?: ""

        if (isHiddenName(folderName)) {

            Log.d(
                TAG,
                "Skipping hidden SAF folder: $folderName"
            )

            return
        }

        Log.d(
            TAG,
            "Scanning SAF subfolder: $folderName"
        )

        val files = try {

            folder.listFiles()

        } catch (e: Exception) {

            Log.e(
                TAG,
                "Cannot list SAF subfolder: $folderName",
                e
            )

            return
        }

        for (file in files) {

            try {

                if (file.isDirectory) {

                    val childFolderName =
                        file.name ?: ""

                    if (isHiddenName(childFolderName)) {

                        Log.d(
                            TAG,
                            "Skipping hidden SAF subfolder: $childFolderName"
                        )

                        continue
                    }

                    scanDocumentSubfolder(
                        file,
                        keyBytes
                    )

                } else if (file.isFile) {

                    val fileName =
                        file.name ?: ""

                    if (isHiddenName(fileName)) {

                        Log.d(
                            TAG,
                            "Skipping hidden SAF file: $fileName"
                        )

                        continue
                    }

                    processSafFile(
                        file,
                        folder,
                        keyBytes
                    )
                }

            } catch (e: Exception) {

                Log.e(
                    TAG,
                    "Error processing subfolder file: ${file.name}",
                    e
                )
            }
        }
    }


    // ============================================================
    // PROCESS SAF FILE
    // ============================================================

    private fun processSafFile(
        file: DocumentFile,
        parent: DocumentFile,
        keyBytes: ByteArray
    ) {

        val fileName =
            file.name ?: "unknown"

        if (isHiddenName(fileName)) {
            return
        }

        val mimeType =
            file.type ?: ""

        val fileLength =
            file.length()

        // ========================================================
        // CHECK WHETHER FILE IS IMAGE OR VIDEO
        // ========================================================

        if (
            !isEligibleMedia(
                fileName,
                mimeType,
                fileLength
            )
        ) {

            return
        }

        val mediaType =
            getMediaType(
                fileName,
                mimeType
            )

        Log.d(
            TAG,
            "========== MEDIA DETECTED =========="
        )

        Log.d(
            TAG,
            "Type: $mediaType"
        )

        Log.d(
            TAG,
            "File: $fileName"
        )

        Log.d(
            TAG,
            "MIME: $mimeType"
        )

        Log.d(
            TAG,
            "Initial size: $fileLength bytes"
        )

        // ========================================================
        // WAIT FOR FILE TO BECOME STABLE
        // ========================================================

        if (
            !waitForSafFileToBecomeStable(file)
        ) {

            Log.d(
                TAG,
                "File is still changing. Skipping for now: $fileName"
            )

            return
        }

        Log.d(
            TAG,
            "File is stable and ready for encryption: $fileName"
        )

        // ========================================================
        // ENCRYPT FILE
        // ========================================================

        val encryptedFile =
            EncryptionManager.encryptSingleFile(
                context,
                file,
                parent,
                keyBytes
            )

        // ========================================================
        // DELETE ORIGINAL ONLY AFTER SUCCESS
        // ========================================================

        if (encryptedFile != null) {

            Log.d(
                TAG,
                "Encryption successful: ${encryptedFile.name}"
            )

            if (file.delete()) {

                Log.d(
                    TAG,
                    "Original file deleted: $fileName"
                )

            } else {

                Log.e(
                    TAG,
                    "Encryption succeeded but original deletion failed: $fileName"
                )
            }

        } else {

            Log.e(
                TAG,
                "Encryption failed for: $fileName"
            )
        }
    }


    // ============================================================
    // WAIT FOR SAF FILE TO BECOME STABLE
    // ============================================================

    private fun waitForSafFileToBecomeStable(
        file: DocumentFile
    ): Boolean {

        var previousSize =
            file.length()

        if (previousSize <= 0) {
            return false
        }

        var stableCount = 0

        Log.d(
            TAG,
            "Checking file stability: ${file.name}"
        )

        while (stableCount < STABLE_CHECKS) {

            try {

                Thread.sleep(
                    STABILITY_DELAY_MS
                )

            } catch (e: InterruptedException) {

                Thread.currentThread().interrupt()

                Log.w(
                    TAG,
                    "File stability check interrupted: ${file.name}"
                )

                return false
            }

            if (!file.exists()) {

                Log.d(
                    TAG,
                    "File disappeared during stability check: ${file.name}"
                )

                return false
            }

            val currentSize =
                file.length()

            Log.d(
                TAG,
                "Stability check ${stableCount + 1}/$STABLE_CHECKS: " +
                        "${file.name} = $currentSize bytes"
            )

            if (currentSize <= 0) {

                return false
            }

            if (currentSize == previousSize) {

                stableCount++

            } else {

                Log.d(
                    TAG,
                    "File size changed: " +
                            "$previousSize -> $currentSize bytes"
                )

                stableCount = 0
            }

            previousSize =
                currentSize
        }

        return true
    }


    // ============================================================
    // DIRECT RAW FILE SYSTEM SCANNING
    // ============================================================

    private fun scanFileFolder(
        folder: File,
        keyBytes: ByteArray
    ) {

        if (
            !folder.exists() ||
            !folder.isDirectory
        ) {

            Log.e(
                TAG,
                "Raw file directory invalid: ${folder.absolutePath}"
            )

            return
        }

        if (isHiddenName(folder.name)) {

            Log.d(
                TAG,
                "Skipping hidden raw folder: ${folder.name}"
            )

            return
        }

        val files =
            folder.listFiles()
                ?: return

        for (file in files) {

            try {

                if (file.isDirectory) {

                    if (isHiddenName(file.name)) {

                        Log.d(
                            TAG,
                            "Skipping hidden raw folder: ${file.name}"
                        )

                        continue
                    }

                    scanFileFolder(
                        file,
                        keyBytes
                    )

                } else if (file.isFile) {

                    if (isHiddenName(file.name)) {

                        Log.d(
                            TAG,
                            "Skipping hidden raw file: ${file.name}"
                        )

                        continue
                    }

                    processRawFile(
                        file,
                        keyBytes
                    )
                }

            } catch (e: Exception) {

                Log.e(
                    TAG,
                    "Error processing raw file: ${file.name}",
                    e
                )
            }
        }
    }


    // ============================================================
    // PROCESS RAW FILE
    // ============================================================

    private fun processRawFile(
        file: File,
        keyBytes: ByteArray
    ) {

        val fileName =
            file.name

        if (isHiddenName(fileName)) {
            return
        }

        if (
            !isEligibleMedia(
                fileName,
                "",
                file.length()
            )
        ) {

            return
        }

        val mediaType =
            getMediaType(
                fileName,
                ""
            )

        Log.d(
            TAG,
            "========== RAW MEDIA DETECTED =========="
        )

        Log.d(
            TAG,
            "Type: $mediaType"
        )

        Log.d(
            TAG,
            "File: $fileName"
        )

        Log.d(
            TAG,
            "Path: ${file.absolutePath}"
        )

        Log.d(
            TAG,
            "Initial size: ${file.length()} bytes"
        )

        // ========================================================
        // WAIT FOR RAW FILE TO BECOME STABLE
        // ========================================================

        if (
            !waitForRawFileToBecomeStable(file)
        ) {

            Log.d(
                TAG,
                "Raw file is still changing. Skipping: $fileName"
            )

            return
        }

        Log.d(
            TAG,
            "Raw file is stable and ready for encryption: $fileName"
        )

        val documentFile =
            DocumentFile.fromFile(file)

        val parentDocumentFile =
            DocumentFile.fromFile(
                file.parentFile ?: return
            )

        // ========================================================
        // ENCRYPT FILE
        // ========================================================

        val encryptedFile =
            EncryptionManager.encryptSingleFile(
                context,
                documentFile,
                parentDocumentFile,
                keyBytes
            )

        // ========================================================
        // DELETE ORIGINAL AFTER SUCCESS
        // ========================================================

        if (encryptedFile != null) {

            Log.d(
                TAG,
                "Encryption successful: ${encryptedFile.name}"
            )

            if (file.delete()) {

                Log.d(
                    TAG,
                    "Original raw file deleted: $fileName"
                )

            } else {

                Log.e(
                    TAG,
                    "Encryption succeeded but raw file deletion failed: $fileName"
                )
            }

        } else {

            Log.e(
                TAG,
                "Encryption failed for: $fileName"
            )
        }
    }


    // ============================================================
    // WAIT FOR RAW FILE TO BECOME STABLE
    // ============================================================

    private fun waitForRawFileToBecomeStable(
        file: File
    ): Boolean {

        var previousSize =
            file.length()

        if (previousSize <= 0) {
            return false
        }

        var stableCount = 0

        Log.d(
            TAG,
            "Checking raw file stability: ${file.name}"
        )

        while (stableCount < STABLE_CHECKS) {

            try {

                Thread.sleep(
                    STABILITY_DELAY_MS
                )

            } catch (e: InterruptedException) {

                Thread.currentThread().interrupt()

                return false
            }

            if (!file.exists()) {
                return false
            }

            val currentSize =
                file.length()

            Log.d(
                TAG,
                "Raw stability check ${stableCount + 1}/$STABLE_CHECKS: " +
                        "${file.name} = $currentSize bytes"
            )

            if (currentSize <= 0) {
                return false
            }

            if (currentSize == previousSize) {

                stableCount++

            } else {

                Log.d(
                    TAG,
                    "Raw file size changed: " +
                            "$previousSize -> $currentSize bytes"
                )

                stableCount = 0
            }

            previousSize =
                currentSize
        }

        return true
    }


    // ============================================================
    // CHECK IF FILE IS ELIGIBLE
    // ============================================================

    private fun isEligibleMedia(
        fileName: String,
        mimeType: String,
        fileLength: Long
    ): Boolean {

        if (isHiddenName(fileName)) {
            return false
        }

        if (
            fileName.endsWith(
                ".dsenc",
                ignoreCase = true
            )
        ) {

            return false
        }

        val extension =
            fileName
                .substringAfterLast(
                    '.',
                    ""
                )
                .lowercase()

        if (
            extension in TEMP_EXTENSIONS
        ) {

            return false
        }

        if (fileLength <= 0) {
            return false
        }

        val isImageByMime =
            mimeType.startsWith(
                "image/",
                ignoreCase = true
            )

        val isVideoByMime =
            mimeType.startsWith(
                "video/",
                ignoreCase = true
            )

        val isImageByExtension =
            extension in IMAGE_EXTENSIONS

        val isVideoByExtension =
            extension in VIDEO_EXTENSIONS

        return (
            isImageByMime ||
                    isVideoByMime ||
                    isImageByExtension ||
                    isVideoByExtension
            )
    }


    // ============================================================
    // DETERMINE MEDIA TYPE
    // ============================================================

    private fun getMediaType(
        fileName: String,
        mimeType: String
    ): String {

        val extension =
            fileName
                .substringAfterLast(
                    '.',
                    ""
                )
                .lowercase()

        return when {

            mimeType.startsWith(
                "image/",
                ignoreCase = true
            ) ||
                    extension in IMAGE_EXTENSIONS -> {

                "IMAGE"
            }

            mimeType.startsWith(
                "video/",
                ignoreCase = true
            ) ||
                    extension in VIDEO_EXTENSIONS -> {

                "VIDEO"
            }

            else -> {

                "UNKNOWN"
            }
        }
    }


    // ============================================================
    // CHECK FOR HIDDEN FILE / FOLDER
    // ============================================================

    private fun isHiddenName(
        name: String
    ): Boolean {

        return name.isNotBlank() &&
                name.startsWith(".")
    }
}
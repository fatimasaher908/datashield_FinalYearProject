package com.example.datashield_fyp

import android.content.Context
import android.net.Uri
import android.util.Log
import androidx.documentfile.provider.DocumentFile

object EncryptionManager {

    private const val TAG =
        "EncryptionManager"


    // ============================================================
    // ENCRYPT SINGLE FILE
    // ============================================================

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


    // ============================================================
    // ENCRYPT SINGLE IMAGE
    // ============================================================

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


    // ============================================================
    // ENCRYPT FOLDER
    //
    // Returns ONLY files that were successfully encrypted
    // during THIS encryption operation.
    //
    // Already encrypted .dsenc files are skipped.
    // ============================================================

    fun encryptFolder(
        context: Context,
        folderUri: Uri,
        keyBytes: ByteArray
    ): List<Map<String, Any>> {

        val encryptedFiles =
            mutableListOf<Map<String, Any>>()


        // ========================================================
        // VALIDATE KEY
        // ========================================================

        if (keyBytes.isEmpty()) {

            Log.e(
                TAG,
                "Cannot encrypt folder: encryption key is empty."
            )

            return encryptedFiles
        }


        // ========================================================
        // OPEN ROOT FOLDER
        // ========================================================

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

            return encryptedFiles
        }


        // ========================================================
        // CHECK EXISTS
        // ========================================================

        if (!rootFolder.exists()) {

            Log.e(
                TAG,
                "Media folder does not exist."
            )

            return encryptedFiles
        }


        // ========================================================
        // CHECK DIRECTORY
        // ========================================================

        if (!rootFolder.isDirectory) {

            Log.e(
                TAG,
                "Provided URI is not a directory."
            )

            return encryptedFiles
        }


        // ========================================================
        // START
        // ========================================================

        Log.d(
            TAG,
            "========== START FOLDER ENCRYPTION =========="
        )

        Log.d(
            TAG,
            "Folder URI: $folderUri"
        )


        // ========================================================
        // SCAN + ENCRYPT
        // ========================================================

        scanAndEncrypt(
            context,
            rootFolder,
            keyBytes,
            encryptedFiles
        )


        // ========================================================
        // COMPLETE
        // ========================================================

        Log.d(
            TAG,
            "========== FOLDER ENCRYPTION COMPLETE =========="
        )

        Log.d(
            TAG,
            "New files encrypted: ${encryptedFiles.size}"
        )


        return encryptedFiles
    }


    // ============================================================
    // SCAN FOLDER AND ENCRYPT MEDIA
    // ============================================================

    private fun scanAndEncrypt(
        context: Context,
        folder: DocumentFile,
        keyBytes: ByteArray,
        encryptedFiles: MutableList<Map<String, Any>>
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


        // ========================================================
        // PROCESS EACH CHILD
        // ========================================================

        for (child in children) {

            try {

                // ==================================================
                // DIRECTORY
                // ==================================================

                if (child.isDirectory) {

                    Log.d(
                        TAG,
                        "Scanning subfolder: ${child.name}"
                    )

                    scanAndEncrypt(
                        context,
                        child,
                        keyBytes,
                        encryptedFiles
                    )

                    continue
                }


                // ==================================================
                // NOT A FILE
                // ==================================================

                if (!child.isFile) {
                    continue
                }


                // ==================================================
                // GET ORIGINAL FILE NAME
                // ==================================================

                val fileName =
                    child.name
                        ?: continue


                // ==================================================
                // SKIP ALREADY ENCRYPTED FILES
                // ==================================================

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


                // ==================================================
                // SKIP UNSUPPORTED FILES
                // ==================================================

                if (!isSupportedMedia(child)) {

                    Log.d(
                        TAG,
                        "Skipping unsupported file: $fileName"
                    )

                    continue
                }


                // ==================================================
                // ENCRYPT FILE
                // ==================================================

                Log.d(
                    TAG,
                    "Encrypting: $fileName"
                )

                val encryptedFile =
                    encryptSingleFile(
                        context,
                        child,
                        folder,
                        keyBytes
                    )


                // ==================================================
                // ONLY REGISTER SUCCESSFULLY ENCRYPTED FILES
                // ==================================================

                if (encryptedFile != null) {

                    // ------------------------------------------------
                    // ENCRYPTED FILE NAME
                    // ------------------------------------------------

                    val encryptedName =
                        encryptedFile.name
                            ?: "$fileName.dsenc"


                    // ------------------------------------------------
                    // ORIGINAL MIME TYPE
                    // ------------------------------------------------

                    val mimeType =
                        child.type
                            ?: "application/octet-stream"


                    // ------------------------------------------------
                    // FILE TYPE
                    // ------------------------------------------------

                    val fileType =
                        when {

                            mimeType.startsWith(
                                "image/"
                            ) -> "image"

                            mimeType.startsWith(
                                "video/"
                            ) -> "video"

                            else -> "unknown"
                        }


                    // ------------------------------------------------
                    // ENCRYPTED FILE SIZE
                    // ------------------------------------------------

                    val fileSize =
                        encryptedFile.length()


                    // ------------------------------------------------
                    // ADD METADATA
                    // ------------------------------------------------

                    encryptedFiles.add(
                        mapOf(
                            "uri" to
                                encryptedFile
                                    .uri
                                    .toString(),

                            "originalName" to
                                fileName,

                            "encryptedName" to
                                encryptedName,

                            "fileSize" to
                                fileSize,

                            "mimeType" to
                                mimeType,

                            "fileType" to
                                fileType
                        )
                    )


                    // ------------------------------------------------
                    // LOG SUCCESS
                    // ------------------------------------------------

                    Log.d(
                        TAG,
                        "Successfully encrypted:"
                    )

                    Log.d(
                        TAG,
                        "  Original: $fileName"
                    )

                    Log.d(
                        TAG,
                        "  Encrypted: $encryptedName"
                    )

                    Log.d(
                        TAG,
                        "  Size: $fileSize bytes"
                    )

                    Log.d(
                        TAG,
                        "  MIME: $mimeType"
                    )

                    Log.d(
                        TAG,
                        "  Type: $fileType"
                    )
                }

            } catch (e: Exception) {

                Log.e(
                    TAG,
                    "Error processing file: ${child.name}",
                    e
                )
            }
        }
    }


    // ============================================================
    // CHECK SUPPORTED MEDIA
    //
    // Supported:
    // Images
    // Videos
    // ============================================================

    private fun isSupportedMedia(
        file: DocumentFile
    ): Boolean {

        // ========================================================
        // CHECK MIME TYPE
        // ========================================================

        val mimeType =
            file.type
                ?.lowercase()

        if (
            mimeType != null &&
            (
                mimeType.startsWith("image/") ||
                mimeType.startsWith("video/")
            )
        ) {

            return true
        }


        // ========================================================
        // FALLBACK TO FILE EXTENSION
        // ========================================================

        val name =
            file.name
                ?.lowercase()
                ?: return false


        // ========================================================
        // IMAGE EXTENSIONS
        // ========================================================

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


        // ========================================================
        // VIDEO EXTENSIONS
        // ========================================================

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


        // ========================================================
        // CHECK EXTENSIONS
        // ========================================================

        return (
            imageExtensions.any {
                name.endsWith(it)
            } ||
            videoExtensions.any {
                name.endsWith(it)
            }
        )
    }


    // ============================================================
    // SCAN FOLDER
    //
    // Returns normal, unencrypted supported media files.
    //
    // This function is kept for your existing functionality.
    // ============================================================

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


    // ============================================================
    // RECURSIVE SCAN
    // ============================================================

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


        // ========================================================
        // PROCESS CHILDREN
        // ========================================================

        for (child in children) {

            // ----------------------------------------------------
            // DIRECTORY
            // ----------------------------------------------------

            if (child.isDirectory) {

                scanFolderRecursive(
                    child,
                    results
                )

            }

            // ----------------------------------------------------
            // NORMAL MEDIA FILE
            // ----------------------------------------------------

            else if (
                child.isFile &&
                !child.name
                    .orEmpty()
                    .endsWith(
                        ".dsenc",
                        ignoreCase = true
                    ) &&
                isSupportedMedia(child)
            ) {

                results.add(
                    child
                )
            }
        }
    }
}
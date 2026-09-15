package com.example.datashield_fyp

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import android.util.Log
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {


companion object {

    // ========================================================
    // CHANNELS
    // ========================================================

    private const val STORAGE_CHANNEL =
        "datashield/storage"

    private const val ENCRYPTION_CHANNEL =
        "datashield/encryption"

    private const val SERVICE_CHANNEL =
        "datashield/service"

    private const val MEDIA_CHANNEL =
        "datashield/media"


    // ========================================================
    // REQUEST CODES
    // ========================================================

    private const val PICK_PICTURES_REQUEST =
        1001

    private const val PICK_DCIM_REQUEST =
        1002


    // ========================================================
    // LOG
    // ========================================================

    private const val TAG =
        "MainActivity"


    // ========================================================
    // STORAGE
    // ========================================================

    private const val PREFS =
        "datashield_pictures"

    private const val PICTURES_URI_KEY =
        "pictures_uri"

    private const val DCIM_URI_KEY =
        "dcim_uri"


    // ========================================================
    // SERVICE EXTRAS
    // ========================================================

    private const val EXTRA_PICTURES_URI =
        "picturesUri"

    private const val EXTRA_DCIM_URI =
        "dcimUri"

    private const val EXTRA_KEY =
        "key"
}


// ============================================================
// PENDING FOLDER PICKER RESULT
// ============================================================

private var pendingResult:
    MethodChannel.Result? = null


// ============================================================
// FLUTTER ENGINE
// ============================================================

override fun configureFlutterEngine(
    flutterEngine: FlutterEngine
) {

    super.configureFlutterEngine(
        flutterEngine
    )

    flutterEngine
    .platformViewsController
    .registry
    .registerViewFactory(
        "datashield/video_player",
        DataShieldVideoViewFactory()
    )

    // ========================================================
    // SERVICE CHANNEL
    // ========================================================

    MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        SERVICE_CHANNEL
    ).setMethodCallHandler { call, result ->

        when (call.method) {

            // =================================================
            // START DATASHIELD SERVICE
            // =================================================

            "startService" -> {

                val picturesUri =
                    call.argument<String>(
                        "picturesUri"
                    )

                val dcimUri =
                    call.argument<String>(
                        "dcimUri"
                    )

                val keyBytes =
                    call.argument<ByteArray>(
                        "key"
                    )

                if (picturesUri.isNullOrEmpty()) {

                    result.error(
                        "INVALID_PICTURES_URI",
                        "Pictures folder URI is missing.",
                        null
                    )

                    return@setMethodCallHandler
                }

                if (dcimUri.isNullOrEmpty()) {

                    result.error(
                        "INVALID_DCIM_URI",
                        "DCIM folder URI is missing.",
                        null
                    )

                    return@setMethodCallHandler
                }

                if (
                    keyBytes == null ||
                    keyBytes.size != 32
                ) {

                    result.error(
                        "INVALID_KEY",
                        "AES-256 encryption key is missing or invalid.",
                        null
                    )

                    return@setMethodCallHandler
                }

                Log.d(
                    TAG,
                    "========== START DATASHIELD =========="
                )

                Log.d(
                    TAG,
                    "Pictures URI: $picturesUri"
                )

                Log.d(
                    TAG,
                    "DCIM URI: $dcimUri"
                )

                Log.d(
                    TAG,
                    "DEK size: ${keyBytes.size} bytes"
                )

                val started =
                    startDataShieldService(
                        picturesUri,
                        dcimUri,
                        keyBytes
                    )

                if (started) {

                    result.success(true)

                } else {

                    result.error(
                        "SERVICE_START_FAILED",
                        "Could not start DataShield service.",
                        null
                    )
                }
            }


            // =================================================
            // STOP DATASHIELD SERVICE
            // =================================================

            "stopService" -> {

                stopDataShieldService()

                result.success(true)
            }


            else -> {

                result.notImplemented()
            }
        }
    }


    // ========================================================
    // STORAGE CHANNEL
    // ========================================================

    MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        STORAGE_CHANNEL
    ).setMethodCallHandler { call, result ->

        when (call.method) {

            // =================================================
            // REQUEST BOTH PICTURES + DCIM
            // =================================================

            "requestMediaFolders" -> {

                if (pendingResult != null) {

                    result.error(
                        "PICKER_BUSY",
                        "A folder picker is already open.",
                        null
                    )

                    return@setMethodCallHandler
                }

                pendingResult = result

                val savedPictures =
                    getSavedPicturesUri()

                val savedDcim =
                    getSavedDcimUri()

                if (
                    hasPersistedPermission(
                        savedPictures
                    ) &&
                    hasPersistedPermission(
                        savedDcim
                    )
                ) {

                    Log.d(
                        TAG,
                        "Pictures and DCIM permissions already exist."
                    )

                    val response =
                        mapOf(
                            "picturesUri" to savedPictures,
                            "dcimUri" to savedDcim
                        )

                    pendingResult?.success(
                        response
                    )

                    pendingResult = null

                    return@setMethodCallHandler
                }

                openPicturesFolderPicker()
            }


            // =================================================
            // LEGACY PICTURES REQUEST
            // =================================================

            "requestPicturesFolder" -> {

                if (pendingResult != null) {

                    result.error(
                        "PICKER_BUSY",
                        "Folder picker is already open.",
                        null
                    )

                    return@setMethodCallHandler
                }

                pendingResult = result

                openPicturesFolderPicker()
            }


            // =================================================
            // GET SAVED PICTURES URI
            // =================================================

            "getPicturesFolderUri" -> {

                result.success(
                    getSavedPicturesUri()
                )
            }


            // =================================================
            // GET SAVED DCIM URI
            // =================================================

            "getDcimFolderUri" -> {

                result.success(
                    getSavedDcimUri()
                )
            }


            else -> {

                result.notImplemented()
            }
        }
    }


    // ========================================================
    // MEDIA RETRIEVAL CHANNEL
    // ========================================================

    MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        MEDIA_CHANNEL
    ).setMethodCallHandler { call, result ->

        when (call.method) {

            // =================================================
            // FIND ENCRYPTED FILES
            // =================================================

            "findEncryptedFiles" -> {

                val folderUriString =
                    call.argument<String>(
                        "folderUri"
                    )

                if (folderUriString.isNullOrEmpty()) {

                    result.error(
                        "NO_URI",
                        "Folder URI is missing.",
                        null
                    )

                    return@setMethodCallHandler
                }

                try {

                    val folderUri =
                        Uri.parse(
                            folderUriString
                        )

                    Log.d(
                        TAG,
                        "========== FIND USER ENCRYPTED MEDIA =========="
                    )

                    Log.d(
                        TAG,
                        "Root URI: $folderUri"
                    )

                    val files =
                        findEncryptedFiles(
                            folderUri
                        )

                    Log.d(
                        TAG,
                        "USER ENCRYPTED MEDIA FOUND: ${files.size}"
                    )

                    result.success(
                        files
                    )

                } catch (e: Exception) {

                    Log.e(
                        TAG,
                        "Failed to find encrypted files",
                        e
                    )

                    result.error(
                        "MEDIA_SEARCH_ERROR",
                        "Could not search encrypted media.",
                        e.message
                    )
                }
            }


            // =================================================
            // READ ENCRYPTED FILE
            //
            // IMPORTANT:
            // This reads RAW .dsenc bytes.
            //
            // NO DECRYPTION occurs here.
            //
            // Currently intended for testing smaller files.
            // Large video streaming will be implemented
            // separately.
            // =================================================

            "readEncryptedFile" -> {

                val uriString =
                    call.argument<String>(
                        "uri"
                    )

                if (uriString.isNullOrEmpty()) {

                    result.error(
                        "NO_URI",
                        "Encrypted file URI is missing.",
                        null
                    )

                    return@setMethodCallHandler
                }

                try {

                    val uri =
                        Uri.parse(
                            uriString
                        )

                    Log.d(
                        TAG,
                        "========== READ ENCRYPTED FILE =========="
                    )

                    Log.d(
                        TAG,
                        "URI: $uri"
                    )

                    val bytes =
                        contentResolver
                            .openInputStream(uri)
                            ?.use { input ->

                                input.readBytes()
                            }

                    if (bytes == null) {

                        result.error(
                            "READ_ERROR",
                            "Could not open encrypted file.",
                            null
                        )

                        return@setMethodCallHandler
                    }

                    Log.d(
                        TAG,
                        "Encrypted bytes read: ${bytes.size}"
                    )

                    // ------------------------------------------------
                    // IMPORTANT
                    // ------------------------------------------------
                    // These are RAW encrypted bytes.
                    //
                    // No AES key is used.
                    // No decryption occurs.
                    // ------------------------------------------------

                    result.success(
                        bytes
                    )

                } catch (e: Exception) {

                    Log.e(
                        TAG,
                        "Failed to read encrypted file",
                        e
                    )

                    result.error(
                        "READ_ERROR",
                        "Could not read encrypted file.",
                        e.message
                    )
                }
            }


            else -> {

                result.notImplemented()
            }
        }
    }


    // ========================================================
    // ENCRYPTION CHANNEL
    // ========================================================

    MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        ENCRYPTION_CHANNEL
    ).setMethodCallHandler { call, result ->

        when (call.method) {

            // =================================================
            // ENCRYPT FOLDER
            // =================================================

            "encryptFolder" -> {

                val uriString =
                    call.argument<String>(
                        "uri"
                    )

                val keyBytes =
                    call.argument<ByteArray>(
                        "key"
                    )

                if (uriString.isNullOrEmpty()) {

                    result.error(
                        "NO_URI",
                        "Folder URI is missing.",
                        null
                    )

                    return@setMethodCallHandler
                }

                if (
                    keyBytes == null ||
                    keyBytes.size != 32
                ) {

                    result.error(
                        "NO_KEY",
                        "AES-256 encryption key is missing or invalid.",
                        null
                    )

                    return@setMethodCallHandler
                }

                try {

                    Log.d(
                        TAG,
                        "Encrypting folder: $uriString"
                    )

                    EncryptionManager.encryptFolder(
                        this,
                        Uri.parse(uriString),
                        keyBytes
                    )

                    result.success(
                        true
                    )

                } catch (e: Exception) {

                    Log.e(
                        TAG,
                        "Folder encryption failed",
                        e
                    )

                    result.error(
                        "ENCRYPTION_ERROR",
                        "Failed to encrypt folder.",
                        e.message
                    )
                }
            }


            // =================================================
            // GET ENCRYPTED MEDIA
            // =================================================

            "getEncryptedMedia" -> {

                val picturesUriString =
                    call.argument<String>(
                        "picturesUri"
                    )

                val dcimUriString =
                    call.argument<String>(
                        "dcimUri"
                    )

                if (
                    picturesUriString.isNullOrEmpty() &&
                    dcimUriString.isNullOrEmpty()
                ) {

                    result.error(
                        "NO_URI",
                        "Pictures and DCIM folder URIs are missing.",
                        null
                    )

                    return@setMethodCallHandler
                }

                try {

                    val picturesUri =
                        picturesUriString
                            ?.takeIf {
                                it.isNotEmpty()
                            }
                            ?.let {
                                Uri.parse(it)
                            }

                    val dcimUri =
                        dcimUriString
                            ?.takeIf {
                                it.isNotEmpty()
                            }
                            ?.let {
                                Uri.parse(it)
                            }

                    Log.d(
                        TAG,
                        "Getting encrypted media from Pictures + DCIM"
                    )

                    Log.d(
                        TAG,
                        "Pictures URI: $picturesUri"
                    )

                    Log.d(
                        TAG,
                        "DCIM URI: $dcimUri"
                    )

                    val files =
                        DecryptionManager.getEncryptedMedia(
                            this,
                            picturesUri,
                            dcimUri
                        )

                    Log.d(
                        TAG,
                        "Encrypted media found: ${files.size}"
                    )

                    result.success(
                        files
                    )

                } catch (e: Exception) {

                    Log.e(
                        TAG,
                        "Failed to retrieve encrypted media",
                        e
                    )

                    result.error(
                        "DECRYPTION_ERROR",
                        "Could not retrieve encrypted media.",
                        e.message
                    )
                }
            }


            // =================================================
            // DECRYPT IMAGE
            // =================================================

            "decryptImage" -> {

                val uriString =
                    call.argument<String>(
                        "uri"
                    )

                val keyBytes =
                    call.argument<ByteArray>(
                        "key"
                    )

                if (uriString.isNullOrEmpty()) {

                    result.error(
                        "NO_URI",
                        "Encrypted file URI is missing.",
                        null
                    )

                    return@setMethodCallHandler
                }

                if (
                    keyBytes == null ||
                    keyBytes.size != 32
                ) {

                    result.error(
                        "NO_KEY",
                        "AES-256 decryption key is missing or invalid.",
                        null
                    )

                    return@setMethodCallHandler
                }

                try {

                    val encryptedUri =
                        Uri.parse(
                            uriString
                        )

                    Log.d(
                        TAG,
                        "========== DECRYPT IMAGE =========="
                    )

                    Log.d(
                        TAG,
                        "URI: $encryptedUri"
                    )

                    val decryptedBytes =
                        DecryptionEngine.decryptImage(
                            this,
                            encryptedUri,
                            keyBytes
                        )

                    if (decryptedBytes == null) {

                        result.error(
                            "DECRYPTION_ERROR",
                            "Failed to decrypt encrypted image.",
                            null
                        )

                        return@setMethodCallHandler
                    }

                    Log.d(
                        TAG,
                        "Image decrypted successfully."
                    )

                    Log.d(
                        TAG,
                        "Bytes: ${decryptedBytes.size}"
                    )

                    result.success(
                        decryptedBytes
                    )

                } catch (e: Exception) {

                    Log.e(
                        TAG,
                        "File decryption failed",
                        e
                    )

                    result.error(
                        "DECRYPTION_ERROR",
                        "Failed to decrypt file.",
                        e.message
                    )
                }
            }


            // =================================================
            // DECRYPT VIDEO / MEDIA TO TEMP FILE
            // =================================================

            "decryptToTempFile" -> {

                val uriString =
                    call.argument<String>(
                        "uri"
                    )

                val fileName =
                    call.argument<String>(
                        "name"
                    )

                val keyBytes =
                    call.argument<ByteArray>(
                        "key"
                    )

                if (uriString.isNullOrEmpty()) {

                    result.error(
                        "NO_URI",
                        "Encrypted file URI is missing.",
                        null
                    )

                    return@setMethodCallHandler
                }

                if (
                    keyBytes == null ||
                    keyBytes.size != 32
                ) {

                    result.error(
                        "INVALID_KEY",
                        "AES-256 decryption key is missing or invalid.",
                        null
                    )

                    return@setMethodCallHandler
                }

                try {

                    val encryptedUri =
                        Uri.parse(
                            uriString
                        )

                    Log.d(
                        TAG,
                        "========== DECRYPT MEDIA TO TEMP =========="
                    )

                    Log.d(
                        TAG,
                        "URI: $encryptedUri"
                    )

                    Log.d(
                        TAG,
                        "Name: $fileName"
                    )

                    val tempFile =
                        DecryptionEngine.decryptToFile(
                            this,
                            encryptedUri,
                            fileName,
                            keyBytes
                        )

                    if (tempFile == null) {

                        result.error(
                            "DECRYPTION_ERROR",
                            "Could not decrypt media to temporary file.",
                            null
                        )

                        return@setMethodCallHandler
                    }

                    Log.d(
                        TAG,
                        "Temporary decrypted file created:"
                    )

                    Log.d(
                        TAG,
                        tempFile
                    )

                    result.success(
                        tempFile
                    )

                } catch (e: Exception) {

                    Log.e(
                        TAG,
                        "Failed to decrypt media to temporary file",
                        e
                    )

                    result.error(
                        "DECRYPTION_ERROR",
                        "Could not decrypt media.",
                        e.message
                    )
                }
            }

// =================================================
// GENERATE VIDEO THUMBNAIL
//
// IMPORTANT:
//
// DecryptionEngine.generateVideoThumbnail()
// now:
//
// 1. Decrypts the video ONCE
// 2. Extracts the thumbnail
// 3. Keeps the decrypted temporary MP4
// 4. Returns BOTH:
//      - thumbnailBytes
//      - videoPath
//
// Flutter will use videoPath later for playback,
// preventing a second decryption.
// =================================================

"generateVideoThumbnail" -> {

    val uriString =
        call.argument<String>(
            "uri"
        )

    val fileName =
        call.argument<String>(
            "name"
        )

    val keyBytes =
        call.argument<ByteArray>(
            "key"
        )

    if (uriString.isNullOrEmpty()) {

        result.error(
            "NO_URI",
            "Encrypted video URI is missing.",
            null
        )

        return@setMethodCallHandler
    }

    if (
        keyBytes == null ||
        keyBytes.size != 32
    ) {

        result.error(
            "INVALID_KEY",
            "AES-256 decryption key is missing or invalid.",
            null
        )

        return@setMethodCallHandler
    }

    try {

        val encryptedUri =
            Uri.parse(
                uriString
            )

        Log.d(
            TAG,
            "========== GENERATE VIDEO THUMBNAIL =========="
        )

        Log.d(
            TAG,
            "URI: $encryptedUri"
        )

        Log.d(
            TAG,
            "Name: $fileName"
        )

        // ------------------------------------------------
        // DECRYPT VIDEO ONCE + GENERATE THUMBNAIL
        //
        // The returned map contains:
        //
        // thumbnailBytes
        // videoPath
        // ------------------------------------------------

        val resultMap =
            DecryptionEngine.generateVideoThumbnail(
                this,
                encryptedUri,
                fileName,
                keyBytes
            )

        if (resultMap == null) {

            result.error(
                "THUMBNAIL_ERROR",
                "Could not generate video thumbnail.",
                null
            )

            return@setMethodCallHandler
        }

        // ------------------------------------------------
        // GET THUMBNAIL BYTES
        // ------------------------------------------------

        val thumbnailBytes =
            resultMap["thumbnailBytes"]

        // ------------------------------------------------
        // GET RETAINED DECRYPTED VIDEO PATH
        // ------------------------------------------------

        val videoPath =
            resultMap["videoPath"]

        if (
            thumbnailBytes !is ByteArray
        ) {

            Log.e(
                TAG,
                "Thumbnail bytes are missing or invalid."
            )

            result.error(
                "THUMBNAIL_ERROR",
                "Generated thumbnail data is invalid.",
                null
            )

            return@setMethodCallHandler
        }

        if (
            videoPath !is String ||
            videoPath.isEmpty()
        ) {

            Log.e(
                TAG,
                "Decrypted video path is missing or invalid."
            )

            result.error(
                "VIDEO_PATH_ERROR",
                "Decrypted video path is missing.",
                null
            )

            return@setMethodCallHandler
        }

        // ------------------------------------------------
        // LOG SUCCESS
        // ------------------------------------------------

        Log.d(
            TAG,
            "Video thumbnail generated successfully."
        )

        Log.d(
            TAG,
            "Thumbnail bytes: ${thumbnailBytes.size}"
        )

        Log.d(
            TAG,
            "Decrypted video path:"
        )

        Log.d(
            TAG,
            videoPath
        )

        Log.d(
            TAG,
            "Decrypted video is being kept for playback."
        )

        // ------------------------------------------------
        // RETURN BOTH RESULTS TO FLUTTER
        // ------------------------------------------------

        result.success(
            mapOf(
                "thumbnailBytes" to thumbnailBytes,
                "videoPath" to videoPath
            )
        )

    } catch (e: Exception) {

        Log.e(
            TAG,
            "Failed to generate video thumbnail",
            e
        )

        result.error(
            "THUMBNAIL_ERROR",
            "Could not generate video thumbnail.",
            e.message
        )
    }
}


            // =================================================
            // DELETE ENCRYPTED FILE
            // =================================================

            "deleteEncryptedImage" -> {

                val uriString =
                    call.argument<String>(
                        "uri"
                    )

                if (uriString.isNullOrEmpty()) {

                    result.error(
                        "NO_URI",
                        "Encrypted file URI is missing.",
                        null
                    )

                    return@setMethodCallHandler
                }

                try {

                    val uri =
                        Uri.parse(
                            uriString
                        )

                    Log.d(
                        TAG,
                        "Deleting encrypted file:"
                    )

                    Log.d(
                        TAG,
                        uri.toString()
                    )

                    val deleted =
                        DocumentsContract.deleteDocument(
                            contentResolver,
                            uri
                        )

                    result.success(
                        deleted
                    )

                } catch (e: Exception) {

                    Log.e(
                        TAG,
                        "Failed to delete encrypted file",
                        e
                    )

                    result.error(
                        "DELETE_ERROR",
                        "Could not delete encrypted file.",
                        e.message
                    )
                }
            }


            else -> {

                result.notImplemented()
            }
        }
    }
}


// ============================================================
// FIND ENCRYPTED FILES RECURSIVELY
//
// IMPORTANT:
// Only DataShield-encrypted media files are returned.
//
// A valid file must:
//
// photo.jpg.dsenc
// image.png.dsenc
// video.mp4.dsenc
//
// Files such as:
//
// .dsenc
// 39.dsenc
// 0x0.dsenc
//
// are ignored.
// ============================================================

private fun findEncryptedFiles(
    rootUri: Uri
): List<Map<String, Any>> {

    val encryptedFiles =
        mutableListOf<Map<String, Any>>()

    try {

        val root =
            DocumentFile.fromTreeUri(
                this,
                rootUri
            )

        if (root == null) {

            Log.e(
                TAG,
                "Could not open root folder: $rootUri"
            )

            return encryptedFiles
        }

        if (!root.isDirectory) {

            Log.e(
                TAG,
                "Root URI is not a directory: $rootUri"
            )

            return encryptedFiles
        }

        scanDirectoryForEncryptedFiles(
            root,
            encryptedFiles
        )

    } catch (e: Exception) {

        Log.e(
            TAG,
            "Recursive encrypted file search failed",
            e
        )
    }

    return encryptedFiles
}


// ============================================================
// RECURSIVE DIRECTORY SCANNER
// ============================================================

private fun scanDirectoryForEncryptedFiles(
    directory: DocumentFile,
    encryptedFiles: MutableList<Map<String, Any>>
) {

    try {

        val children =
            directory.listFiles()

        for (file in children) {

            // ------------------------------------------------
            // DIRECTORY
            // ------------------------------------------------

            if (file.isDirectory) {

                val folderName =
                    file.name
                        ?.trim()
                        .orEmpty()

                // --------------------------------------------
                // SKIP SYSTEM / CACHE MEDIA DIRECTORIES
                // --------------------------------------------

                if (
                    isExcludedMediaFolder(
                        folderName
                    )
                ) {

                    Log.d(
                        TAG,
                        "Skipping excluded media folder: $folderName"
                    )

                    continue
                }

                scanDirectoryForEncryptedFiles(
                    file,
                    encryptedFiles
                )

                continue
            }


            // ------------------------------------------------
            // FILE
            // ------------------------------------------------

            if (!file.isFile) {
                continue
            }


            val name =
                file.name
                    ?.trim()
                    .orEmpty()


            if (name.isEmpty()) {
                continue
            }


            // ------------------------------------------------
            // ONLY .dsenc FILES
            // ------------------------------------------------

            if (
                !name.endsWith(
                    ".dsenc",
                    ignoreCase = true
                )
            ) {

                continue
            }


            // ------------------------------------------------
            // ONLY VALID ENCRYPTED MEDIA
            //
            // Examples accepted:
            //
            // photo.jpg.dsenc
            // image.png.dsenc
            // video.mp4.dsenc
            //
            // Examples rejected:
            //
            // .dsenc
            // 39.dsenc
            // 0x0.dsenc
            // random.dsenc
            // ------------------------------------------------

            if (
                !isEncryptedMediaFile(
                    name
                )
            ) {

                Log.d(
                    TAG,
                    "Skipping non-media encrypted file: $name"
                )

                continue
            }


            val uri =
                file.uri.toString()


            val size =
                try {

                    file.length()

                } catch (e: Exception) {

                    0L
                }


            // ------------------------------------------------
            // VALID USER ENCRYPTED MEDIA
            // ------------------------------------------------

            Log.d(
                TAG,
                "USER ENCRYPTED MEDIA FOUND:"
            )

            Log.d(
                TAG,
                "  Name: $name"
            )

            Log.d(
                TAG,
                "  URI: $uri"
            )

            Log.d(
                TAG,
                "  Size: $size bytes"
            )


            encryptedFiles.add(
                mapOf(
                    "name" to name,
                    "uri" to uri,
                    "size" to size
                )
            )
        }

    } catch (e: Exception) {

        Log.e(
            TAG,
            "Failed scanning directory: ${directory.uri}",
            e
        )
    }
}


// ============================================================
// CHECK WHETHER .DSENC IS ACTUALLY AN ENCRYPTED MEDIA FILE
// ============================================================

private fun isEncryptedMediaFile(
    fileName: String
): Boolean {

    val name =
        fileName.lowercase()


    // --------------------------------------------------------
    // MUST END WITH .DSENC
    // --------------------------------------------------------

    if (
        !name.endsWith(
            ".dsenc"
        )
    ) {

        return false
    }


    // --------------------------------------------------------
    // ORIGINAL MEDIA EXTENSIONS
    //
    // These match the extensions supported by
    // EncryptionManager.
    // --------------------------------------------------------

    val mediaExtensions =
        setOf(

            // Images
            ".jpg",
            ".jpeg",
            ".png",
            ".gif",
            ".webp",
            ".bmp",
            ".heic",
            ".heif",
            ".tif",
            ".tiff",

            // Videos
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


    // --------------------------------------------------------
    // VALID FORMAT:
    //
    // originalExtension + .dsenc
    //
    // photo.jpg.dsenc
    // video.mp4.dsenc
    // --------------------------------------------------------

    return mediaExtensions.any { extension ->

        name.endsWith(
            "$extension.dsenc"
        )
    }
}


// ============================================================
// EXCLUDED SYSTEM / CACHE MEDIA DIRECTORIES
// ============================================================

private fun isExcludedMediaFolder(
    folderName: String
): Boolean {

    val name =
        folderName
            .lowercase()
            .trim()


    return name in setOf(

        // Android/system thumbnail cache
        ".thumbnails",

        // Gallery cache/config
        ".gallery2",

        // Hidden gallery content
        "hiddenalbum"
    )
}


// ============================================================
// OPEN PICTURES FOLDER PICKER
// ============================================================

private fun openPicturesFolderPicker() {

    val intent =
        Intent(
            Intent.ACTION_OPEN_DOCUMENT_TREE
        ).apply {

            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                        Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
            )

            if (
                Build.VERSION.SDK_INT >=
                Build.VERSION_CODES.O
            ) {

                val picturesUri =
                    Uri.parse(
                        "content://com.android.externalstorage.documents/document/primary%3APictures"
                    )

                putExtra(
                    DocumentsContract.EXTRA_INITIAL_URI,
                    picturesUri
                )
            }
        }

    try {

        startActivityForResult(
            intent,
            PICK_PICTURES_REQUEST
        )

    } catch (e: Exception) {

        Log.e(
            TAG,
            "Failed to open Pictures picker",
            e
        )

        pendingResult?.error(
            "PICKER_ERROR",
            "Could not request Pictures folder access.",
            e.message
        )

        pendingResult = null
    }
}


// ============================================================
// OPEN DCIM FOLDER PICKER
// ============================================================

private fun openDcimFolderPicker() {

    val intent =
        Intent(
            Intent.ACTION_OPEN_DOCUMENT_TREE
        ).apply {

            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                        Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
            )

            if (
                Build.VERSION.SDK_INT >=
                Build.VERSION_CODES.O
            ) {

                val dcimUri =
                    Uri.parse(
                        "content://com.android.externalstorage.documents/document/primary%3ADCIM"
                    )

                putExtra(
                    DocumentsContract.EXTRA_INITIAL_URI,
                    dcimUri
                )
            }
        }

    try {

        startActivityForResult(
            intent,
            PICK_DCIM_REQUEST
        )

    } catch (e: Exception) {

        Log.e(
            TAG,
            "Failed to open DCIM picker",
            e
        )

        pendingResult?.error(
            "PICKER_ERROR",
            "Could not request DCIM folder access.",
            e.message
        )

        pendingResult = null
    }
}


// ============================================================
// START DATASHIELD SERVICE
// ============================================================

private fun startDataShieldService(
    picturesUri: String,
    dcimUri: String,
    keyBytes: ByteArray
): Boolean {

    if (picturesUri.isEmpty()) {

        Log.e(
            TAG,
            "Cannot start service: Pictures URI missing."
        )

        return false
    }

    if (dcimUri.isEmpty()) {

        Log.e(
            TAG,
            "Cannot start service: DCIM URI missing."
        )

        return false
    }

    if (keyBytes.size != 32) {

        Log.e(
            TAG,
            "Cannot start service: invalid DEK."
        )

        return false
    }


    // ========================================================
    // SAVE SESSION DEK
    // ========================================================

    val sessionSaved =
        SessionKeyStore.saveKey(
            this,
            keyBytes
        )

    if (!sessionSaved) {

        Log.e(
            TAG,
            "Could not save session DEK."
        )

        return false
    }


    // ========================================================
    // SAVE BOTH URIs
    // ========================================================

    savePicturesUri(
        picturesUri
    )

    saveDcimUri(
        dcimUri
    )


    // ========================================================
    // CREATE SERVICE INTENT
    // ========================================================

    val serviceIntent =
        Intent(
            this,
            DataShieldService::class.java
        ).apply {

            putExtra(
                EXTRA_PICTURES_URI,
                picturesUri
            )

            putExtra(
                EXTRA_DCIM_URI,
                dcimUri
            )

            putExtra(
                EXTRA_KEY,
                keyBytes
            )
        }


    // ========================================================
    // START FOREGROUND SERVICE
    // ========================================================

    return try {

        if (
            Build.VERSION.SDK_INT >=
            Build.VERSION_CODES.O
        ) {

            startForegroundService(
                serviceIntent
            )

        } else {

            startService(
                serviceIntent
            )
        }

        Log.d(
            TAG,
            "DataShield Pictures + DCIM service started."
        )

        true

    } catch (e: Exception) {

        Log.e(
            TAG,
            "Failed to start DataShield service",
            e
        )

        SessionKeyStore.clearSession(
            this
        )

        false
    }
}


// ============================================================
// STOP DATASHIELD SERVICE
// ============================================================

private fun stopDataShieldService() {

    Log.d(
        TAG,
        "========== STOP DATASHIELD =========="
    )

    try {

        stopService(
            Intent(
                this,
                DataShieldService::class.java
            )
        )

    } catch (e: Exception) {

        Log.e(
            TAG,
            "Failed to stop DataShield service",
            e
        )
    }

    SessionKeyStore.clearSession(
        this
    )

    Log.d(
        TAG,
        "DataShield service stopped."
    )
}


// ============================================================
// SAVE PICTURES URI
// ============================================================

private fun savePicturesUri(
    uri: String
) {

    getSharedPreferences(
        PREFS,
        MODE_PRIVATE
    )
        .edit()
        .putString(
            PICTURES_URI_KEY,
            uri
        )
        .apply()

    Log.d(
        TAG,
        "Pictures folder URI saved."
    )
}


// ============================================================
// SAVE DCIM URI
// ============================================================

private fun saveDcimUri(
    uri: String
) {

    getSharedPreferences(
        PREFS,
        MODE_PRIVATE
    )
        .edit()
        .putString(
            DCIM_URI_KEY,
            uri
        )
        .apply()

    Log.d(
        TAG,
        "DCIM folder URI saved."
    )
}


// ============================================================
// GET SAVED PICTURES URI
// ============================================================

private fun getSavedPicturesUri():
    String? {

    return getSharedPreferences(
        PREFS,
        MODE_PRIVATE
    )
        .getString(
            PICTURES_URI_KEY,
            null
        )
}


// ============================================================
// GET SAVED DCIM URI
// ============================================================

private fun getSavedDcimUri():
    String? {

    return getSharedPreferences(
        PREFS,
        MODE_PRIVATE
    )
        .getString(
            DCIM_URI_KEY,
            null
        )
}


// ============================================================
// CHECK PERSISTED SAF PERMISSION
// ============================================================

private fun hasPersistedPermission(
    uriString: String?
): Boolean {

    if (uriString.isNullOrEmpty()) {
        return false
    }

    val uri =
        Uri.parse(uriString)

    return contentResolver
        .persistedUriPermissions
        .any { permission ->

            permission.uri == uri &&
                    permission.isReadPermission &&
                    permission.isWritePermission
        }
}


// ============================================================
// FOLDER PICKER RESULT
// ============================================================

@Deprecated(
    "Deprecated in Java"
)
override fun onActivityResult(
    requestCode: Int,
    resultCode: Int,
    data: Intent?
) {

    super.onActivityResult(
        requestCode,
        resultCode,
        data
    )


    // --------------------------------------------------------
    // IGNORE UNRELATED RESULTS
    // --------------------------------------------------------

    if (
        requestCode != PICK_PICTURES_REQUEST &&
        requestCode != PICK_DCIM_REQUEST
    ) {

        return
    }


    // --------------------------------------------------------
    // USER CANCELLED
    // --------------------------------------------------------

    if (
        resultCode != Activity.RESULT_OK ||
        data == null
    ) {

        Log.d(
            TAG,
            "Folder picker cancelled."
        )

        pendingResult?.error(
            "PICKER_CANCELLED",
            if (
                requestCode ==
                PICK_PICTURES_REQUEST
            ) {

                "Pictures folder access was not granted."

            } else {

                "DCIM folder access was not granted."
            },
            null
        )

        pendingResult = null

        return
    }


    // --------------------------------------------------------
    // GET SELECTED URI
    // --------------------------------------------------------

    val uri =
        data.data

    if (uri == null) {

        Log.e(
            TAG,
            "Picker returned a null URI."
        )

        pendingResult?.error(
            "NULL_URI",
            "No folder was selected.",
            null
        )

        pendingResult = null

        return
    }


    try {

        // ====================================================
        // GET TREE DOCUMENT ID
        // ====================================================

        val treeDocumentId =
            DocumentsContract.getTreeDocumentId(
                uri
            )

        Log.d(
            TAG,
            "Selected tree document ID: $treeDocumentId"
        )


        // ====================================================
        // PICTURES RESULT
        // ====================================================

        if (
            requestCode ==
            PICK_PICTURES_REQUEST
        ) {

            if (
                treeDocumentId !=
                "primary:Pictures"
            ) {

                Log.e(
                    TAG,
                    "Invalid Pictures folder: $treeDocumentId"
                )

                pendingResult?.error(
                    "INVALID_FOLDER",
                    "Please select the Pictures folder.",
                    null
                )

                pendingResult = null

                return
            }


            // ------------------------------------------------
            // PERSIST PICTURES PERMISSION
            // ------------------------------------------------

            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            )

            savePicturesUri(
                uri.toString()
            )

            Log.d(
                TAG,
                "Pictures permission persisted."
            )


            // ------------------------------------------------
            // REQUEST DCIM
            // ------------------------------------------------

            openDcimFolderPicker()

            return
        }


        // ====================================================
        // DCIM RESULT
        // ====================================================

        if (
            requestCode ==
            PICK_DCIM_REQUEST
        ) {

            if (
                treeDocumentId !=
                "primary:DCIM"
            ) {

                Log.e(
                    TAG,
                    "Invalid DCIM folder: $treeDocumentId"
                )

                pendingResult?.error(
                    "INVALID_FOLDER",
                    "Please select the DCIM folder.",
                    null
                )

                pendingResult = null

                return
            }


            // ------------------------------------------------
            // PERSIST DCIM PERMISSION
            // ------------------------------------------------

            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            )

            saveDcimUri(
                uri.toString()
            )

            Log.d(
                TAG,
                "DCIM permission persisted."
            )

            Log.d(
                TAG,
                "Pictures URI: ${getSavedPicturesUri()}"
            )

            Log.d(
                TAG,
                "DCIM URI: ${getSavedDcimUri()}"
            )


            // ------------------------------------------------
            // RETURN BOTH URIs TO FLUTTER
            // ------------------------------------------------

            pendingResult?.success(
                mapOf(
                    "picturesUri" to
                            getSavedPicturesUri(),

                    "dcimUri" to
                            getSavedDcimUri()
                )
            )

            pendingResult = null
        }

    } catch (e: Exception) {

        Log.e(
            TAG,
            "Failed to process folder permission",
            e
        )

        pendingResult?.error(
            "PERMISSION_ERROR",
            "Could not persist folder permission.",
            e.message
        )

        pendingResult = null
    }
}


}

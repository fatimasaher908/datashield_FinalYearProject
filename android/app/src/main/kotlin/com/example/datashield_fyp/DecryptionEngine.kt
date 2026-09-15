package com.example.datashield_fyp

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.util.Log
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileInputStream
import javax.crypto.Cipher
import javax.crypto.CipherInputStream
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

object DecryptionEngine {

    private const val TAG = "DataShield"

    // ============================================================
    // DATASHIELD FILE FORMAT
    // ============================================================

    private const val HEADER = "DS01"

    private const val HEADER_SIZE = 4
    private const val IV_SIZE = 12
    private const val TAG_SIZE = 16

    private const val MIN_ENCRYPTED_SIZE =
        HEADER_SIZE + IV_SIZE + TAG_SIZE

    private const val BUFFER_SIZE = 64 * 1024


    // ============================================================
    // DECRYPT IMAGE
    // ============================================================

    fun decryptImage(
        context: Context,
        encryptedUri: Uri,
        keyBytes: ByteArray
    ): ByteArray? {

        return try {

            Log.d(TAG, "Decrypting image URI: $encryptedUri")

            // ----------------------------------------------------
            // VALIDATE KEY
            // ----------------------------------------------------

            if (keyBytes.size != 32) {

                Log.e(
                    TAG,
                    "Invalid AES-256 key size: ${keyBytes.size} bytes"
                )

                return null
            }

            // ----------------------------------------------------
            // READ ENCRYPTED FILE
            // ----------------------------------------------------

            val encryptedData =
                context.contentResolver
                    .openInputStream(encryptedUri)
                    ?.use { input ->
                        input.readBytes()
                    }
                    ?: run {

                        Log.e(
                            TAG,
                            "Unable to open encrypted URI: $encryptedUri"
                        )

                        return null
                    }

            Log.d(
                TAG,
                "Encrypted data size: ${encryptedData.size} bytes"
            )

            // ----------------------------------------------------
            // MINIMUM SIZE
            // ----------------------------------------------------

            if (encryptedData.size < MIN_ENCRYPTED_SIZE) {

                Log.e(
                    TAG,
                    "Encrypted file is too small"
                )

                return null
            }

            // ----------------------------------------------------
            // CHECK HEADER
            // ----------------------------------------------------

            val header =
                String(
                    encryptedData,
                    0,
                    HEADER_SIZE,
                    Charsets.UTF_8
                )

            if (header != HEADER) {

                Log.e(
                    TAG,
                    "Invalid DataShield header: $header"
                )

                return null
            }

            // ----------------------------------------------------
            // EXTRACT IV
            // ----------------------------------------------------

            val iv =
                encryptedData.copyOfRange(
                    HEADER_SIZE,
                    HEADER_SIZE + IV_SIZE
                )

            // ----------------------------------------------------
            // EXTRACT CIPHERTEXT + TAG
            // ----------------------------------------------------

            val cipherText =
                encryptedData.copyOfRange(
                    HEADER_SIZE + IV_SIZE,
                    encryptedData.size
                )

            // ----------------------------------------------------
            // AES-256 KEY
            // ----------------------------------------------------

            val secretKey =
                SecretKeySpec(
                    keyBytes,
                    "AES"
                )

            // ----------------------------------------------------
            // AES-GCM
            // ----------------------------------------------------

            val cipher =
                Cipher.getInstance(
                    "AES/GCM/NoPadding"
                )

            val gcmSpec =
                GCMParameterSpec(
                    128,
                    iv
                )

            cipher.init(
                Cipher.DECRYPT_MODE,
                secretKey,
                gcmSpec
            )

            // ----------------------------------------------------
            // DECRYPT
            // ----------------------------------------------------

            val originalBytes =
                cipher.doFinal(cipherText)

            Log.d(
                TAG,
                "Image decryption successful."
            )

            Log.d(
                TAG,
                "Recovered size: ${originalBytes.size} bytes"
            )

            originalBytes

        } catch (e: Exception) {

            Log.e(
                TAG,
                "Image decryption failed.",
                e
            )

            null
        }
    }


    // ============================================================
    // DECRYPT VIDEO TO TEMP FILE
    //
    // EXISTING WORKING METHOD
    //
    // This method is intentionally preserved.
    // ============================================================

    fun decryptToFile(
        context: Context,
        encryptedUri: Uri,
        originalName: String?,
        keyBytes: ByteArray
    ): String? {

        var outputFile: File? = null

        try {

            Log.d(
                TAG,
                "========== VIDEO DECRYPTION START =========="
            )

            Log.d(
                TAG,
                "Encrypted URI: $encryptedUri"
            )

            Log.d(
                TAG,
                "Decryption key size: ${keyBytes.size} bytes"
            )

            // ----------------------------------------------------
            // VALIDATE KEY
            // ----------------------------------------------------

            if (keyBytes.size != 32) {

                Log.e(
                    TAG,
                    "Invalid AES-256 key size: ${keyBytes.size} bytes"
                )

                return null
            }

            // ----------------------------------------------------
            // DETERMINE ORIGINAL FILE NAME
            // ----------------------------------------------------

            var safeOriginalName =
                originalName
                    ?.trim()
                    ?.takeIf { it.isNotEmpty() }
                    ?: "datashield_media"

            // ----------------------------------------------------
            // REMOVE .DSENC
            // ----------------------------------------------------

            if (
                safeOriginalName
                    .lowercase()
                    .endsWith(".dsenc")
            ) {

                safeOriginalName =
                    safeOriginalName
                        .dropLast(".dsenc".length)
            }

            // ----------------------------------------------------
            // SAFETY AGAINST PATH TRAVERSAL
            // ----------------------------------------------------

            safeOriginalName =
                File(safeOriginalName).name

            if (safeOriginalName.isBlank()) {

                safeOriginalName =
                    "datashield_media.mp4"
            }

            // ----------------------------------------------------
            // CREATE CACHE DIRECTORY
            // ----------------------------------------------------

            val cacheDirectory =
                File(
                    context.cacheDir,
                    "datashield_decrypted"
                )

            if (!cacheDirectory.exists()) {

                if (!cacheDirectory.mkdirs()) {

                    Log.e(
                        TAG,
                        "Could not create cache directory"
                    )

                    return null
                }
            }

            // ----------------------------------------------------
            // CREATE TEMPORARY FILE
            // ----------------------------------------------------

            outputFile =
                File(
                    cacheDirectory,
                    "${System.currentTimeMillis()}_$safeOriginalName"
                )

            Log.d(
                TAG,
                "Temporary output:"
            )

            Log.d(
                TAG,
                outputFile.absolutePath
            )

            // ----------------------------------------------------
            // OPEN ENCRYPTED FILE
            // ----------------------------------------------------

            val rawInput =
                context.contentResolver
                    .openInputStream(encryptedUri)

            if (rawInput == null) {

                Log.e(
                    TAG,
                    "Could not open encrypted input stream"
                )

                return null
            }

            rawInput.use { stream ->

                val input =
                    BufferedInputStream(
                        stream,
                        BUFFER_SIZE
                    )

                // ------------------------------------------------
                // READ HEADER
                // ------------------------------------------------

                val headerBytes =
                    ByteArray(HEADER_SIZE)

                readFully(
                    input,
                    headerBytes
                )

                val header =
                    String(
                        headerBytes,
                        Charsets.UTF_8
                    )

                Log.d(
                    TAG,
                    "Decryption header: $header"
                )

                if (header != HEADER) {

                    Log.e(
                        TAG,
                        "Invalid DataShield header"
                    )

                    return null
                }

                // ------------------------------------------------
                // READ IV
                // ------------------------------------------------

                val iv =
                    ByteArray(IV_SIZE)

                readFully(
                    input,
                    iv
                )

                Log.d(
                    TAG,
                    "Decryption IV: " +
                            iv.joinToString(" ") {
                                "%02X".format(it)
                            }
                )

                // ------------------------------------------------
                // AES-256 KEY
                // ------------------------------------------------

                val secretKey =
                    SecretKeySpec(
                        keyBytes,
                        "AES"
                    )

                // ------------------------------------------------
                // AES-GCM
                // ------------------------------------------------

                val cipher =
                    Cipher.getInstance(
                        "AES/GCM/NoPadding"
                    )

                val gcmSpec =
                    GCMParameterSpec(
                        128,
                        iv
                    )

                cipher.init(
                    Cipher.DECRYPT_MODE,
                    secretKey,
                    gcmSpec
                )

                // ------------------------------------------------
                // STREAM DECRYPTION
                // ------------------------------------------------

                CipherInputStream(
                    input,
                    cipher
                ).use { cipherInput ->

                    BufferedOutputStream(
                        outputFile.outputStream(),
                        BUFFER_SIZE
                    ).use { output ->

                        val buffer =
                            ByteArray(BUFFER_SIZE)

                        var totalDecrypted =
                            0L

                        while (true) {

                            val bytesRead =
                                cipherInput.read(buffer)

                            if (bytesRead == -1) {
                                break
                            }

                            if (bytesRead > 0) {

                                output.write(
                                    buffer,
                                    0,
                                    bytesRead
                                )

                                totalDecrypted +=
                                    bytesRead
                            }
                        }

                        output.flush()

                        Log.d(
                            TAG,
                            "Decrypted size: $totalDecrypted bytes"
                        )
                    }
                }
            }

            // ----------------------------------------------------
            // VERIFY OUTPUT
            // ----------------------------------------------------

            if (
                !outputFile.exists() ||
                outputFile.length() <= 0
            ) {

                Log.e(
                    TAG,
                    "Temporary decrypted file is invalid"
                )

                outputFile.delete()
                outputFile = null

                return null
            }

            Log.d(
                TAG,
                "Streaming decryption successful."
            )

            Log.d(
                TAG,
                "Output: ${outputFile.absolutePath}"
            )

            Log.d(
                TAG,
                "Output size: ${outputFile.length()} bytes"
            )

            // ----------------------------------------------------
            // VERIFY MP4 HEADER
            // ----------------------------------------------------

            try {

                FileInputStream(
                    outputFile
                ).use { fileInput ->

                    val header =
                        ByteArray(32)

                    val bytesRead =
                        fileInput.read(header)

                    if (bytesRead > 0) {

                        val hex =
                            header
                                .copyOf(bytesRead)
                                .joinToString(" ") {
                                    "%02X".format(it)
                                }

                        Log.d(
                            TAG,
                            "First decrypted bytes: $hex"
                        )

                        if (bytesRead >= 8) {

                            val boxType =
                                String(
                                    header,
                                    4,
                                    4,
                                    Charsets.US_ASCII
                                )

                            Log.d(
                                TAG,
                                "MP4 box type at offset 4: $boxType"
                            )

                            if (boxType != "ftyp") {

                                Log.w(
                                    TAG,
                                    "Unexpected MP4 box type: $boxType"
                                )
                            }
                        }
                    }
                }

            } catch (e: Exception) {

                Log.e(
                    TAG,
                    "Could not inspect decrypted file",
                    e
                )
            }

            Log.d(
                TAG,
                "========== VIDEO DECRYPTION SUCCESS =========="
            )

            return outputFile.absolutePath

        } catch (e: Exception) {

            Log.e(
                TAG,
                "========== VIDEO DECRYPTION FAILED ==========",
                e
            )

            try {
                outputFile?.delete()
            } catch (deleteException: Exception) {

                Log.e(
                    TAG,
                    "Could not delete partial temp file.",
                    deleteException
                )
            }

            return null
        }
    }


// ============================================================
// GENERATE VIDEO THUMBNAIL + KEEP DECRYPTED VIDEO
//
// IMPORTANT:
//
// The video is decrypted ONLY ONCE.
//
// Flow:
//
// encrypted .dsenc
//       ↓
// decryptToFile()
//       ↓
// temporary .mp4
//       ↓
// MediaMetadataRetriever
//       ├── thumbnail JPEG
//       │
//       └── KEEP temporary .mp4
//
// The method returns BOTH:
//
// "thumbnailBytes" → JPEG thumbnail for Flutter
// "videoPath"     → decrypted MP4 for playback
//
// The temporary video is intentionally NOT deleted here.
// ============================================================

fun generateVideoThumbnail(
    context: Context,
    encryptedUri: Uri,
    originalName: String?,
    keyBytes: ByteArray
): Map<String, Any>? {

    var temporaryVideoPath: String? = null
    var bitmap: Bitmap? = null
    var scaledBitmap: Bitmap? = null

    val retriever =
        MediaMetadataRetriever()

    try {

        Log.d(
            TAG,
            "========== VIDEO THUMBNAIL + DECRYPT START =========="
        )

        Log.d(
            TAG,
            "Encrypted URI: $encryptedUri"
        )

        // ----------------------------------------------------
        // VALIDATE KEY
        // ----------------------------------------------------

        if (keyBytes.size != 32) {

            Log.e(
                TAG,
                "Invalid AES-256 key size for thumbnail: ${keyBytes.size}"
            )

            return null
        }

        // ----------------------------------------------------
        // DECRYPT VIDEO ONCE
        // ----------------------------------------------------

        temporaryVideoPath =
            decryptToFile(
                context,
                encryptedUri,
                originalName,
                keyBytes
            )

        if (temporaryVideoPath.isNullOrEmpty()) {

            Log.e(
                TAG,
                "Could not decrypt video for thumbnail."
            )

            return null
        }

        val temporaryVideo =
            File(
                temporaryVideoPath
            )

        if (!temporaryVideo.exists() ||
            temporaryVideo.length() <= 0
        ) {

            Log.e(
                TAG,
                "Temporary decrypted video is invalid."
            )

            temporaryVideo.delete()
            temporaryVideoPath = null

            return null
        }

        Log.d(
            TAG,
            "Decrypted video created successfully."
        )

        Log.d(
            TAG,
            "Temporary video path:"
        )

        Log.d(
            TAG,
            temporaryVideo.absolutePath
        )

        Log.d(
            TAG,
            "Temporary video size: ${temporaryVideo.length()} bytes"
        )

        // ----------------------------------------------------
        // SET VIDEO SOURCE
        // ----------------------------------------------------

        retriever.setDataSource(
            temporaryVideo.absolutePath
        )

        // ----------------------------------------------------
        // EXTRACT FIRST KEYFRAME
        // ----------------------------------------------------

        bitmap =
            retriever.getFrameAtTime(
                0L,
                MediaMetadataRetriever
                    .OPTION_CLOSEST_SYNC
            )

        if (bitmap == null) {

            Log.e(
                TAG,
                "MediaMetadataRetriever returned NULL frame."
            )

            temporaryVideo.delete()
            temporaryVideoPath = null

            return null
        }

        Log.d(
            TAG,
            "Video frame extracted successfully."
        )

        Log.d(
            TAG,
            "Original thumbnail size: " +
                    "${bitmap.width}x${bitmap.height}"
        )

        // ----------------------------------------------------
        // SCALE THUMBNAIL
        // ----------------------------------------------------

        scaledBitmap =
            scaleBitmapForThumbnail(
                bitmap,
                600
            )

        // ----------------------------------------------------
        // COMPRESS TO JPEG
        // ----------------------------------------------------

        val outputStream =
            ByteArrayOutputStream()

        scaledBitmap.compress(
            Bitmap.CompressFormat.JPEG,
            85,
            outputStream
        )

        val thumbnailBytes =
            outputStream.toByteArray()

        outputStream.close()

        Log.d(
            TAG,
            "Thumbnail JPEG size: " +
                    "${thumbnailBytes.size} bytes"
        )

        if (thumbnailBytes.isEmpty()) {

            Log.e(
                TAG,
                "Generated thumbnail is empty."
            )

            temporaryVideo.delete()
            temporaryVideoPath = null

            return null
        }

        // ----------------------------------------------------
        // IMPORTANT
        //
        // DO NOT DELETE THE DECRYPTED VIDEO.
        //
        // Gallery needs this exact file later when the user
        // taps the video.
        // ----------------------------------------------------

        Log.d(
            TAG,
            "Keeping decrypted video for playback."
        )

        Log.d(
            TAG,
            "Video path returned to Flutter:"
        )

        Log.d(
            TAG,
            temporaryVideo.absolutePath
        )

        Log.d(
            TAG,
            "========== VIDEO THUMBNAIL + DECRYPT SUCCESS =========="
        )

        // ----------------------------------------------------
        // RETURN BOTH RESULTS
        // ----------------------------------------------------

        return mapOf(
            "thumbnailBytes" to thumbnailBytes,
            "videoPath" to temporaryVideo.absolutePath
        )

    } catch (e: Exception) {

        Log.e(
            TAG,
            "========== VIDEO THUMBNAIL + DECRYPT FAILED ==========",
            e
        )

        // ----------------------------------------------------
        // DELETE ONLY IF THE OPERATION FAILED.
        //
        // If thumbnail generation succeeds, the file is kept.
        // ----------------------------------------------------

        if (!temporaryVideoPath.isNullOrEmpty()) {

            try {

                val temporaryFile =
                    File(
                        temporaryVideoPath
                    )

                if (temporaryFile.exists()) {

                    temporaryFile.delete()

                    Log.d(
                        TAG,
                        "Deleted temporary video after failure."
                    )
                }

            } catch (deleteException: Exception) {

                Log.e(
                    TAG,
                    "Failed to delete temporary video after failure.",
                    deleteException
                )
            }
        }

        return null

    } finally {

        // ----------------------------------------------------
        // RELEASE RETRIEVER
        // ----------------------------------------------------

        try {

            retriever.release()

        } catch (e: Exception) {

            Log.e(
                TAG,
                "Failed to release MediaMetadataRetriever",
                e
            )
        }

        // ----------------------------------------------------
        // RECYCLE SCALED BITMAP IF IT IS A DIFFERENT OBJECT
        // ----------------------------------------------------

        try {

            if (
                scaledBitmap != null &&
                scaledBitmap !== bitmap &&
                !scaledBitmap.isRecycled
            ) {
                scaledBitmap.recycle()
            }

        } catch (e: Exception) {

            Log.e(
                TAG,
                "Failed to recycle scaled thumbnail bitmap",
                e
            )
        }

        // ----------------------------------------------------
        // RECYCLE ORIGINAL BITMAP
        // ----------------------------------------------------

        try {

            if (
                bitmap != null &&
                !bitmap.isRecycled
            ) {
                bitmap.recycle()
            }

        } catch (e: Exception) {

            Log.e(
                TAG,
                "Failed to recycle thumbnail bitmap",
                e
            )
        }

        // ----------------------------------------------------
        // DO NOT DELETE temporaryVideoPath HERE.
        //
        // On SUCCESS:
        //     the decrypted MP4 must remain available.
        //
        // On FAILURE:
        //     the catch block already deletes it.
        // ----------------------------------------------------
    }
}


    // ============================================================
    // SCALE BITMAP FOR THUMBNAIL
    // ============================================================

    private fun scaleBitmapForThumbnail(
        bitmap: Bitmap,
        maxDimension: Int
    ): Bitmap {

        val width =
            bitmap.width

        val height =
            bitmap.height

        if (
            width <= maxDimension &&
            height <= maxDimension
        ) {

            return bitmap
        }

        val scale =
            minOf(
                maxDimension.toFloat() / width,
                maxDimension.toFloat() / height
            )

        val newWidth =
            (width * scale)
                .toInt()
                .coerceAtLeast(1)

        val newHeight =
            (height * scale)
                .toInt()
                .coerceAtLeast(1)

        return Bitmap.createScaledBitmap(
            bitmap,
            newWidth,
            newHeight,
            true
        )
    }


    // ============================================================
    // READ EXACT NUMBER OF BYTES
    // ============================================================

    private fun readFully(
        input: BufferedInputStream,
        buffer: ByteArray
    ) {

        var offset = 0

        while (offset < buffer.size) {

            val count =
                input.read(
                    buffer,
                    offset,
                    buffer.size - offset
                )

            if (count == -1) {

                throw IllegalStateException(
                    "Unexpected end of encrypted file"
                )
            }

            offset += count
        }
    }
}
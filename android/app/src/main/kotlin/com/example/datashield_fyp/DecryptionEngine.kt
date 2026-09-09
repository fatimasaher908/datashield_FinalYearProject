package com.example.datashield_fyp

import android.content.Context
import android.net.Uri
import android.util.Log
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.File
import javax.crypto.Cipher
import javax.crypto.CipherInputStream
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec
import java.io.FileInputStream

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
    //
    // IMPORTANT:
    // This version accepts Uri directly.
    //
    // We intentionally DO NOT use DocumentFile.fromSingleUri()
    // here because some SAF providers can return a null cursor
    // when DocumentFile queries a child document.
    // ============================================================

    fun decryptImage(
        context: Context,
        encryptedUri: Uri,
        keyBytes: ByteArray
    ): ByteArray? {

        return try {

            Log.d(
                TAG,
                "Decrypting image URI: $encryptedUri"
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
            // OPEN ENCRYPTED FILE DIRECTLY
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
                            "Unable to open encrypted URI:"
                        )

                        Log.e(
                            TAG,
                            encryptedUri.toString()
                        )

                        return null
                    }

            Log.d(
                TAG,
                "Encrypted data size: ${encryptedData.size} bytes"
            )

            // ----------------------------------------------------
            // CHECK MINIMUM SIZE
            // ----------------------------------------------------

            if (
                encryptedData.size <
                MIN_ENCRYPTED_SIZE
            ) {

                Log.e(
                    TAG,
                    "Encrypted file is corrupted or too short"
                )

                return null
            }

            // ----------------------------------------------------
            // CHECK DATASHIELD HEADER
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
                    "Invalid DataShield file format"
                )

                Log.e(
                    TAG,
                    "Expected header: $HEADER"
                )

                Log.e(
                    TAG,
                    "Actual header: $header"
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
            // EXTRACT CIPHERTEXT + GCM TAG
            // ----------------------------------------------------

            val cipherText =
                encryptedData.copyOfRange(
                    HEADER_SIZE + IV_SIZE,
                    encryptedData.size
                )

            // ----------------------------------------------------
            // CREATE AES-256 KEY
            // ----------------------------------------------------

            val secretKey =
                SecretKeySpec(
                    keyBytes,
                    "AES"
                )

            // ----------------------------------------------------
            // CREATE AES-GCM CIPHER
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
                cipher.doFinal(
                    cipherText
                )

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
                "Image decryption failed."
            )

            Log.e(
                TAG,
                "URI: $encryptedUri"
            )

            Log.e(
                TAG,
                "Reason: ${e.message}",
                e
            )

            null
        }
    }


    // ============================================================
    // DECRYPT TO TEMPORARY FILE
    //
    // Used for videos.
    //
    // The encrypted file is never modified.
    //
    // Output:
    //
    // cache/datashield_decrypted/
    //
    // The original extension is preserved so video_player can
    // recognize the media format.
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
                "Starting streaming decryption."
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
                    "Invalid AES-256 key size: ${keyBytes.size} bytes"
                )

                return null
            }

            // ----------------------------------------------------
            // GET ORIGINAL NAME
            // ----------------------------------------------------

            val safeOriginalName =
                originalName
                    ?.takeIf { it.isNotBlank() }
                    ?: "datashield_media"

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
            // CREATE UNIQUE TEMP FILE
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
            // OPEN ENCRYPTED INPUT DIRECTLY
            //
            // IMPORTANT:
            // No DocumentFile query here.
            // ----------------------------------------------------

            val inputStream =
                context.contentResolver
                    .openInputStream(encryptedUri)

            if (inputStream == null) {

                Log.e(
                    TAG,
                    "Could not open encrypted input stream"
                )

                return null
            }

            inputStream.use { rawInput ->

                val input =
                    BufferedInputStream(
                        rawInput,
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

                if (header != HEADER) {

                    Log.e(
                        TAG,
                        "Invalid DataShield header: $header"
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

                // ------------------------------------------------
                // CREATE AES-GCM CIPHER
                // ------------------------------------------------

                val secretKey =
                    SecretKeySpec(
                        keyBytes,
                        "AES"
                    )

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
                            "Decrypted $totalDecrypted bytes"
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

// ============================================================
// VERIFY DECRYPTED MP4 HEADER
// ============================================================

try {

    FileInputStream(outputFile).use { input ->

        val header = ByteArray(32)

        val bytesRead = input.read(header)

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

return outputFile.absolutePath

      

        } catch (e: Exception) {

            Log.e(
                TAG,
                "Streaming decryption failed.",
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
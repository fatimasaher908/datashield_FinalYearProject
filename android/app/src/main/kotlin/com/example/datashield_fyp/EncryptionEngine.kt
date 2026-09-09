package com.example.datashield_fyp

import android.content.Context
import android.util.Log
import androidx.documentfile.provider.DocumentFile
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.CipherOutputStream
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

object EncryptionEngine {

    private const val TAG = "DataShield"

    // DataShield encrypted file header
    private const val HEADER = "DS01"

    // AES-GCM recommended IV length
    private const val IV_LENGTH = 12

    // AES-GCM authentication tag length
    private const val TAG_LENGTH = 128

    // Buffer used for streaming file encryption
    private const val BUFFER_SIZE = 64 * 1024

    /**
     * Encrypt any supported file using AES-GCM.
     *
     * Output format:
     *
     * DS01
     * + 12-byte IV
     * + encrypted data
     * + GCM authentication tag
     *
     * Output filename:
     *
     * originalName.ext.dsenc
     *
     * The original file is NOT deleted here.
     * FolderMonitor deletes it only after successful encryption.
     */
    fun encryptFile(
        context: Context,
        file: DocumentFile,
        parent: DocumentFile,
        keyBytes: ByteArray
    ): DocumentFile? {

        var encryptedFile: DocumentFile? = null

        try {

            // ====================================================
            // VALIDATE FILE
            // ====================================================

            if (!file.exists()) {

                Log.e(
                    TAG,
                    "File does not exist: ${file.name}"
                )

                return null
            }

            if (!file.isFile) {

                Log.e(
                    TAG,
                    "Not a file: ${file.name}"
                )

                return null
            }

            if (keyBytes.isEmpty()) {

                Log.e(
                    TAG,
                    "Encryption key is empty."
                )

                return null
            }

            // AES-128/192/256 are supported.
            // DataShield expects AES-256.
            if (keyBytes.size != 32) {

                Log.e(
                    TAG,
                    "Invalid AES-256 key length: ${keyBytes.size} bytes"
                )

                return null
            }

            val originalName =
                file.name ?: return null

            // ====================================================
            // NEVER ENCRYPT .DSENC
            // ====================================================

            if (
                originalName.endsWith(
                    ".dsenc",
                    ignoreCase = true
                )
            ) {

                Log.d(
                    TAG,
                    "Skipping already encrypted file: $originalName"
                )

                return null
            }

            // ====================================================
            // CHECK SOURCE FILE SIZE
            // ====================================================

            val originalLength =
                file.length()

            if (originalLength <= 0) {

                Log.d(
                    TAG,
                    "Skipping empty file: $originalName"
                )

                return null
            }

            Log.d(
                TAG,
                "Starting encryption:"
            )

            Log.d(
                TAG,
                "File: $originalName"
            )

            Log.d(
                TAG,
                "Size: $originalLength bytes"
            )

            // ====================================================
            // GENERATE RANDOM IV
            // ====================================================

            val iv =
                ByteArray(IV_LENGTH)

            SecureRandom().nextBytes(iv)

            // ====================================================
            // CREATE AES-GCM CIPHER
            // ====================================================

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
                    TAG_LENGTH,
                    iv
                )

            cipher.init(
                Cipher.ENCRYPT_MODE,
                secretKey,
                gcmSpec
            )

            // ====================================================
            // CREATE ENCRYPTED FILE
            // ====================================================

            val encryptedName =
                "$originalName.dsenc"

            encryptedFile =
                parent.createFile(
                    "application/octet-stream",
                    encryptedName
                )

            if (encryptedFile == null) {

                Log.e(
                    TAG,
                    "Could not create encrypted file: $encryptedName"
                )

                return null
            }

            // ====================================================
            // OPEN INPUT STREAM
            // ====================================================

            val inputStream =
                context.contentResolver.openInputStream(
                    file.uri
                )

            if (inputStream == null) {

                Log.e(
                    TAG,
                    "Could not open input stream: $originalName"
                )

                encryptedFile.delete()
                encryptedFile = null

                return null
            }

            // ====================================================
            // OPEN OUTPUT STREAM
            // ====================================================

            val outputStream =
                context.contentResolver.openOutputStream(
                    encryptedFile.uri,
                    "w"
                )

            if (outputStream == null) {

                Log.e(
                    TAG,
                    "Could not open output stream: $encryptedName"
                )

                inputStream.close()
                encryptedFile.delete()
                encryptedFile = null

                return null
            }

            // ====================================================
            // STREAM ENCRYPTION
            // ====================================================

            inputStream.use { input ->

                outputStream.use { output ->

                    val bufferedInput =
                        BufferedInputStream(
                            input,
                            BUFFER_SIZE
                        )

                    val bufferedOutput =
                        BufferedOutputStream(
                            output,
                            BUFFER_SIZE
                        )

                    // ------------------------------------------------
                    // WRITE HEADER
                    // ------------------------------------------------

                    bufferedOutput.write(
                        HEADER.toByteArray(
                            Charsets.UTF_8
                        )
                    )

                    // ------------------------------------------------
                    // WRITE IV
                    // ------------------------------------------------

                    bufferedOutput.write(iv)

                    bufferedOutput.flush()

                    // ------------------------------------------------
                    // AES-GCM STREAM
                    // ------------------------------------------------

                    val cipherOutput =
                        CipherOutputStream(
                            bufferedOutput,
                            cipher
                        )

                    cipherOutput.use { encryptedOutput ->

                        val buffer =
                            ByteArray(BUFFER_SIZE)

                        var totalRead = 0L

                        while (true) {

                            val bytesRead =
                                bufferedInput.read(
                                    buffer
                                )

                            if (bytesRead == -1) {
                                break
                            }

                            if (bytesRead > 0) {

                                encryptedOutput.write(
                                    buffer,
                                    0,
                                    bytesRead
                                )

                                totalRead += bytesRead
                            }
                        }

                        encryptedOutput.flush()

                        Log.d(
                            TAG,
                            "Encrypted $totalRead bytes: $originalName"
                        )
                    }
                }
            }

            // ====================================================
            // VERIFY ENCRYPTED FILE
            // ====================================================

            if (
                !encryptedFile.exists() ||
                encryptedFile.length() <= 0
            ) {

                Log.e(
                    TAG,
                    "Encrypted file was not created correctly: $encryptedName"
                )

                encryptedFile.delete()
                encryptedFile = null

                return null
            }

            Log.d(
                TAG,
                "Encryption successful:"
            )

            Log.d(
                TAG,
                "$originalName -> $encryptedName"
            )

            Log.d(
                TAG,
                "Encrypted size: ${encryptedFile.length()} bytes"
            )

            return encryptedFile

        } catch (e: Exception) {

            Log.e(
                TAG,
                "Encryption failed: ${file.name}",
                e
            )

            // ----------------------------------------------------
            // DELETE PARTIAL ENCRYPTED FILE
            // ----------------------------------------------------

            try {

                encryptedFile?.delete()

            } catch (deleteException: Exception) {

                Log.e(
                    TAG,
                    "Could not delete incomplete encrypted file",
                    deleteException
                )
            }

            return null
        }
    }

    /**
     * Backwards-compatible image encryption method.
     */
    fun encryptImage(
        context: Context,
        file: DocumentFile,
        parent: DocumentFile,
        keyBytes: ByteArray
    ): DocumentFile? {

        return encryptFile(
            context,
            file,
            parent,
            keyBytes
        )
    }
}
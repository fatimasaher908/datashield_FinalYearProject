package com.example.datashield_fyp

import android.content.Context
import android.util.Log
import androidx.documentfile.provider.DocumentFile
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.security.KeyStore
import java.security.MessageDigest
import java.security.cert.CertificateFactory
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.SSLContext
import javax.net.ssl.TrustManagerFactory

object MediaRegistrationService {

    private const val TAG = "MediaRegistration"

    private const val BASE_URL =
        "https://192.168.137.1:8383"

    private const val REGISTER_ENDPOINT =
        "/media/register"

    private const val AUTH_PREFS =
        "datashield_native_auth"

    private const val JWT_KEY =
        "jwt_token"

    // ============================================================
    // REGISTER FILE
    // ============================================================

    suspend fun registerFile(
        context: Context,
        originalName: String,
        encryptedFile: DocumentFile,
        mimeType: String
    ): Boolean = withContext(Dispatchers.IO) {

        try {

            Log.d(TAG, "========================================")
            Log.d(TAG, "REGISTERING ENCRYPTED FILE")
            Log.d(TAG, "Original name: $originalName")
            Log.d(TAG, "Encrypted name: ${encryptedFile.name}")
            Log.d(TAG, "MIME type: $mimeType")
            Log.d(TAG, "========================================")

            // ----------------------------------------------------
            // 1. GET JWT
            // ----------------------------------------------------

            val jwt =
                context
                    .getSharedPreferences(
                        AUTH_PREFS,
                        Context.MODE_PRIVATE
                    )
                    .getString(
                        JWT_KEY,
                        null
                    )

            if (jwt.isNullOrEmpty()) {

                Log.e(
                    TAG,
                    "JWT NOT FOUND - file cannot be registered"
                )

                return@withContext false
            }

            Log.d(
                TAG,
                "JWT found"
            )

            // ----------------------------------------------------
            // 2. CHECK ENCRYPTED FILE
            // ----------------------------------------------------

            if (!encryptedFile.exists()) {

                Log.e(
                    TAG,
                    "Encrypted file does not exist"
                )

                return@withContext false
            }

            // ----------------------------------------------------
            // 3. GET ENCRYPTED FILE SIZE
            // ----------------------------------------------------

            val fileSize =
                encryptedFile.length()

            Log.d(
                TAG,
                "Encrypted file size: $fileSize"
            )

            if (fileSize <= 0) {

                Log.e(
                    TAG,
                    "Encrypted file size is invalid"
                )

                return@withContext false
            }

            // ----------------------------------------------------
            // 4. CALCULATE SHA-256 OF .DSENC
            // ----------------------------------------------------

            val fileHash =
                calculateSha256(
                    context,
                    encryptedFile
                )

            Log.d(
                TAG,
                "SHA-256: $fileHash"
            )

            // ----------------------------------------------------
            // 5. PREPARE JSON
            // ----------------------------------------------------

            val encryptedName =
                encryptedFile.name
                    ?: "$originalName.dsenc"

            val json =
                JSONObject().apply {

                    put(
                        "original_name",
                        originalName
                    )

                    put(
                        "encrypted_name",
                        encryptedName
                    )

                    put(
                        "mime_type",
                        mimeType
                    )

                    put(
                        "file_size",
                        fileSize
                    )

                    put(
                        "file_hash",
                        fileHash
                    )
                }

            Log.d(
                TAG,
                "Request body: $json"
            )

            // ----------------------------------------------------
            // 6. CREATE HTTPS CONNECTION
            // ----------------------------------------------------

            val url =
                URL(
                    BASE_URL + REGISTER_ENDPOINT
                )

            val connection =
                url.openConnection()
                    as HttpsURLConnection

            try {

                // ------------------------------------------------
                // IMPORTANT:
                // Use your DataShield CA certificate.
                // DO NOT disable SSL verification.
                // ------------------------------------------------

                connection.sslSocketFactory =
                    createSslSocketFactory(context)

                connection.requestMethod =
                    "POST"

                connection.connectTimeout =
                    10_000

                connection.readTimeout =
                    10_000

                connection.doOutput =
                    true

                connection.setRequestProperty(
                    "Content-Type",
                    "application/json"
                )

                connection.setRequestProperty(
                    "Authorization",
                    "Bearer $jwt"
                )

                // ------------------------------------------------
                // 7. SEND REQUEST
                // ------------------------------------------------

                OutputStreamWriter(
                    connection.outputStream,
                    Charsets.UTF_8
                ).use { writer ->

                    writer.write(
                        json.toString()
                    )

                    writer.flush()
                }

                // ------------------------------------------------
                // 8. READ RESPONSE
                // ------------------------------------------------

                val statusCode =
                    connection.responseCode

                val responseBody =
                    if (statusCode in 200..299) {

                        BufferedReader(
                            InputStreamReader(
                                connection.inputStream
                            )
                        ).use {
                            it.readText()
                        }

                    } else {

                        connection.errorStream
                            ?.let { stream ->

                                BufferedReader(
                                    InputStreamReader(
                                        stream
                                    )
                                ).use {
                                    it.readText()
                                }

                            } ?: ""
                    }

                Log.d(
                    TAG,
                    "HTTP status: $statusCode"
                )

                Log.d(
                    TAG,
                    "Server response: $responseBody"
                )

                // ------------------------------------------------
                // 9. SUCCESS
                // ------------------------------------------------

                if (statusCode == 201) {

                    Log.d(
                        TAG,
                        "========================================"
                    )

                    Log.d(
                        TAG,
                        "MEDIA REGISTRATION SUCCESSFUL"
                    )

                    Log.d(
                        TAG,
                        "File: $encryptedName"
                    )

                    Log.d(
                        TAG,
                        "========================================"
                    )

                    return@withContext true
                }

                // ------------------------------------------------
                // 10. FAILURE
                // ------------------------------------------------

                Log.e(
                    TAG,
                    "MEDIA REGISTRATION FAILED"
                )

                Log.e(
                    TAG,
                    "Status: $statusCode"
                )

                Log.e(
                    TAG,
                    "Response: $responseBody"
                )

                return@withContext false

            } finally {

                connection.disconnect()
            }

        } catch (e: Exception) {

            Log.e(
                TAG,
                "MEDIA REGISTRATION ERROR",
                e
            )

            return@withContext false
        }
    }

    // ============================================================
    // SHA-256
    // ============================================================

    private fun calculateSha256(
        context: Context,
        file: DocumentFile
    ): String {

        val digest =
            MessageDigest.getInstance(
                "SHA-256"
            )

        context.contentResolver
            .openInputStream(
                file.uri
            )
            ?.use { input ->

                val buffer =
                    ByteArray(8192)

                var bytesRead: Int

                while (
                    input.read(buffer).also {
                        bytesRead = it
                    } != -1
                ) {

                    digest.update(
                        buffer,
                        0,
                        bytesRead
                    )
                }

            }
            ?: throw Exception(
                "Could not open encrypted file"
            )

        return digest
            .digest()
            .joinToString("") {
                "%02x".format(it)
            }
    }

    // ============================================================
    // SSL
    // ============================================================

    private fun createSslSocketFactory(
        context: Context
    ): javax.net.ssl.SSLSocketFactory {

        /*
         * This expects:
         *
         * android/app/src/main/assets/certs/rootca.pem
         *
         * to contain your CA certificate.
         */

        val certificateFactory =
            CertificateFactory.getInstance(
                "X.509"
            )

        val certificate =
            context.assets
                .open("certs/rootCA.pem")
                .use { inputStream ->

                    certificateFactory
                        .generateCertificate(
                            inputStream
                        )
                }

        val keyStore =
            KeyStore.getInstance(
                KeyStore.getDefaultType()
            )

        keyStore.load(
            null,
            null
        )

        keyStore.setCertificateEntry(
            "datashield_root_ca",
            certificate
        )

        val trustManagerFactory =
            TrustManagerFactory.getInstance(
                TrustManagerFactory
                    .getDefaultAlgorithm()
            )

        trustManagerFactory.init(
            keyStore
        )

        val sslContext =
            SSLContext.getInstance(
                "TLS"
            )

        sslContext.init(
            null,
            trustManagerFactory.trustManagers,
            null
        )

        return sslContext.socketFactory
    }
}
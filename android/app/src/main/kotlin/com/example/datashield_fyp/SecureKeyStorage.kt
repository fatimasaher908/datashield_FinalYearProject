package com.example.datashield_fyp

import android.content.Context
import android.util.Base64
import android.util.Log
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * Securely stores the Data Encryption Key (DEK).
 *
 * The DEK itself is NEVER stored directly in SharedPreferences.
 *
 * Instead:
 *
 *       DEK
 *        ↓
 *   AES-GCM encryption
 *        ↓
 *   encrypted DEK + IV
 *        ↓
 *   SharedPreferences
 *
 * The AES key used to protect the DEK lives inside Android Keystore.
 */
object SecureKeyStorage {

    private const val TAG = "SecureKeyStorage"

    private const val KEYSTORE_NAME = "AndroidKeyStore"
    private const val MASTER_KEY_ALIAS = "DataShieldMasterKey"

    private const val PREFS_NAME = "datashield_native_security"

    private const val ENCRYPTED_DEK = "encrypted_dek"
    private const val DEK_IV = "dek_iv"

    private const val TRANSFORMATION =
        "AES/GCM/NoPadding"


    // ============================================================
    // STORE DEK
    // ============================================================

    fun storeDek(
        context: Context,
        dek: ByteArray
    ) {

        require(dek.isNotEmpty()) {
            "DEK cannot be empty"
        }

        try {

            val secretKey =
                getOrCreateMasterKey()

            val cipher =
                Cipher.getInstance(
                    TRANSFORMATION
                )

            cipher.init(
                Cipher.ENCRYPT_MODE,
                secretKey
            )

            val encryptedDek =
                cipher.doFinal(dek)

            val iv =
                cipher.iv

            val preferences =
                context.getSharedPreferences(
                    PREFS_NAME,
                    Context.MODE_PRIVATE
                )

            preferences.edit()
                .putString(
                    ENCRYPTED_DEK,
                    Base64.encodeToString(
                        encryptedDek,
                        Base64.NO_WRAP
                    )
                )
                .putString(
                    DEK_IV,
                    Base64.encodeToString(
                        iv,
                        Base64.NO_WRAP
                    )
                )
                .apply()

            Log.d(
                TAG,
                "DEK securely stored. Length=${dek.size}"
            )

        } catch (e: Exception) {

            Log.e(
                TAG,
                "Failed to securely store DEK",
                e
            )

            throw e
        }
    }


    // ============================================================
    // LOAD DEK
    // ============================================================

    fun loadDek(
        context: Context
    ): ByteArray? {

        return try {

            val preferences =
                context.getSharedPreferences(
                    PREFS_NAME,
                    Context.MODE_PRIVATE
                )

            val encryptedDekBase64 =
                preferences.getString(
                    ENCRYPTED_DEK,
                    null
                )

            val ivBase64 =
                preferences.getString(
                    DEK_IV,
                    null
                )

            if (
                encryptedDekBase64.isNullOrEmpty() ||
                ivBase64.isNullOrEmpty()
            ) {

                Log.w(
                    TAG,
                    "No stored DEK found"
                )

                return null
            }

            val encryptedDek =
                Base64.decode(
                    encryptedDekBase64,
                    Base64.NO_WRAP
                )

            val iv =
                Base64.decode(
                    ivBase64,
                    Base64.NO_WRAP
                )

            val secretKey =
                getOrCreateMasterKey()

            val cipher =
                Cipher.getInstance(
                    TRANSFORMATION
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

            val dek =
                cipher.doFinal(
                    encryptedDek
                )

            Log.d(
                TAG,
                "DEK successfully recovered. Length=${dek.size}"
            )

            dek

        } catch (e: Exception) {

            Log.e(
                TAG,
                "Failed to recover DEK",
                e
            )

            null
        }
    }


    // ============================================================
    // DELETE DEK
    // ============================================================

    fun clearDek(
        context: Context
    ) {

        try {

            val preferences =
                context.getSharedPreferences(
                    PREFS_NAME,
                    Context.MODE_PRIVATE
                )

            preferences.edit()
                .remove(ENCRYPTED_DEK)
                .remove(DEK_IV)
                .apply()

            /*
             * Also remove the Keystore master key.
             *
             * This means that after logout/clearAll,
             * the old encrypted DEK cannot be recovered.
             */

            val keyStore =
                KeyStore.getInstance(
                    KEYSTORE_NAME
                )

            keyStore.load(null)

            if (
                keyStore.containsAlias(
                    MASTER_KEY_ALIAS
                )
            ) {

                keyStore.deleteEntry(
                    MASTER_KEY_ALIAS
                )
            }

            Log.d(
                TAG,
                "Stored DEK and master key cleared"

            )

        } catch (e: Exception) {

            Log.e(
                TAG,
                "Failed to clear DEK",
                e
            )
        }
    }


    // ============================================================
    // CHECK WHETHER DEK EXISTS
    // ============================================================

    fun hasDek(
        context: Context
    ): Boolean {

        val preferences =
            context.getSharedPreferences(
                PREFS_NAME,
                Context.MODE_PRIVATE
            )

        return !preferences
            .getString(
                ENCRYPTED_DEK,
                null
            )
            .isNullOrEmpty()
    }


    // ============================================================
    // ANDROID KEYSTORE MASTER KEY
    // ============================================================

    private fun getOrCreateMasterKey(): SecretKey {

        val keyStore =
            KeyStore.getInstance(
                KEYSTORE_NAME
            )

        keyStore.load(null)

        if (
            keyStore.containsAlias(
                MASTER_KEY_ALIAS
            )
        ) {

            return keyStore
                .getKey(
                    MASTER_KEY_ALIAS,
                    null
                ) as SecretKey
        }


        val keyGenerator =
            KeyGenerator.getInstance(
                "AES",
                KEYSTORE_NAME
            )

        val keySpec =
            android.security.keystore.KeyGenParameterSpec.Builder(
                MASTER_KEY_ALIAS,
                android.security.keystore.KeyProperties.PURPOSE_ENCRYPT or
                        android.security.keystore.KeyProperties.PURPOSE_DECRYPT
            )
                .setKeySize(256)
                .setBlockModes(
                    android.security.keystore.KeyProperties.BLOCK_MODE_GCM
                )
                .setEncryptionPaddings(
                    android.security.keystore.KeyProperties.ENCRYPTION_PADDING_NONE
                )
                .build()

        keyGenerator.init(keySpec)

        return keyGenerator.generateKey()
    }
}
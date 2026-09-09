package com.example.datashield_fyp

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.util.Log
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

object SessionKeyStore {

    private const val TAG = "SessionKeyStore"

    private const val KEYSTORE_NAME = "AndroidKeyStore"
    private const val KEY_ALIAS = "DataShieldSessionKey"

    private const val PREFS_NAME = "datashield_native_session"

    private const val KEY_DATA = "encrypted_dek"
    private const val KEY_IV = "dek_iv"
    private const val KEY_ACTIVE = "session_active"

    private const val AES_MODE = "AES/GCM/NoPadding"

    // ============================================================
    // SAVE DEK
    // ============================================================

    fun saveKey(
        context: Context,
        keyBytes: ByteArray
    ): Boolean {
        return try {
            if (keyBytes.isEmpty()) {
                Log.e(TAG, "Cannot save empty DEK")
                return false
            }

            val secretKey = getOrCreateSecretKey()

            val cipher = Cipher.getInstance(AES_MODE)
            cipher.init(Cipher.ENCRYPT_MODE, secretKey)

            val encrypted = cipher.doFinal(keyBytes)
            val iv = cipher.iv

            val prefs = context.getSharedPreferences(
                PREFS_NAME,
                Context.MODE_PRIVATE
            )

            // CRITICAL FIX: Use commit() instead of apply() to guarantee 
            // immediate synchronous disk write before process termination.
            val success = prefs.edit()
                .putString(
                    KEY_DATA,
                    Base64.encodeToString(encrypted, Base64.NO_WRAP)
                )
                .putString(
                    KEY_IV,
                    Base64.encodeToString(iv, Base64.NO_WRAP)
                )
                .putBoolean(KEY_ACTIVE, true)
                .commit()

            Log.d(TAG, "DEK securely stored (commit success=$success). Length=${keyBytes.size}")
            success

        } catch (e: Exception) {
            Log.e(TAG, "Failed to save DEK", e)
            false
        }
    }

    // ============================================================
    // GET DEK
    // ============================================================

    fun getKey(
        context: Context
    ): ByteArray? {
        return try {
            val prefs = context.getSharedPreferences(
                PREFS_NAME,
                Context.MODE_PRIVATE
            )

            val active = prefs.getBoolean(KEY_ACTIVE, false)
            if (!active) {
                Log.d(TAG, "No active DataShield session")
                return null
            }

            val encryptedBase64 = prefs.getString(KEY_DATA, null)
            val ivBase64 = prefs.getString(KEY_IV, null)

            if (encryptedBase64 == null || ivBase64 == null) {
                Log.e(TAG, "Stored DEK data is incomplete")
                return null
            }

            val encrypted = Base64.decode(encryptedBase64, Base64.NO_WRAP)
            val iv = Base64.decode(ivBase64, Base64.NO_WRAP)

            val secretKey = getOrCreateSecretKey()

            val cipher = Cipher.getInstance(AES_MODE)
            cipher.init(
                Cipher.DECRYPT_MODE,
                secretKey,
                GCMParameterSpec(128, iv)
            )

            val key = cipher.doFinal(encrypted)
            Log.d(TAG, "DEK successfully recovered. Length=${key.size}")
            key

        } catch (e: Exception) {
            Log.e(TAG, "Failed to recover DEK", e)
            null
        }
    }

    // ============================================================
    // SESSION ACTIVE
    // ============================================================

    fun isSessionActive(
        context: Context
    ): Boolean {
        val prefs = context.getSharedPreferences(
            PREFS_NAME,
            Context.MODE_PRIVATE
        )
        return prefs.getBoolean(KEY_ACTIVE, false)
    }

    // ============================================================
    // CLEAR SESSION
    // ============================================================

    fun clearSession(
        context: Context
    ) {
        try {
            val prefs = context.getSharedPreferences(
                PREFS_NAME,
                Context.MODE_PRIVATE
            )

            prefs.edit().clear().commit()
            deleteKeystoreKey()

            Log.d(TAG, "DataShield session and DEK deleted")

        } catch (e: Exception) {
            Log.e(TAG, "Failed to clear session", e)
        }
    }

    // ============================================================
    // ANDROID KEYSTORE
    // ============================================================

    private fun getOrCreateSecretKey(): SecretKey {
        val keyStore = KeyStore.getInstance(KEYSTORE_NAME)
        keyStore.load(null)

        if (keyStore.containsAlias(KEY_ALIAS)) {
            val entry = keyStore.getKey(KEY_ALIAS, null)
            if (entry is SecretKey) {
                return entry
            }
            // If entry is invalid or corrupted, delete and recreate
            keyStore.deleteEntry(KEY_ALIAS)
        }

        val keyGenerator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            KEYSTORE_NAME
        )

        val spec = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .build()

        keyGenerator.init(spec)
        return keyGenerator.generateKey()
    }

    // ============================================================
    // DELETE KEYSTORE KEY
    // ============================================================

    private fun deleteKeystoreKey() {
        try {
            val keyStore = KeyStore.getInstance(KEYSTORE_NAME)
            keyStore.load(null)

            if (keyStore.containsAlias(KEY_ALIAS)) {
                keyStore.deleteEntry(KEY_ALIAS)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to delete KeyStore key", e)
        }
    }
}
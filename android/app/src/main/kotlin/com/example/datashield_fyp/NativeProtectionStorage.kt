package com.example.datashield_fyp

import android.content.Context
import android.util.Log

object NativeProtectionStorage {

    private const val TAG =
        "NativeProtectionStorage"

    private const val PREFS_NAME =
        "datashield_native_protection"

    private const val FOLDERS_KEY =
        "protected_folders"

    // ============================================================
    // SAVE FOLDERS
    // ============================================================

    fun saveFolders(
        context: Context,
        folders: List<String>
    ) {

        val preferences =
            context.getSharedPreferences(
                PREFS_NAME,
                Context.MODE_PRIVATE
            )

        preferences.edit()
            .putStringSet(
                FOLDERS_KEY,
                folders.toSet()
            )
            .apply()

        Log.d(
            TAG,
            "Saved ${folders.size} protected folders"
        )
    }


    // ============================================================
    // LOAD FOLDERS
    // ============================================================

    fun loadFolders(
        context: Context
    ): List<String> {

        val preferences =
            context.getSharedPreferences(
                PREFS_NAME,
                Context.MODE_PRIVATE
            )

        return preferences
            .getStringSet(
                FOLDERS_KEY,
                emptySet()
            )
            ?.toList()
            ?: emptyList()
    }


    // ============================================================
    // CHECK FOLDERS
    // ============================================================

    fun hasFolders(
        context: Context
    ): Boolean {

        return loadFolders(context)
            .isNotEmpty()
    }


    // ============================================================
    // CLEAR FOLDERS
    // ============================================================

    fun clearFolders(
        context: Context
    ) {

        context.getSharedPreferences(
            PREFS_NAME,
            Context.MODE_PRIVATE
        )
            .edit()
            .remove(FOLDERS_KEY)
            .apply()

        Log.d(
            TAG,
            "Protected folders cleared"
        )
    }


    // ============================================================
    // CLEAR EVERYTHING
    // ============================================================

    fun clearAll(
        context: Context
    ) {

        context.getSharedPreferences(
            PREFS_NAME,
            Context.MODE_PRIVATE
        )
            .edit()
            .clear()
            .apply()

        Log.d(
            TAG,
            "Native protection storage cleared"
        )
    }
}
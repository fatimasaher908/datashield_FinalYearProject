package com.example.datashield_fyp.database
import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "encrypted_files")
data class EncryptedFile(

    @PrimaryKey
    val fileUri: String,

    val fileName: String,

    val encryptedAt: Long

)
package com.example.datashield_fyp.database
import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query

@Dao
interface EncryptedFileDao {

    @Query(
        "SELECT EXISTS(SELECT 1 FROM encrypted_files WHERE fileUri = :uri)"
    )
    suspend fun isEncrypted(
        uri: String
    ): Boolean

    @Insert(
        onConflict = OnConflictStrategy.REPLACE
    )
    suspend fun insert(
        file: EncryptedFile
    )

    @Query(
        "DELETE FROM encrypted_files WHERE fileUri = :uri"
    )
    suspend fun delete(
        uri:String
    )

    @Query(
        "SELECT * FROM encrypted_files"
    )
    suspend fun getAllEncryptedFiles():
            List<EncryptedFile>
}
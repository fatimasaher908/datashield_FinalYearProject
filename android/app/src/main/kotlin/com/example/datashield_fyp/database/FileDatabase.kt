package com.example.datashield_fyp.database


import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase


@Database(
    entities = [
        EncryptedFile::class
    ],
    version = 1,
    exportSchema = false
)

abstract class FileDatabase :
    RoomDatabase(){


    abstract fun encryptedFileDao():
            EncryptedFileDao



    companion object {


        @Volatile
        private var INSTANCE: FileDatabase? = null



        fun getDatabase(
            context: Context
        ): FileDatabase {


            return INSTANCE ?: synchronized(this){


                val instance =
                    Room.databaseBuilder(

                        context.applicationContext,

                        FileDatabase::class.java,

                        "datashield_database"

                    )

                    .build()



                INSTANCE = instance


                instance

            }


        }

    }

}
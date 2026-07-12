package com.example.datashield_fyp

import android.content.Context
import android.net.Uri
import androidx.documentfile.provider.DocumentFile


object DecryptionManager {


    fun getEncryptedImages(
        context: Context,
        folderUri: Uri
    ): List<String> {


        val folder =
            DocumentFile.fromTreeUri(
                context,
                folderUri
            )
            ?: return emptyList()


        val encryptedFiles = mutableListOf<String>()


        scanFolder(
            folder,
            encryptedFiles
        )


        return encryptedFiles

    }




    private fun scanFolder(
        folder: DocumentFile,
        result: MutableList<String>
    ){


        folder.listFiles().forEach { file ->


            if(file.isDirectory){


                scanFolder(
                    file,
                    result
                )


            }
            else if(file.isFile){


                if(
                    file.name?.endsWith(".dsenc") == true
                ){

                    result.add(
                        file.uri.toString()
                    )

                }


            }


        }


    }



}
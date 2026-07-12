package com.example.datashield_fyp

import android.content.Context
import android.util.Log
import androidx.documentfile.provider.DocumentFile
import java.io.ByteArrayOutputStream
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec


object EncryptionEngine {


    private const val TAG = "DataShield"



    // TEMPORARY AES-256 KEY
    // Later replace this with the server-unwrapped key
    private val aesKey = byteArrayOf(

        0x01,0x02,0x03,0x04,
        0x05,0x06,0x07,0x08,

        0x09,0x0A,0x0B,0x0C,
        0x0D,0x0E,0x0F,0x10,

        0x11,0x12,0x13,0x14,
        0x15,0x16,0x17,0x18,

        0x19,0x1A,0x1B,0x1C,
        0x1D,0x1E,0x1F,0x20

    )





    fun encryptImage(

        context: Context,

        image: DocumentFile,

        parent: DocumentFile

    ): DocumentFile? {


        return try {


            Log.d(
                TAG,
                "Encrypting: ${image.name}"
            )



            /*
             * Read original image
             */

            val originalBytes =

                context.contentResolver
                    .openInputStream(image.uri)
                    ?.use {

                        it.readBytes()

                    }
                    ?: return null





            /*
             * Generate random IV
             */

            val iv =
                ByteArray(12)


            SecureRandom()
                .nextBytes(iv)






            /*
             * AES-256-GCM Encryption
             */

            val cipher =

                Cipher.getInstance(
                    "AES/GCM/NoPadding"
                )



            val secretKey =

                SecretKeySpec(
                    aesKey,
                    "AES"
                )



            val gcmSpec =

                GCMParameterSpec(
                    128,
                    iv
                )



            cipher.init(

                Cipher.ENCRYPT_MODE,

                secretKey,

                gcmSpec

            )



            val encryptedBytes =

                cipher.doFinal(
                    originalBytes
                )






            /*
             * Create encrypted filename
             */

            val originalName =
                image.name ?: "image"


            val encryptedName =

                originalName
                    .substringBeforeLast('.') + ".dsenc"






            /*
             * Prevent duplicate encrypted files
             */

            val alreadyExists =

                parent.listFiles()
                    .any {

                        it.name == encryptedName

                    }



            if(alreadyExists){


                Log.d(
                    TAG,
                    "Encrypted file already exists, skipping"
                )


                return parent.listFiles()
                    .first {

                        it.name == encryptedName

                    }

            }







            /*
             * Create encrypted file
             */

            val outputFile =

                parent.createFile(

                    "application/octet-stream",

                    encryptedName

                )
                ?: return null






            /*
             * DataShield file format
             *
             * HEADER
             * DS01
             *
             * IV
             * 12 bytes
             *
             * DATA
             * Ciphertext + Authentication Tag
             *
             */


            val outputData =

                ByteArrayOutputStream()



            outputData.write(

                "DS01".toByteArray()

            )



            outputData.write(iv)



            outputData.write(

                encryptedBytes

            )






            context.contentResolver
                .openOutputStream(outputFile.uri)
                ?.use {

                    it.write(
                        outputData.toByteArray()
                    )

                }
                ?: return null






            Log.d(

                TAG,

                "Encrypted file created: ${outputFile.name}"

            )



            Log.d(

                TAG,

                "Original size: ${originalBytes.size} bytes"

            )



            Log.d(

                TAG,

                "Encrypted size: ${encryptedBytes.size} bytes"

            )



            return outputFile



        }

        catch(e: Exception){


            Log.e(

                TAG,

                "Encryption failed",

                e

            )


            null

        }


    }


}
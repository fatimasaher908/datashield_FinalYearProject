package com.example.datashield_fyp

import android.content.Context
import android.util.Log
import androidx.documentfile.provider.DocumentFile
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec


object DecryptionEngine {


    private const val TAG = "DataShield"



    // SAME TEMPORARY KEY
    // Later replaced with server-unwrapped key
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





    fun decryptImage(

        context: Context,

        encryptedFile: DocumentFile

    ): ByteArray? {


        return try {



            Log.d(
                TAG,
                "Decrypting: ${encryptedFile.name}"
            )





            val encryptedData =

                context.contentResolver
                    .openInputStream(encryptedFile.uri)
                    ?.use {

                        it.readBytes()

                    }
                    ?: return null





            /*
             * Validate DataShield format
             *
             * DS01
             * IV
             * Ciphertext
             */


            if(encryptedData.size < 16){


                Log.e(
                    TAG,
                    "Encrypted file corrupted"
                )


                return null

            }





            val header =

                String(

                    encryptedData,

                    0,

                    4

                )





            if(header != "DS01"){


                Log.e(

                    TAG,

                    "Invalid DataShield file"

                )


                return null

            }





            // Extract IV

            val iv =

                encryptedData.copyOfRange(

                    4,

                    16

                )





            // Extract ciphertext

            val cipherText =

                encryptedData.copyOfRange(

                    16,

                    encryptedData.size

                )







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

                Cipher.DECRYPT_MODE,

                secretKey,

                gcmSpec

            )






            val originalBytes =

                cipher.doFinal(

                    cipherText

                )







            Log.d(

                TAG,

                "Decryption successful"

            )



            Log.d(

                TAG,

                "Recovered size: ${originalBytes.size} bytes"

            )





            originalBytes



        }

        catch(e: Exception){


            Log.e(

                TAG,

                "Decryption failed",

                e

            )


            null


        }



    }



}
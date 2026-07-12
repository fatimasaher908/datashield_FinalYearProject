package com.example.datashield_fyp

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel


class MainActivity : FlutterActivity() {


    companion object {

        private const val STORAGE_CHANNEL =
            "datashield/storage"

        private const val ENCRYPTION_CHANNEL =
            "datashield/encryption"

        private const val SERVICE_CHANNEL =
            "datashield/service"

        private const val PICK_FOLDER_REQUEST =
            1001

        private const val TAG =
            "MainActivity"
    }


    private var pendingResult:
            MethodChannel.Result? = null



    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {

        super.configureFlutterEngine(flutterEngine)



        /*
         * SERVICE CHANNEL
         * Starts and stops foreground service
         */

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SERVICE_CHANNEL
        ).setMethodCallHandler { call, result ->


            when(call.method) {


                "startService" -> {

    val folders =
        call.argument<List<String>>("folders")

    if (folders != null) {

        startDataShieldService(
            ArrayList(folders)
        )

        result.success(true)

    } else {

        result.error(
            "NO_FOLDERS",
            "Folder list missing",
            null
        )

    }

}


                "stopService" -> {

                    stopDataShieldService()

                    result.success(true)

                }


                else -> {

                    result.notImplemented()

                }
            }

        }






        /*
         * STORAGE CHANNEL
         * Folder picker
         */

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            STORAGE_CHANNEL
        ).setMethodCallHandler { call, result ->


            when(call.method) {


                "pickFolder" -> {


                    pendingResult = result


                    val intent =
                        Intent(
                            Intent.ACTION_OPEN_DOCUMENT_TREE
                        )


                    intent.addFlags(
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                        Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
                    )


                    if(Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {

                        intent.putExtra(
                            "android.content.extra.SHOW_ADVANCED",
                            true
                        )

                    }


                    startActivityForResult(
                        intent,
                        PICK_FOLDER_REQUEST
                    )

                }


                else -> {

                    result.notImplemented()

                }

            }

        }





        /*
         * ENCRYPTION CHANNEL
         */

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ENCRYPTION_CHANNEL
        ).setMethodCallHandler { call, result ->


            when(call.method) {



                "encryptFolder" -> {


                    val uriString =
                        call.argument<String>("uri")


                    if(uriString != null) {


                        EncryptionManager.encryptFolder(
                            this,
                            Uri.parse(uriString)
                        )


                        result.success(true)

                    }
                    else {


                        result.error(
                            "NO_URI",
                            "Folder URI missing",
                            null
                        )

                    }

                }




                "getEncryptedImages" -> {


                    val uriString =
                        call.argument<String>("uri")


                    if(uriString != null) {


                        val images =
                            DecryptionManager.getEncryptedImages(
                                this,
                                Uri.parse(uriString)
                            )


                        result.success(images)

                    }
                    else {


                        result.error(
                            "NO_URI",
                            "Folder URI missing",
                            null
                        )

                    }

                }





                "decryptImage" -> {


                    val uriString =
                        call.argument<String>("uri")


                    if(uriString != null) {


                        val encryptedFile =
                            DocumentFile.fromSingleUri(
                                this,
                                Uri.parse(uriString)
                            )


                        if(encryptedFile != null) {


                            val decryptedBytes =
                                DecryptionEngine.decryptImage(
                                    this,
                                    encryptedFile
                                )


                            result.success(
                                decryptedBytes
                            )


                        }
                        else {


                            result.error(
                                "FILE_ERROR",
                                "Cannot open encrypted file",
                                null
                            )

                        }


                    }
                    else {


                        result.error(
                            "NO_URI",
                            "Image URI missing",
                            null
                        )

                    }

                }

                "deleteEncryptedImage" -> {

    val uriString = call.argument<String>("uri")!!

    val document = DocumentFile.fromSingleUri(
        this,
        Uri.parse(uriString)
    )

    if (document != null && document.exists()) {

        document.delete()

        result.success(true)

    } else {

        result.success(false)

    }

}




                else -> {

                    result.notImplemented()

                }

            }


        }

    }





    /*
     * START FOREGROUND SERVICE
     */

 private fun startDataShieldService(
    folders: ArrayList<String>
) {

    Log.d(
        TAG,
        "Starting DataShield Service"
    )

    val intent =
        Intent(
            this,
            DataShieldService::class.java
        )

    intent.putStringArrayListExtra(
        "protectedFolders",
        folders
    )

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {

        startForegroundService(intent)

    } else {

        startService(intent)

    }

}





    /*
     * STOP FOREGROUND SERVICE
     */

    private fun stopDataShieldService() {


        Log.d(
            TAG,
            "Stopping DataShield Service"
        )


        stopService(
            Intent(
                this,
                DataShieldService::class.java
            )
        )

    }






    @Deprecated("Deprecated in Java")
    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?
    ) {


        super.onActivityResult(
            requestCode,
            resultCode,
            data
        )


        if(requestCode == PICK_FOLDER_REQUEST) {


            if(
                resultCode == Activity.RESULT_OK &&
                data != null
            ) {


                val uri =
                    data.data


                if(uri != null) {


                    contentResolver
                        .takePersistableUriPermission(
                            uri,
                            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                            Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                        )


                    pendingResult?.success(
                        uri.toString()
                    )


                }
                else {


                    pendingResult?.error(
                        "NULL_URI",
                        "No folder selected",
                        null
                    )

                }


            }
            else {


                pendingResult?.success(null)

            }


            pendingResult = null

        }

    }

}
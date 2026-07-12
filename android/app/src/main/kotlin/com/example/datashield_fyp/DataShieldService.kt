package com.example.datashield_fyp

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*


class DataShieldService : Service() {


    companion object {

        private const val CHANNEL_ID =
            "datashield_service"

        private const val NOTIFICATION_ID =
            1

        private const val TAG =
            "DataShieldService"

    }



    private lateinit var folderMonitor: FolderMonitor

    private val protectedFolders = mutableListOf<String>()


    private var serviceScope =
        CoroutineScope(
            Dispatchers.IO +
                    SupervisorJob()
        )



    private var isMonitoring = false





    override fun onCreate() {

        super.onCreate()


        Log.d(
            TAG,
            "Service Created"
        )


        createNotificationChannel()



        folderMonitor =
            FolderMonitor(this)

    }







    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int
    ): Int {



        Log.d(
            TAG,
            "Service Started"
        )

        intent?.getStringArrayListExtra(
    "protectedFolders"
)?.let {

    protectedFolders.clear()

    protectedFolders.addAll(it)

    Log.d(
        TAG,
        "Protected folders: $protectedFolders"
    )
}



        val notification =
            NotificationCompat.Builder(
                this,
                CHANNEL_ID
            )

                .setSmallIcon(
                    R.mipmap.ic_launcher
                )

                .setContentTitle(
                    "DataShield Active"
                )

                .setContentText(
                    "Monitoring protected folders..."
                )

                .setOngoing(true)

                .build()



        startForeground(
            NOTIFICATION_ID,
            notification
        )


        Log.d(
            TAG,
            "Foreground Service Running"
        )



        startFolderMonitoring()



        return START_STICKY

    }









    private fun startFolderMonitoring(){


        if(isMonitoring){

            Log.d(
                TAG,
                "Monitoring already running"
            )

            return

        }



        isMonitoring = true



        serviceScope.launch {


            Log.d(
                TAG,
                "Folder monitoring started"
            )



            while(isMonitoring){

try {

    Log.d(
        TAG,
        "===== Monitoring Cycle ====="
    )

    protectedFolders.forEach { folder ->

        Log.d(
            TAG,
            "Scanning: $folder"
        )

        folderMonitor.scanFolder(
            folder
        )
    }

    Log.d(
        TAG,
        "Sleeping for 10 seconds..."
    )

    delay(10000)

} catch (e: Exception) {

    Log.e(
        TAG,
        "Monitoring error",
        e
    )

}


            }


        }


    }








    override fun onDestroy(){


        Log.d(
            TAG,
            "Service Destroyed"
        )


        isMonitoring = false


        serviceScope.cancel()


        super.onDestroy()

    }







    override fun onBind(
        intent: Intent?
    ): IBinder? {


        return null

    }









    private fun createNotificationChannel(){


        if(
            Build.VERSION.SDK_INT >=
            Build.VERSION_CODES.O
        ){


            val channel =
                NotificationChannel(

                    CHANNEL_ID,

                    "DataShield Service",

                    NotificationManager.IMPORTANCE_LOW

                )



            val manager =
                getSystemService(
                    NotificationManager::class.java
                )


            manager.createNotificationChannel(
                channel
            )



            Log.d(
                TAG,
                "Notification Channel Created"
            )

        }

    }


}
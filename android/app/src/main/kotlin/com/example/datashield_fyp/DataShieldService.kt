package com.example.datashield_fyp

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

class DataShieldService : Service() {

    companion object {

        private const val TAG =
            "DataShieldService"

        private const val CHANNEL_ID =
            "datashield_service"

        private const val NOTIFICATION_ID =
            1001

        // ========================================================
        // INTENT EXTRAS
        // ========================================================

        private const val EXTRA_PICTURES_URI =
            "picturesUri"

        private const val EXTRA_DCIM_URI =
            "dcimUri"

        private const val EXTRA_KEY =
            "key"

        // ========================================================
        // MONITORING
        // ========================================================

        private const val SCAN_INTERVAL_MS =
            10_000L

        // ========================================================
        // URI STORAGE
        // ========================================================

        private const val PREFS =
            "datashield_pictures"

        private const val PICTURES_URI_KEY =
            "pictures_uri"

        private const val DCIM_URI_KEY =
            "dcim_uri"
    }

    // ============================================================
    // VARIABLES
    // ============================================================

    private lateinit var folderMonitor: FolderMonitor

    private var picturesFolderUri: String? = null

    private var dcimFolderUri: String? = null

    private var encryptionKey: ByteArray? = null

    private val serviceScope =
        CoroutineScope(
            Dispatchers.IO + SupervisorJob()
        )

    private var monitoringJob: Job? = null

    @Volatile
    private var isMonitoring = false

    // ============================================================
    // CREATE
    // ============================================================

    override fun onCreate() {

        super.onCreate()

        Log.d(
            TAG,
            "========== SERVICE CREATED =========="
        )

        createNotificationChannel()

        folderMonitor =
            FolderMonitor(this)

        Log.d(
            TAG,
            "DataShield service created successfully"
        )
    }

    // ============================================================
    // START COMMAND
    // ============================================================

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int
    ): Int {

        Log.d(
            TAG,
            "========== SERVICE START COMMAND =========="
        )

        // ========================================================
        // 1. ENTER FOREGROUND IMMEDIATELY
        // ========================================================

        try {

            val notification =
                createNotification()

            if (
                Build.VERSION.SDK_INT >=
                Build.VERSION_CODES.Q
            ) {

                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                )

            } else {

                startForeground(
                    NOTIFICATION_ID,
                    notification
                )
            }

            Log.d(
                TAG,
                "Foreground service started successfully"
            )

        } catch (e: Exception) {

            Log.e(
                TAG,
                "Failed to enter foreground mode",
                e
            )

            stopSelf()

            return START_NOT_STICKY
        }

        // ========================================================
        // 2. RECEIVE PICTURES URI
        // ========================================================

        val incomingPicturesUri =
            intent?.getStringExtra(
                EXTRA_PICTURES_URI
            )

        if (
            !incomingPicturesUri.isNullOrEmpty()
        ) {

            picturesFolderUri =
                incomingPicturesUri

            savePicturesUri(
                incomingPicturesUri
            )

            Log.d(
                TAG,
                "Pictures URI received:"
            )

            Log.d(
                TAG,
                incomingPicturesUri
            )
        }

        // ========================================================
        // 3. RECEIVE DCIM URI
        // ========================================================

        val incomingDcimUri =
            intent?.getStringExtra(
                EXTRA_DCIM_URI
            )

        if (
            !incomingDcimUri.isNullOrEmpty()
        ) {

            dcimFolderUri =
                incomingDcimUri

            saveDcimUri(
                incomingDcimUri
            )

            Log.d(
                TAG,
                "DCIM URI received:"
            )

            Log.d(
                TAG,
                incomingDcimUri
            )
        }

        // ========================================================
        // 4. RECEIVE DEK
        // ========================================================

        val incomingKey =
            intent?.getByteArrayExtra(
                EXTRA_KEY
            )

        if (
            incomingKey != null &&
            incomingKey.isNotEmpty()
        ) {

            encryptionKey =
                incomingKey.copyOf()

            Log.d(
                TAG,
                "DEK received"
            )

            Log.d(
                TAG,
                "DEK length: ${incomingKey.size}"
            )

            val saved =
                SessionKeyStore.saveKey(
                    this,
                    incomingKey
                )

            Log.d(
                TAG,
                "Session DEK saved: $saved"
            )

            if (!saved) {

                Log.e(
                    TAG,
                    "Could not save session DEK"
                )

                stopDataShieldService()

                return START_NOT_STICKY
            }
        }

        // ========================================================
        // 5. RECOVER PICTURES URI
        // ========================================================

        if (
            picturesFolderUri.isNullOrEmpty()
        ) {

            picturesFolderUri =
                getSavedPicturesUri()

            Log.d(
                TAG,
                "Recovered Pictures URI:"
            )

            Log.d(
                TAG,
                picturesFolderUri ?: "NULL"
            )
        }

        // ========================================================
        // 6. RECOVER DCIM URI
        // ========================================================

        if (
            dcimFolderUri.isNullOrEmpty()
        ) {

            dcimFolderUri =
                getSavedDcimUri()

            Log.d(
                TAG,
                "Recovered DCIM URI:"
            )

            Log.d(
                TAG,
                dcimFolderUri ?: "NULL"
            )
        }

        // ========================================================
        // 7. VALIDATE SESSION
        // ========================================================

        if (
            !SessionKeyStore.isSessionActive(
                this
            )
        ) {

            Log.d(
                TAG,
                "No active DataShield session"
            )

            stopDataShieldService()

            return START_NOT_STICKY
        }

        // ========================================================
        // 8. RECOVER DEK IF NECESSARY
        // ========================================================

        if (
            encryptionKey == null
        ) {

            encryptionKey =
                SessionKeyStore.getKey(
                    this
                )
        }

        if (
            encryptionKey == null ||
            encryptionKey!!.isEmpty()
        ) {

            Log.e(
                TAG,
                "No encryption key available"
            )

            stopDataShieldService()

            return START_NOT_STICKY
        }

        // ========================================================
        // 9. VALIDATE PICTURES URI
        // ========================================================

        if (
            picturesFolderUri.isNullOrEmpty()
        ) {

            Log.e(
                TAG,
                "Pictures folder URI is missing"
            )

            stopDataShieldService()

            return START_NOT_STICKY
        }

        // ========================================================
        // 10. VALIDATE DCIM URI
        // ========================================================

        if (
            dcimFolderUri.isNullOrEmpty()
        ) {

            Log.e(
                TAG,
                "DCIM folder URI is missing"
            )

            stopDataShieldService()

            return START_NOT_STICKY
        }

        // ========================================================
        // 11. START MONITORING
        // ========================================================

        startMediaMonitoring()

        return START_STICKY
    }

    // ============================================================
    // START MEDIA MONITORING
    // ============================================================

    private fun startMediaMonitoring() {

        if (
            monitoringJob?.isActive == true
        ) {

            Log.d(
                TAG,
                "Monitoring already running"
            )

            return
        }

        isMonitoring = true

        monitoringJob =
            serviceScope.launch {

                Log.d(
                    TAG,
                    "========== MEDIA MONITORING STARTED =========="
                )

                while (
                    isActive &&
                    isMonitoring
                ) {

                    try {

                        // ====================================================
                        // CHECK SESSION
                        // ====================================================

                        val sessionActive =
                            SessionKeyStore.isSessionActive(
                                this@DataShieldService
                            )

                        Log.d(
                            TAG,
                            "SESSION ACTIVE = $sessionActive"
                        )

                        if (!sessionActive) {

                            Log.e(
                                TAG,
                                "SESSION INACTIVE - STOPPING MONITORING"
                            )

                            break
                        }

                        // ====================================================
                        // GET ENCRYPTION KEY
                        // ====================================================

                        if (
                            encryptionKey == null
                        ) {

                            encryptionKey =
                                SessionKeyStore.getKey(
                                    this@DataShieldService
                                )
                        }

                        val key =
                            encryptionKey

                        if (
                            key == null ||
                            key.isEmpty()
                        ) {

                            Log.e(
                                TAG,
                                "ENCRYPTION KEY UNAVAILABLE"
                            )

                            break
                        }

                        // ====================================================
                        // START CYCLE
                        // ====================================================

                        Log.d(
                            TAG,
                            "===== MONITORING CYCLE START ====="
                        )

                        // ====================================================
                        // PICTURES
                        // ====================================================

                        val picturesUri =
                            picturesFolderUri

                        if (
                            picturesUri.isNullOrEmpty()
                        ) {

                            Log.e(
                                TAG,
                                "PICTURES URI IS NULL OR EMPTY"
                            )

                        } else {

                            Log.d(
                                TAG,
                                "Scanning Pictures:"
                            )

                            Log.d(
                                TAG,
                                picturesUri
                            )

                            folderMonitor.scanFolder(
                                picturesUri,
                                key
                            )

                            Log.d(
                                TAG,
                                "Finished scanning Pictures"
                            )
                        }

                        // ====================================================
                        // DCIM
                        // ====================================================

                        val dcimUri =
                            dcimFolderUri

                        if (
                            dcimUri.isNullOrEmpty()
                        ) {

                            Log.e(
                                TAG,
                                "DCIM URI IS NULL OR EMPTY"
                            )

                        } else {

                            Log.d(
                                TAG,
                                "Scanning DCIM:"
                            )

                            Log.d(
                                TAG,
                                dcimUri
                            )

                            folderMonitor.scanFolder(
                                dcimUri,
                                key
                            )

                            Log.d(
                                TAG,
                                "Finished scanning DCIM"
                            )
                        }

                        // ====================================================
                        // END CYCLE
                        // ====================================================

                        Log.d(
    TAG,
    "===== MONITORING CYCLE END ====="
)

Log.e(
    TAG,
    "========== BEFORE DELAY =========="
)

Log.e(
    TAG,
    "Process ID: ${android.os.Process.myPid()}"
)

Log.e(
    TAG,
    "Thread: ${Thread.currentThread().name}"
)

delay(
    SCAN_INTERVAL_MS
)

Log.e(
    TAG,
    "========== AFTER DELAY =========="
)

Log.e(
    TAG,
    "Process ID: ${android.os.Process.myPid()}"
)

Log.d(
    TAG,
    "10 seconds finished - next cycle"
)

                    } catch (
                        e: CancellationException
                    ) {

                        Log.e(
                            TAG,
                            "MONITORING COROUTINE CANCELLED"
                        )

                        throw e

                    } catch (
                        e: Exception
                    ) {

                        Log.e(
                            TAG,
                            "MONITORING LOOP ERROR",
                            e
                        )

                        delay(
                            SCAN_INTERVAL_MS
                        )
                    }
                }

                Log.d(
                    TAG,
                    "========== MEDIA MONITORING ENDED =========="
                )
            }
    }

    // ============================================================
    // TASK REMOVED
    // ============================================================

    override fun onTaskRemoved(
        rootIntent: Intent?
    ) {

        Log.e(
            TAG,
            "========================================"
        )

        Log.e(
            TAG,
            "FLUTTER TASK REMOVED"
        )

        Log.e(
            TAG,
            "Flutter application was closed/removed"
        )

        Log.e(
            TAG,
            "DataShieldService is still supposed to be running"
        )

        Log.e(
            TAG,
            "========================================"
        )

        super.onTaskRemoved(
            rootIntent
        )
    }

    // ============================================================
    // DESTROY
    // ============================================================

    override fun onDestroy() {

        Log.e(
            TAG,
            "========================================"
        )

        Log.e(
            TAG,
            "DATASHIELD SERVICE DESTROYED"
        )

        Log.e(
            TAG,
            "Android/Huawei has destroyed the service"
        )

        Log.e(
            TAG,
            "========================================"
        )

        isMonitoring = false

        monitoringJob?.cancel()

        monitoringJob = null

        encryptionKey?.fill(0)

        encryptionKey = null


        super.onDestroy()
    }

    // ============================================================
    // BIND
    // ============================================================

    override fun onBind(
        intent: Intent?
    ): IBinder? {

        return null
    }

    // ============================================================
    // STOP SERVICE
    // ============================================================

    private fun stopDataShieldService() {

        Log.d(
            TAG,
            "Stopping DataShield service"
        )

        isMonitoring = false

        monitoringJob?.cancel()

        monitoringJob = null

        if (
            Build.VERSION.SDK_INT >=
            Build.VERSION_CODES.N
        ) {

            stopForeground(
                STOP_FOREGROUND_REMOVE
            )

        } else {

            @Suppress("DEPRECATION")
            stopForeground(
                true
            )
        }

        stopSelf()
    }

    // ============================================================
    // SAVE PICTURES URI
    // ============================================================

    private fun savePicturesUri(
        uri: String
    ) {

        getSharedPreferences(
            PREFS,
            MODE_PRIVATE
        )
            .edit()
            .putString(
                PICTURES_URI_KEY,
                uri
            )
            .apply()

        Log.d(
            TAG,
            "Pictures URI saved."
        )
    }

    // ============================================================
    // GET SAVED PICTURES URI
    // ============================================================

    private fun getSavedPicturesUri():
        String? {

        return getSharedPreferences(
            PREFS,
            MODE_PRIVATE
        )
            .getString(
                PICTURES_URI_KEY,
                null
            )
    }

    // ============================================================
    // SAVE DCIM URI
    // ============================================================

    private fun saveDcimUri(
        uri: String
    ) {

        getSharedPreferences(
            PREFS,
            MODE_PRIVATE
        )
            .edit()
            .putString(
                DCIM_URI_KEY,
                uri
            )
            .apply()

        Log.d(
            TAG,
            "DCIM URI saved."
        )
    }

    // ============================================================
    // GET SAVED DCIM URI
    // ============================================================

    private fun getSavedDcimUri():
        String? {

        return getSharedPreferences(
            PREFS,
            MODE_PRIVATE
        )
            .getString(
                DCIM_URI_KEY,
                null
            )
    }

    // ============================================================
    // NOTIFICATION
    // ============================================================

    private fun createNotification():
        Notification {

        return NotificationCompat.Builder(
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
                "Protecting Pictures and Camera media"
            )
            .setOngoing(
                true
            )
            .setCategory(
                NotificationCompat.CATEGORY_SERVICE
            )
            .setPriority(
                NotificationCompat.PRIORITY_LOW
            )
            .build()
    }

    // ============================================================
    // NOTIFICATION CHANNEL
    // ============================================================

    private fun createNotificationChannel() {

        if (
            Build.VERSION.SDK_INT >=
            Build.VERSION_CODES.O
        ) {

            val channel =
                NotificationChannel(
                    CHANNEL_ID,
                    "DataShield Background Protection",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {

                    description =
                        "Keeps DataShield Pictures and Camera protection active."
                }

            val manager =
                getSystemService(
                    NotificationManager::class.java
                )

            manager.createNotificationChannel(
                channel
            )
        }
    }
}
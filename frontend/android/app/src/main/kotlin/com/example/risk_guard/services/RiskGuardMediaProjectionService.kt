package com.example.risk_guard.services

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.Image
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.example.risk_guard.ProtectionEventStore
import java.io.File
import java.io.FileOutputStream
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

class RiskGuardMediaProjectionService : Service() {

    companion object {
        const val ACTION_START_CAPTURE_SESSION = "START_CAPTURE_SESSION"
        const val ACTION_STOP_CAPTURE_SESSION = "STOP_CAPTURE_SESSION"
        const val ACTION_CAPTURE_FRAME = "CAPTURE_FRAME"

        const val EXTRA_RESULT_CODE = "resultCode"
        const val EXTRA_PROJECTION_DATA = "projectionData"
        const val EXTRA_SOURCE_PACKAGE = "sourcePackage"
        const val EXTRA_REASON = "reason"

        private const val CHANNEL_ID = "risk_guard_media_projection"
        private const val NOTIFICATION_ID = 202
        private const val CAPTURE_COOLDOWN_MS = 1500L
        private const val CAPTURE_RETRY_DELAY_MS = 90L
        private const val CAPTURE_BOOTSTRAP_DELAY_MS = 120L
        private const val MAX_CAPTURE_FILES = 8
    }

    private val workerThread = HandlerThread("RiskGuardMediaCapture").apply { start() }
    private val workerHandler: Handler by lazy { Handler(workerThread.looper) }

    private var mediaProjectionManager: MediaProjectionManager? = null
    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null
    private var captureWidth: Int = 0
    private var captureHeight: Int = 0
    private var densityDpi: Int = 0
    private var captureInProgress = false
    private var lastCaptureAtMs = 0L

    private val projectionCallback = object : MediaProjection.Callback() {
        override fun onStop() {
            releaseProjectionResources(stopProjection = false)
            ProtectionEventStore.setMediaProjectionRunning(this@RiskGuardMediaProjectionService, false)
            stopForegroundCompat()
            stopSelf()
        }
    }

    override fun onCreate() {
        super.onCreate()
        mediaProjectionManager =
            getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP_CAPTURE_SESSION -> {
                stopCaptureSession()
                return START_NOT_STICKY
            }

            ACTION_START_CAPTURE_SESSION -> {
                val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, 0)
                val projectionData = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(EXTRA_PROJECTION_DATA, Intent::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(EXTRA_PROJECTION_DATA)
                }
                startCaptureSession(resultCode, projectionData)
                return START_STICKY
            }

            ACTION_CAPTURE_FRAME -> {
                val sourcePackage = intent.getStringExtra(EXTRA_SOURCE_PACKAGE) ?: return START_STICKY
                val reason = intent.getStringExtra(EXTRA_REASON) ?: "capture"
                requestCapture(sourcePackage, reason)
                return START_STICKY
            }
        }

        return START_STICKY
    }

    private fun startCaptureSession(resultCode: Int, projectionData: Intent?) {
        if (projectionData == null || resultCode == 0) {
            ProtectionEventStore.setMediaProjectionRunning(this, false)
            return
        }

        releaseProjectionResources(stopProjection = true)
        startForegroundCompat()

        val manager = mediaProjectionManager ?: return
        mediaProjection = manager.getMediaProjection(resultCode, projectionData)
        val projection = mediaProjection ?: return

        val metrics = resources.displayMetrics
        densityDpi = metrics.densityDpi
        val maxDimension = max(metrics.widthPixels, metrics.heightPixels).coerceAtLeast(1)
        val scale = min(1.0, 720.0 / maxDimension.toDouble())
        captureWidth = max(360, (metrics.widthPixels * scale).roundToInt())
        captureHeight = max(640, (metrics.heightPixels * scale).roundToInt())

        imageReader?.close()
        imageReader = ImageReader.newInstance(
            captureWidth,
            captureHeight,
            PixelFormat.RGBA_8888,
            2,
        )

        virtualDisplay?.release()
        virtualDisplay = projection.createVirtualDisplay(
            "RiskGuardRealtimeCapture",
            captureWidth,
            captureHeight,
            densityDpi,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            imageReader?.surface,
            null,
            workerHandler,
        )

        projection.registerCallback(projectionCallback, workerHandler)
        ProtectionEventStore.setMediaProjectionRunning(this, true)
    }

    private fun requestCapture(sourcePackage: String, reason: String) {
        if (!ProtectionEventStore.isProtectionActive(this)) return
        if (!ProtectionEventStore.isMediaProjectionRunning(this)) return
        if (!ProtectionEventStore.whitelistedPackages(this).contains(sourcePackage)) return

        val now = System.currentTimeMillis()
        if (captureInProgress || now - lastCaptureAtMs < CAPTURE_COOLDOWN_MS) return

        captureInProgress = true
        lastCaptureAtMs = now
        workerHandler.postDelayed(
            { captureLatestImage(sourcePackage, reason, attempt = 0) },
            CAPTURE_BOOTSTRAP_DELAY_MS,
        )
    }

    private fun captureLatestImage(sourcePackage: String, reason: String, attempt: Int) {
        val reader = imageReader
        if (reader == null) {
            captureInProgress = false
            return
        }

        val image = reader.acquireLatestImage()
        if (image == null) {
            if (attempt < 3) {
                workerHandler.postDelayed(
                    { captureLatestImage(sourcePackage, reason, attempt + 1) },
                    CAPTURE_RETRY_DELAY_MS,
                )
            } else {
                captureInProgress = false
            }
            return
        }

        try {
            val bitmap = imageToBitmap(image) ?: return
            val frameDir = File(cacheDir, "riskguard_realtime_frames").apply { mkdirs() }
            pruneFrameCache(frameDir)
            val frameFile = File(frameDir, "frame_${System.currentTimeMillis()}.jpg")
            FileOutputStream(frameFile).use { output ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, 72, output)
            }
            bitmap.recycle()
            ProtectionEventStore.storeMediaCaptureEvent(
                context = this,
                filePath = frameFile.absolutePath,
                sourcePackage = sourcePackage,
                targetType = "screen_frame",
                reason = reason,
            )
        } finally {
            image.close()
            captureInProgress = false
        }
    }

    private fun imageToBitmap(image: Image): Bitmap? {
        val plane = image.planes.firstOrNull() ?: return null
        val buffer = plane.buffer
        val pixelStride = plane.pixelStride
        val rowStride = plane.rowStride
        val rowPadding = rowStride - pixelStride * image.width

        val wideBitmap = Bitmap.createBitmap(
            image.width + rowPadding / pixelStride,
            image.height,
            Bitmap.Config.ARGB_8888,
        )
        wideBitmap.copyPixelsFromBuffer(buffer)

        val cropped = Bitmap.createBitmap(wideBitmap, 0, 0, image.width, image.height)
        if (cropped != wideBitmap) {
            wideBitmap.recycle()
        }
        return cropped
    }

    private fun pruneFrameCache(directory: File) {
        val files = directory.listFiles()?.sortedByDescending { it.lastModified() } ?: return
        if (files.size < MAX_CAPTURE_FILES) return
        files.drop(MAX_CAPTURE_FILES).forEach { file ->
            runCatching { file.delete() }
        }
    }

    private fun stopCaptureSession() {
        releaseProjectionResources(stopProjection = true)
        ProtectionEventStore.setMediaProjectionRunning(this, false)
        stopForegroundCompat()
        stopSelf()
    }

    private fun releaseProjectionResources(stopProjection: Boolean) {
        captureInProgress = false
        virtualDisplay?.release()
        virtualDisplay = null

        imageReader?.close()
        imageReader = null

        mediaProjection?.let { projection ->
            projection.unregisterCallback(projectionCallback)
            if (stopProjection) {
                projection.stop()
            }
        }
        mediaProjection = null
    }

    private fun startForegroundCompat() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "RiskGuard Screen Capture",
                    NotificationManager.IMPORTANCE_LOW,
                ),
            )
        }

        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("RiskGuard Screen Capture Active")
            .setContentText("Monitoring visible media in whitelisted apps.")
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    override fun onDestroy() {
        releaseProjectionResources(stopProjection = true)
        ProtectionEventStore.setMediaProjectionRunning(this, false)
        workerThread.quitSafely()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}

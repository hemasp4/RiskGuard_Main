package com.example.personal

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import android.util.Log

/**
 * Service for managing smart notifications with actionable quick actions
 */
class NotificationService(private val context: Context) {
    
    companion object {
        private const val TAG = "NotificationService"
        
        // Notification channels
        const val CHANNEL_ID_ALERTS = "riskguard_alerts"
        const val CHANNEL_ID_DIGEST = "riskguard_digest"
        const val CHANNEL_ID_AI_DETECTION = "riskguard_ai_detection"
        
        // Notification IDs
        private const val NOTIFICATION_ID_POST_CALL = 1000
        private const val NOTIFICATION_ID_AI_VOICE = 2000
        private const val NOTIFICATION_ID_DAILY_DIGEST = 3000
        
        // Custom colors
        private const val COLOR_BACKGROUND = "#ACC8E5"
        private const val COLOR_TEXT = "#112A46"
    }
    
    private val notificationManager = NotificationManagerCompat.from(context)
    
    init {
        createNotificationChannels()
    }
    
    /**
     * Create notification channels for Android O+
     */
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // High-risk alerts channel
            val alertsChannel = NotificationChannel(
                CHANNEL_ID_ALERTS,
                "Risk Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for high-risk calls and threats"
                enableLights(true)
                lightColor = Color.parseColor("#FF3D71")
                enableVibration(true)
            }
            
            // AI detection channel
            val aiChannel = NotificationChannel(
                CHANNEL_ID_AI_DETECTION,
                "AI Voice Detection",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications when AI-generated voice is detected"
                enableLights(true)
                lightColor = Color.parseColor("#FFAA00")
            }
            
            // Daily digest channel
            val digestChannel = NotificationChannel(
                CHANNEL_ID_DIGEST,
                "Daily Digest",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Daily summary of protection activity"
                enableLights(false)
            }
            
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(alertsChannel)
            manager.createNotificationChannel(aiChannel)
            manager.createNotificationChannel(digestChannel)
            
            Log.d(TAG, "Notification channels created")
        }
    }
    
    /**
     * Send post-call risk notification with quick actions
     */
    fun sendPostCallNotification(
        phoneNumber: String,
        riskScore: Int,
        riskLevel: String,
        duration: Long,
        callerName: String? = null
    ) {
        val displayName = callerName ?: phoneNumber
        val durationStr = formatDuration(duration)
        
        val notification = NotificationCompat.Builder(context, CHANNEL_ID_ALERTS)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("⚠️ High Risk Call Detected")
            .setContentText("$displayName - Risk: $riskScore%")
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText(
                        "$displayName\n" +
                        "Risk Score: $riskScore% - $riskLevel\n" +
                        "Duration: $durationStr"
                    )
            )
            .setColor(Color.parseColor(COLOR_BACKGROUND))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            // Add quick actions
            .addAction(createBlockAction(phoneNumber))
            .addAction(createSaveAction(phoneNumber))
            .addAction(createReportAction(phoneNumber))
            .build()
        
        notificationManager.notify(NOTIFICATION_ID_POST_CALL, notification)
        Log.d(TAG, "Post-call notification sent for $phoneNumber")
    }
    
    /**
     * Send AI voice detection alert
     */
    fun sendAIVoiceAlert(
        phoneNumber: String,
        probability: Float,
        callerName: String? = null
    ) {
        val displayName = callerName ?: phoneNumber
        val percentage = (probability * 100).toInt()
        
        val notification = NotificationCompat.Builder(context, CHANNEL_ID_AI_DETECTION)
            .setSmallIcon(android.R.drawable.stat_notify_error)
            .setContentTitle("🤖 AI Voice Detected")
            .setContentText("$displayName - $percentage% probability")
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText(
                        "$displayName\n" +
                        "$percentage% probability of synthetic voice\n" +
                        "Call may be from AI system or voice changer"
                    )
            )
            .setColor(Color.parseColor(COLOR_BACKGROUND))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .addAction(createBlockAction(phoneNumber))
            .addAction(createViewDetailsAction(phoneNumber))
            .build()
        
        notificationManager.notify(NOTIFICATION_ID_AI_VOICE, notification)
        Log.d(TAG, "AI voice alert sent for $phoneNumber")
    }
    
    /**
     * Send daily digest notification
     */
    fun sendDailyDigest(
        totalCalls: Int,
        highRiskCalls: Int,
        aiVoiceDetected: Int,
        callsBlocked: Int
    ) {
        val notification = NotificationCompat.Builder(context, CHANNEL_ID_DIGEST)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("📊 Daily Protection Summary")
            .setContentText("$totalCalls calls analyzed today")
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText(
                        "Today's Activity:\n" +
                        "• $totalCalls calls analyzed\n" +
                        "• $highRiskCalls high-risk calls\n" +
                        "• $aiVoiceDetected AI voices detected\n" +
                        "• $callsBlocked calls blocked"
                    )
            )
            .setColor(Color.parseColor(COLOR_BACKGROUND))
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .addAction(createViewReportAction())
            .build()
        
        notificationManager.notify(NOTIFICATION_ID_DAILY_DIGEST, notification)
        Log.d(TAG, "Daily digest sent")
    }
    
    /**
     * Create "Block" action
     */
    private fun createBlockAction(phoneNumber: String): NotificationCompat.Action {
        val intent = Intent(context, NotificationActionReceiver::class.java).apply {
            action = NotificationActionReceiver.ACTION_BLOCK
            putExtra("phone_number", phoneNumber)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            phoneNumber.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Action(
            android.R.drawable.ic_delete,
            "Block",
            pendingIntent
        )
    }
    
    /**
     * Create "Save" action
     */
    private fun createSaveAction(phoneNumber: String): NotificationCompat.Action {
        val intent = Intent(context, NotificationActionReceiver::class.java).apply {
            action = NotificationActionReceiver.ACTION_SAVE
            putExtra("phone_number", phoneNumber)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            phoneNumber.hashCode() + 1,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Action(
            android.R.drawable.ic_menu_save,
            "Save",
            pendingIntent
        )
    }
    
    /**
     * Create "Report" action
     */
    private fun createReportAction(phoneNumber: String): NotificationCompat.Action {
        val intent = Intent(context, NotificationActionReceiver::class.java).apply {
            action = NotificationActionReceiver.ACTION_REPORT
            putExtra("phone_number", phoneNumber)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            phoneNumber.hashCode() + 2,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Action(
            android.R.drawable.ic_menu_report_image,
            "Report",
            pendingIntent
        )
    }
    
    /**
     * Create "View Details" action
     */
    private fun createViewDetailsAction(phoneNumber: String): NotificationCompat.Action {
        val intent = Intent(context, NotificationActionReceiver::class.java).apply {
            action = NotificationActionReceiver.ACTION_VIEW_DETAILS
            putExtra("phone_number", phoneNumber)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            phoneNumber.hashCode() + 3,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Action(
            android.R.drawable.ic_menu_info_details,
            "View Details",
            pendingIntent
        )
    }
    
    /**
     * Create "View Report" action
     */
    private fun createViewReportAction(): NotificationCompat.Action {
        val intent = Intent(context, NotificationActionReceiver::class.java).apply {
            action = NotificationActionReceiver.ACTION_VIEW_REPORT
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            4000,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Action(
            android.R.drawable.ic_menu_view,
            "View Report",
            pendingIntent
        )
    }
    
    /**
     * Format call duration
     */
    private fun formatDuration(milliseconds: Long): String {
        val seconds = milliseconds / 1000
        val minutes = seconds / 60
        val remainingSeconds = seconds % 60
        
        return if (minutes > 0) {
            String.format("%dm %ds", minutes, remainingSeconds)
        } else {
            String.format("%ds", remainingSeconds)
        }
    }
    
    /**
     * Cancel all notifications
     */
    fun cancelAll() {
        notificationManager.cancelAll()
        Log.d(TAG, "All notifications cancelled")
    }
    
    /**
     * Cancel specific notification
     */
    fun cancel(notificationId: Int) {
        notificationManager.cancel(notificationId)
        Log.d(TAG, "Notification cancelled: $notificationId")
    }
}

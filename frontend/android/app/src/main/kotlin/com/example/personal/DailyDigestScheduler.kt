package com.example.personal

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import java.util.Calendar

/**
 * Daily Digest Scheduler using AlarmManager
 * Simpler than WorkManager, no extra dependencies
 */
object DailyDigestScheduler {
    private const val TAG = "DailyDigestScheduler"
    private const val REQUEST_CODE = 1001
    private const val PREF_NAME = "digest_prefs"
    private const val KEY_ENABLED = "digest_enabled"
    private const val KEY_HOUR = "digest_hour"
    private const val KEY_MINUTE = "digest_minute"
    
    /**
     * Schedule daily digest at specified time
     */
    fun scheduleDailyDigest(
        context: Context,
        hour: Int = 20, // 8 PM default
        minute: Int = 0
    ) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, DailyDigestReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
        )
        
        // Calculate time for next digest
        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            
            // If time has passed today, schedule for tomorrow
            if (before(Calendar.getInstance())) {
                add(Calendar.DAY_OF_MONTH, 1)
            }
        }
        
        // Schedule repeating alarm
        alarmManager.setRepeating(
            AlarmManager.RTC_WAKEUP,
            calendar.timeInMillis,
            AlarmManager.INTERVAL_DAY,
            pendingIntent
        )
        
        // Save preferences
        val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        prefs.edit().apply {
            putBoolean(KEY_ENABLED, true)
            putInt(KEY_HOUR, hour)
            putInt(KEY_MINUTE, minute)
            apply()
        }
        
        Log.d(TAG, "Daily digest scheduled for $hour:$minute")
    }
    
    /**
     * Cancel daily digest
     */
    fun cancelDailyDigest(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, DailyDigestReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
        )
        
        alarmManager.cancel(pendingIntent)
        
        // Update preferences
        val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(KEY_ENABLED, false).apply()
        
        Log.d(TAG, "Daily digest cancelled")
    }
    
    /**
     * Check if digest is enabled
     */
    fun isEnabled(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        return prefs.getBoolean(KEY_ENABLED, false)
    }
    
    /**
     * Get scheduled time
     */
    fun getScheduledTime(context: Context): Pair<Int, Int> {
        val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        val hour = prefs.getInt(KEY_HOUR, 20)
        val minute = prefs.getInt(KEY_MINUTE, 0)
        return Pair(hour, minute)
    }
}

/**
 * Receiver for daily digest alarm
 */
class DailyDigestReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "DailyDigestReceiver"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Daily digest alarm triggered")
        
        try {
            // Collect statistics
            val stats = collectDailyStats(context)
            
            // Send notification if there's activity
            if (stats.totalCalls > 0) {
                val notificationService = NotificationService(context)
                notificationService.sendDailyDigest(
                    totalCalls = stats.totalCalls,
                    highRiskCalls = stats.highRiskCalls,
                    aiVoiceDetected = stats.aiDetected,
                    callsBlocked = stats.callsBlocked
                )
                
                Log.d(TAG, "Daily digest sent: ${stats.totalCalls} calls")
            } else {
                Log.d(TAG, "No activity today, skipping digest")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error sending daily digest", e)
        }
    }
    
    private fun collectDailyStats(context: Context): DigestStats {
        // Calculate start of today
        val calendar = Calendar.getInstance()
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        val todayStart = calendar.timeInMillis
        
        try {
            // Get call history from database
            val historyDb = CallHistoryDatabase(context)
            val allCalls = historyDb.getAllCalls()
            val todayCalls = allCalls.filter { it.timestamp >= todayStart }
            
            val highRiskCalls = todayCalls.count { it.riskScore >= 70 }
            val aiDetected = todayCalls.count { it.aiProbability >= 0.7f }
            val callsBlocked = todayCalls.count { it.wasBlocked }
            
            return DigestStats(
                totalCalls = todayCalls.size,
                highRiskCalls = highRiskCalls,
                aiDetected = aiDetected,
                callsBlocked = callsBlocked
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error collecting stats", e)
            return DigestStats(0, 0, 0, 0)
        }
    }
}

/**
 * Stats data class
 */
data class DigestStats(
    val totalCalls: Int,
    val highRiskCalls: Int,
    val aiDetected: Int,
    val callsBlocked: Int
)

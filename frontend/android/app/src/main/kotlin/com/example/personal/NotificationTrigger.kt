package com.example.personal

import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import android.telephony.TelephonyManager

/**
 * Helper class to trigger notifications after calls
 */
object NotificationTrigger {
    private const val TAG = "NotificationTrigger"
    
    /**
     * Send post-call notification if risk score is high
     */
    fun sendPostCallNotificationIfNeeded(
        context: Context,
        phoneNumber: String,
        riskScore: Int,
        callDuration: Long,
        callerName: String? = null
    ) {
        // Only send notification for medium-high risk calls
        if (riskScore >= 60) {
            val riskLevel = when {
                riskScore >= 70 -> "High Risk"
                riskScore >= 40 -> "Medium Risk"
                else -> "Low Risk"
            }
            
            try {
                val notificationService = NotificationService(context)
                notificationService.sendPostCallNotification(
                    phoneNumber = phoneNumber,
                    riskScore = riskScore,
                    riskLevel = riskLevel,
                    duration = callDuration,
                    callerName = callerName
                )
                
                Log.d(TAG, "Post-call notification sent for $phoneNumber (risk: $riskScore%)")
            } catch (e: Exception) {
                Log.e(TAG, "Error sending post-call notification", e)
            }
        }
    }
    
    /**
     * Send AI voice detection alert
     */
    fun sendAIDetectionAlert(
        context: Context,
        phoneNumber: String,
        probability: Float,
        callerName: String? = null
    ) {
        // Only send alert if probability is high
        if (probability >= 0.7f) {
            try {
                val notificationService = NotificationService(context)
                notificationService.sendAIVoiceAlert(
                    phoneNumber = phoneNumber,
                    probability = probability,
                    callerName = callerName
                )
                
                Log.d(TAG, "AI detection alert sent for $phoneNumber")
            } catch (e: Exception) {
                Log.e(TAG, "Error sending AI detection alert", e)
            }
        }
    }
}

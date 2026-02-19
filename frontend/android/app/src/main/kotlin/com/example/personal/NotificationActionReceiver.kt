package com.example.personal

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.widget.Toast
import android.util.Log

/**
 * Receiver for handling notification action buttons
 */
class NotificationActionReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "NotificationActionReceiver"
        
        const val ACTION_BLOCK = "com.example.personal.ACTION_BLOCK"
        const val ACTION_SAVE = "com.example.personal.ACTION_SAVE"
        const val ACTION_REPORT = "com.example.personal.ACTION_REPORT"
        const val ACTION_VIEW_DETAILS = "com.example.personal.ACTION_VIEW_DETAILS"
        const val ACTION_VIEW_REPORT = "com.example.personal.ACTION_VIEW_REPORT"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        val phoneNumber = intent.getStringExtra("phone_number")
        
        when (intent.action) {
            ACTION_BLOCK -> {
                phoneNumber?.let {
                    blockNumber(context, it)
                    Toast.makeText(context, "Number blocked: $it", Toast.LENGTH_SHORT).show()
                }
            }
            ACTION_SAVE -> {
                phoneNumber?.let {
                    // Launch MainActivity with save contact intent
                    val mainIntent = Intent(context, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        putExtra("action", "save_contact")
                        putExtra("phone_number", it)
                    }
                    context.startActivity(mainIntent)
                }
            }
            ACTION_REPORT -> {
                phoneNumber?.let {
                    reportSpam(context, it)
                    Toast.makeText(context, "Number reported as spam", Toast.LENGTH_SHORT).show()
                }
            }
            ACTION_VIEW_DETAILS -> {
                phoneNumber?.let {
                    // Launch MainActivity with view details intent
                    val mainIntent = Intent(context, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        putExtra("action", "view_details")
                        putExtra("phone_number", it)
                    }
                    context.startActivity(mainIntent)
                }
            }
            ACTION_VIEW_REPORT -> {
                // Launch MainActivity with view report intent
                val mainIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    putExtra("action", "view_report")
                }
                context.startActivity(mainIntent)
            }
        }
        
        // Dismiss notification after action
        val notificationManager = androidx.core.app.NotificationManagerCompat.from(context)
        notificationManager.cancel(phoneNumber?.hashCode() ?: 0)
    }
    
    /**
     * Block a number
     */
    private fun blockNumber(context: Context, phoneNumber: String) {
        try {
            val db = BlockedNumbersDatabase(context)
            db.blockNumber(phoneNumber, "Blocked from notification", autoBlocked = false)
            Log.d(TAG, "Number blocked: $phoneNumber")
            
            // Notify via MethodChannel
            MethodChannelHandler.sendNumberBlocked(phoneNumber)
        } catch (e: Exception) {
            Log.e(TAG, "Error blocking number", e)
        }
    }
    
    /**
     * Report number as spam
     */
    private fun reportSpam(context: Context, phoneNumber: String) {
        try {
            // Add to blocked list with spam reason
            val db = BlockedNumbersDatabase(context)
            db.blockNumber(phoneNumber, "Reported as spam", autoBlocked = false)
            
            Log.d(TAG, "Number reported as spam: $phoneNumber")
            
            // Notify via MethodChannel
            MethodChannelHandler.sendNumberReported(phoneNumber)
        } catch (e: Exception) {
            Log.e(TAG, "Error reporting spam", e)
        }
    }
}

package com.example.personal

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.TelephonyManager
import android.util.Log

/**
 * BroadcastReceiver to detect incoming and outgoing call states.
 * Triggers the CallOverlayService to display risk information.
 */
class CallStateReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "CallStateReceiver"
        private var lastState = TelephonyManager.CALL_STATE_IDLE
        private var lastPhoneNumber: String? = null
        private var isIncoming = false
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        Log.d(TAG, "Received action: $action")
        
        when (action) {
            TelephonyManager.ACTION_PHONE_STATE_CHANGED -> handlePhoneStateChanged(context, intent)
            Intent.ACTION_NEW_OUTGOING_CALL -> handleOutgoingCall(context, intent)
        }
    }
    
    private fun handlePhoneStateChanged(context: Context, intent: Intent) {
        val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE) ?: return
        val phoneNumber = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)
        
        Log.d(TAG, "Phone state changed: $state, number: $phoneNumber")
        
        when (state) {
            TelephonyManager.EXTRA_STATE_RINGING -> {
                // Incoming call ringing
                lastState = TelephonyManager.CALL_STATE_RINGING
                lastPhoneNumber = phoneNumber
                isIncoming = true
                
                if (!phoneNumber.isNullOrEmpty()) {
                    startOverlayService(context, phoneNumber, isIncoming = true)
                }
            }
            TelephonyManager.EXTRA_STATE_OFFHOOK -> {
                // Call answered or outgoing call started
                if (lastState == TelephonyManager.CALL_STATE_IDLE) {
                    // Outgoing call - number comes from NEW_OUTGOING_CALL
                    isIncoming = false
                }
                
                lastState = TelephonyManager.CALL_STATE_OFFHOOK
                
                // Update overlay service
                lastPhoneNumber?.let { number ->
                    if (number.isNotEmpty()) {
                        updateOverlayService(context, number, isIncoming)
                        // Ensure overlay is shown if it wasn't already (e.g. outgoing transition)
                        startOverlayService(context, number, isIncoming)
                    }
                }
            }
            TelephonyManager.EXTRA_STATE_IDLE -> {
                // Call ended
                lastState = TelephonyManager.CALL_STATE_IDLE
                
                // Notify Flutter about call end
                lastPhoneNumber?.let { number ->
                    MethodChannelHandler.sendCallEnded(number, isIncoming)
                    
                    // TODO: Re-enable after fixing build
                    // Send post-call notification for high-risk calls
                    // android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    //     sendPostCallNotification(context, number, isIncoming)
                    // }, 500)
                    
                    // Show post-call details after a short delay (1 second)
                    android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                        showPostCallDetails(context, number)
                    }, 1000)
                }
                
                // Stop overlay immediately after call ends
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    stopOverlayService(context)
                }, 1000) // 1 second delay to allow for any final updates
                
                lastPhoneNumber = null
                isIncoming = false
            }
        }
    }
    
    private fun handleOutgoingCall(context: Context, intent: Intent) {
        val phoneNumber = intent.getStringExtra(Intent.EXTRA_PHONE_NUMBER)
        Log.d(TAG, "Outgoing call to: $phoneNumber")
        
        if (!phoneNumber.isNullOrEmpty()) {
            lastPhoneNumber = phoneNumber
            isIncoming = false
            startOverlayService(context, phoneNumber, isIncoming = false)
        }
    }
    
    private fun startOverlayService(context: Context, phoneNumber: String, isIncoming: Boolean) {
        Log.d(TAG, "Starting overlay service for: $phoneNumber, incoming: $isIncoming")
        
        val serviceIntent = Intent(context, CallOverlayService::class.java).apply {
            action = CallOverlayService.ACTION_SHOW_OVERLAY
            putExtra(CallOverlayService.EXTRA_PHONE_NUMBER, phoneNumber)
            putExtra(CallOverlayService.EXTRA_IS_INCOMING, isIncoming)
        }
        
        try {
            context.startForegroundService(serviceIntent)
            
            // Notify Flutter about the call
            MethodChannelHandler.sendCallStateChanged(phoneNumber, isIncoming)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start overlay service", e)
        }
    }
    
    private fun updateOverlayService(context: Context, phoneNumber: String, isIncoming: Boolean) {
        val serviceIntent = Intent(context, CallOverlayService::class.java).apply {
            action = CallOverlayService.ACTION_UPDATE_OVERLAY
            putExtra(CallOverlayService.EXTRA_PHONE_NUMBER, phoneNumber)
            putExtra(CallOverlayService.EXTRA_IS_INCOMING, isIncoming)
        }
        
        try {
            context.startService(serviceIntent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update overlay service", e)
        }
    }
    
    private fun stopOverlayService(context: Context) {
        Log.d(TAG, "Stopping overlay service")
        
        val serviceIntent = Intent(context, CallOverlayService::class.java).apply {
            action = CallOverlayService.ACTION_HIDE_OVERLAY
        }
        
        try {
            context.startService(serviceIntent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop overlay service", e)
        }
    }
    
    private fun showPostCallDetails(context: Context, phoneNumber: String) {
        Log.d(TAG, "Showing post-call details for: $phoneNumber")
        
        val serviceIntent = Intent(context, CallOverlayService::class.java).apply {
            action = CallOverlayService.ACTION_SHOW_POST_CALL_DETAILS
        }
        
        try {
            context.startService(serviceIntent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show post-call details", e)
        }
    }
}

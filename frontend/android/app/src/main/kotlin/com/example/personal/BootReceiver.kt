package com.example.personal

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * BroadcastReceiver that handles device boot events.
 * Automatically restarts call monitoring if protection was enabled before reboot.
 */
class BootReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "BootReceiver"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) {
            return
        }
        
        Log.d(TAG, "Device boot completed, checking protection state...")
        
        // Initialize the state manager
        ProtectionStateManager.initialize(context)
        
        // Check if protection was enabled before reboot
        val wasProtectionEnabled = ProtectionStateManager.isProtectionEnabled()
        
        if (wasProtectionEnabled) {
            Log.d(TAG, "Protection was enabled, restarting call monitoring service...")
            
            // Start the call monitoring service
            // The CallStateReceiver is already registered in manifest, so it will
            // automatically listen for calls. We just need to ensure any foreground
            // service state is restored if needed.
            
            // Note: We don't need to explicitly start CallOverlayService here
            // because it will be started automatically when a call is detected
            // by CallStateReceiver
            
            Log.d(TAG, "Call monitoring automatically enabled via manifest registration")
        } else {
            Log.d(TAG, "Protection was not enabled before reboot, no action needed")
        }
    }
}

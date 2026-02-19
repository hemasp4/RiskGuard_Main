package com.example.personal

import android.content.Context
import android.content.SharedPreferences
import android.util.Log

/**
 * Manages the persistence of protection state across app restarts and device reboots.
 * Uses SharedPreferences to store whether call monitoring protection is enabled.
 */
object ProtectionStateManager {
    private const val TAG = "ProtectionStateManager"
    private const val PREFS_NAME = "riskguard_protection_prefs"
    private const val KEY_PROTECTION_ENABLED = "protection_enabled"
    
    private var sharedPreferences: SharedPreferences? = null
    
    /**
     * Initialize the state manager with application context
     */
    fun initialize(context: Context) {
        if (sharedPreferences == null) {
            sharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            Log.d(TAG, "ProtectionStateManager initialized")
        }
    }
    
    /**
     * Save the protection enabled state
     */
    fun setProtectionEnabled(enabled: Boolean) {
        sharedPreferences?.edit()?.apply {
            putBoolean(KEY_PROTECTION_ENABLED, enabled)
            apply()
        }
        Log.d(TAG, "Protection state saved: $enabled")
    }
    
    /**
     * Get the current protection enabled state
     */
    fun isProtectionEnabled(): Boolean {
        val enabled = sharedPreferences?.getBoolean(KEY_PROTECTION_ENABLED, false) ?: false
        Log.d(TAG, "Protection state retrieved: $enabled")
        return enabled
    }
    
    /**
     * Clear all saved state (for debugging/reset purposes)
     */
    fun clearState() {
        sharedPreferences?.edit()?.clear()?.apply()
        Log.d(TAG, "Protection state cleared")
    }
}

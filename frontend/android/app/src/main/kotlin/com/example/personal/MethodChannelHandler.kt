package com.example.personal

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Handles communication between Flutter and native Android code.
 * Provides methods for call monitoring, overlay control, recording, and risk analysis.
 */
object MethodChannelHandler {
    private const val TAG = "MethodChannelHandler"
    private const val CHANNEL_NAME = "com.riskguard.app/channel"
    
    private var methodChannel: MethodChannel? = null
    private var appContext: Context? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    
    /**
     * Initialize the method channel with the Flutter engine
     */
    fun initialize(flutterEngine: FlutterEngine, context: Context) {
        appContext = context.applicationContext
        
        // Initialize protection state manager
        ProtectionStateManager.initialize(context.applicationContext)
        
        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME
        ).apply {
            setMethodCallHandler { call, result ->
                handleMethodCall(call, result)
            }
        }
        
        Log.d(TAG, "MethodChannel initialized")
    }
    
    /**
     * Handle method calls from Flutter
     */
    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        Log.d(TAG, "Method called: ${call.method}")
        
        when (call.method) {
            "startCallMonitoring" -> {
                val success = startCallMonitoring()
                result.success(success)
            }
            "stopCallMonitoring" -> {
                val success = stopCallMonitoring()
                result.success(success)
            }
            "showRiskOverlay" -> {
                val args = call.arguments as? Map<*, *>
                val riskScore = args?.get("riskScore") as? Int ?: 0
                val riskLevel = args?.get("riskLevel") as? String ?: "Unknown"
                val explanation = args?.get("explanation") as? String ?: ""
                val phoneNumber = args?.get("phoneNumber") as? String ?: ""
                
                val success = showRiskOverlay(riskScore, riskLevel, explanation, phoneNumber)
                result.success(success)
            }
            "hideRiskOverlay" -> {
                val success = hideRiskOverlay()
                result.success(success)
            }
            "updateAIResult" -> {
                val args = call.arguments as? Map<*, *>
                val probability = (args?.get("probability") as? Double)?.toFloat() ?: 0f
                val isSynthetic = args?.get("isSynthetic") as? Boolean ?: false
                
                val success = updateAIResult(probability, isSynthetic)
                result.success(success)
            }
            "checkOverlayPermission" -> {
                val hasPermission = checkOverlayPermission()
                result.success(hasPermission)
            }
            "requestOverlayPermission" -> {
                requestOverlayPermission()
                result.success(null)
            }
            "getRecentCalls" -> {
                val limit = call.argument<Int>("limit") ?: 20
                val calls = getRecentCalls(limit)
                result.success(calls)
            }
            "analyzePhoneNumber" -> {
                val phoneNumber = call.argument<String>("phoneNumber") ?: ""
                val analysis = analyzePhoneNumber(phoneNumber)
                result.success(analysis)
            }
            "getSavedContacts" -> {
                val contacts = getSavedContacts()
                result.success(contacts)
            }
            "getCurrentRecordingPath" -> {
                result.success(CallOverlayService.currentRecordingPath)
            }
            "isProtectionEnabled" -> {
                val enabled = ProtectionStateManager.isProtectionEnabled()
                result.success(enabled)
            }
            "checkBatteryOptimization" -> {
                val isOptimized = checkBatteryOptimization()
                result.success(isOptimized)
            }
            "requestBatteryOptimizationExemption" -> {
                requestBatteryOptimizationExemption()
                result.success(null)
            }
            "clearRecentCalls" -> {
                val context = appContext
                if (context != null) {
                    val db = CallHistoryDatabase(context)
                    val success = db.clearHistory()
                    result.success(success)
                } else {
                    result.error("CONTEXT_NULL", "App context is null", null)
                }
            }
            "getProtectionStats" -> {
                val stats = getProtectionStats()
                result.success(stats)
            }
            else -> {
                result.notImplemented()
            }
        }
    }
    
    /**
     * Start monitoring call states
     */
    private fun startCallMonitoring(): Boolean {
        return try {
            Log.d(TAG, "Call monitoring started")
            // The BroadcastReceiver is registered in AndroidManifest
            // Save the protection enabled state
            ProtectionStateManager.setProtectionEnabled(true)
            Log.d(TAG, "Protection state saved as enabled")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start call monitoring", e)
            false
        }
    }
    
    /**
     * Stop monitoring call states
     */
    private fun stopCallMonitoring(): Boolean {
        return try {
            Log.d(TAG, "Call monitoring stopped")
            // Save the protection disabled state
            ProtectionStateManager.setProtectionEnabled(false)
            Log.d(TAG, "Protection state saved as disabled")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop call monitoring", e)
            false
        }
    }
    
    /**
     * Show risk overlay with given data
     */
    private fun showRiskOverlay(
        riskScore: Int,
        riskLevel: String,
        explanation: String,
        phoneNumber: String
    ): Boolean {
        val context = appContext ?: return false
        
        return try {
            val intent = Intent(context, CallOverlayService::class.java).apply {
                action = CallOverlayService.ACTION_UPDATE_RISK
                putExtra(CallOverlayService.EXTRA_RISK_SCORE, riskScore)
                putExtra(CallOverlayService.EXTRA_RISK_LEVEL, riskLevel)
                putExtra(CallOverlayService.EXTRA_EXPLANATION, explanation)
                putExtra(CallOverlayService.EXTRA_PHONE_NUMBER, phoneNumber)
            }
            context.startService(intent)
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show risk overlay", e)
            false
        }
    }
    
    /**
     * Update AI analysis result in overlay
     */
    private fun updateAIResult(probability: Float, isSynthetic: Boolean): Boolean {
        val context = appContext ?: return false
        
        return try {
            val intent = Intent(context, CallOverlayService::class.java).apply {
                action = CallOverlayService.ACTION_UPDATE_AI_RESULT
                putExtra(CallOverlayService.EXTRA_AI_PROBABILITY, probability)
                putExtra(CallOverlayService.EXTRA_AI_IS_SYNTHETIC, isSynthetic)
            }
            context.startService(intent)
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update AI result", e)
            false
        }
    }
    
    /**
     * Hide the risk overlay
     */
    private fun hideRiskOverlay(): Boolean {
        val context = appContext ?: return false
        
        return try {
            val intent = Intent(context, CallOverlayService::class.java).apply {
                action = CallOverlayService.ACTION_HIDE_OVERLAY
            }
            context.startService(intent)
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to hide risk overlay", e)
            false
        }
    }
    
    /**
     * Check if overlay permission is granted
     */
    private fun checkOverlayPermission(): Boolean {
        val context = appContext ?: return false
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true
        }
    }
    
    /**
     * Request overlay permission (opens settings)
     */
    private fun requestOverlayPermission() {
        val context = appContext ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                android.net.Uri.parse("package:${context.packageName}")
            ).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
        }
    }
    
    /**
     * Check if battery optimization is enabled for this app
     * Returns true if app IS being optimized (bad for background services)
     * Returns false if app is NOT being optimized (exempted - good!)
     */
    private fun checkBatteryOptimization(): Boolean {
        val context = appContext ?: return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
            return !powerManager.isIgnoringBatteryOptimizations(context.packageName)
        }
        return false
    }
    
    /**
     * Request battery optimization exemption
     * Opens system settings for user to disable optimization
     */
    private fun requestBatteryOptimizationExemption() {
        val context = appContext ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val intent = Intent(
                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                    android.net.Uri.parse("package:${context.packageName}")
                ).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(intent)
                Log.d(TAG, "Battery optimization exemption requested")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to request battery optimization exemption", e)
            }
        }
    }
    
    /**
     * Get recent calls from call log
     */
    private fun getRecentCalls(limit: Int): List<Map<String, Any>> {
        // Note: This requires READ_CALL_LOG permission
        // Implementation would query ContentResolver for call history
        // For now, returning empty list
        return emptyList()
    }
    
    /**
     * Analyze a phone number for risk factors
     */
    private fun analyzePhoneNumber(phoneNumber: String): Map<String, Any> {
        // Basic local analysis
        val riskFactors = mutableListOf<String>()
        var riskScore = 0
        
        // Unknown number heuristics
        if (phoneNumber.startsWith("+")) {
            // International number - slightly higher risk for unknown calls
            riskFactors.add("International number")
            riskScore += 10
        }
        
        // Short codes (potential spam)
        if (phoneNumber.length < 7) {
            riskFactors.add("Short code number")
            riskScore += 20
        }
        
        // Premium rate prefixes (example patterns)
        val premiumPrefixes = listOf("900", "976", "970")
        if (premiumPrefixes.any { phoneNumber.contains(it) }) {
            riskFactors.add("Potential premium rate number")
            riskScore += 40
        }
        
        return mapOf(
            "phoneNumber" to phoneNumber,
            "riskScore" to riskScore,
            "riskFactors" to riskFactors,
            "analysisType" to "local"
        )
    }
    
    /**
     * Get saved contacts from native database
     */
    private fun getSavedContacts(): List<Map<String, Any?>> {
        val context = appContext ?: return emptyList()
        val db = ContactsDatabase(context)
        return db.getAllContacts().map {
            mapOf(
                "phoneNumber" to it.phoneNumber,
                "name" to it.name,
                "email" to it.email,
                "category" to it.category,
                "company" to it.company,
                "notes" to it.notes,
                "tags" to it.tags,
                "savedAt" to it.savedAt
            )
        }
    }
    
    /**
     * Get protection statistics from call history
     */
    private fun getProtectionStats(): Map<String, Any> {
        val context = appContext ?: return mapOf(
            "threatsBlockedToday" to 0,
            "threatsBlockedThisWeek" to 0,
            "highRiskCallsCount" to 0,
            "totalCallsCount" to 0
        )
        
        return try {
            val db = CallHistoryDatabase(context)
            mapOf(
                "threatsBlockedToday" to db.getThreatsBlockedToday(),
                "threatsBlockedThisWeek" to db.getThreatsBlockedThisWeek(),
                "highRiskCallsCount" to db.getHighRiskCallsCount(),
                "totalCallsCount" to db.getTotalCallsCount()
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error getting protection stats", e)
            mapOf(
                "threatsBlockedToday" to 0,
                "threatsBlockedThisWeek" to 0,
                "highRiskCallsCount" to 0,
                "totalCallsCount" to 0
            )
        }
    }
    
    // ========== Methods to send events to Flutter ==========
    
    /**
     * Send call state change event to Flutter
     */
    fun sendCallStateChanged(phoneNumber: String, isIncoming: Boolean) {
        mainHandler.post {
            methodChannel?.invokeMethod(
                "onCallStateChanged",
                mapOf(
                    "phoneNumber" to phoneNumber,
                    "isIncoming" to isIncoming
                )
            )
        }
    }
    
    /**
     * Send call ended event to Flutter
     */
    fun sendCallEnded(phoneNumber: String, wasIncoming: Boolean) {
        mainHandler.post {
            methodChannel?.invokeMethod(
                "onCallEnded",
                mapOf(
                    "phoneNumber" to phoneNumber,
                    "wasIncoming" to wasIncoming
                )
            )
        }
    }
    
    /**
     * Send recording started event to Flutter
     */
    fun sendRecordingStarted(filePath: String) {
        mainHandler.post {
            methodChannel?.invokeMethod(
                "onRecordingStarted",
                mapOf(
                    "filePath" to filePath
                )
            )
        }
    }
    
    /**
     * Send recording stopped event to Flutter with file path
     */
    fun sendRecordingStopped(filePath: String) {
        mainHandler.post {
            methodChannel?.invokeMethod(
                "onRecordingStopped",
                mapOf(
                    "filePath" to filePath
                )
            )
        }
    }
    
    /**
     * Send contact saved event to Flutter
     */
    fun sendContactSaved(phoneNumber: String, name: String, email: String?, category: String?, company: String? = null, notes: String? = null) {
        mainHandler.post {
            methodChannel?.invokeMethod(
                "onContactSaved",
                mapOf(
                    "phoneNumber" to phoneNumber,
                    "name" to name,
                    "email" to email,
                    "category" to category,
                    "company" to company,
                    "notes" to notes
                )
            )
        }
    }
    
    /**
     * Send contact updated event to Flutter
     */
    fun sendContactUpdated(phoneNumber: String, name: String, email: String?, category: String?) {
        mainHandler.post {
            methodChannel?.invokeMethod(
                "onContactUpdated",
                mapOf(
                    "phoneNumber" to phoneNumber,
                    "name" to name,
                    "email" to email,
                    "category" to category
                )
            )
        }
    }
    
    /**
     * Send number blocked event to Flutter
     */
    fun sendNumberBlocked(phoneNumber: String) {
        mainHandler.post {
            methodChannel?.invokeMethod(
                "onNumberBlocked",
                mapOf("phoneNumber" to phoneNumber)
            )
        }
    }
    
    /**
     * Send number reported event to Flutter
     */
    fun sendNumberReported(phoneNumber: String) {
        mainHandler.post {
            methodChannel?.invokeMethod(
                "onNumberReported",
                mapOf("phoneNumber" to phoneNumber)
            )
        }
    }
}

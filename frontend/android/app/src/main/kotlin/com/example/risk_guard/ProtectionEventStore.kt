package com.example.risk_guard

import android.content.Context
import android.content.Intent
import org.json.JSONObject

object ProtectionEventStore {
    private const val NATIVE_PREFS = "RiskGuardPrefs"
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"

    private const val KEY_PROTECTION_ACTIVE = "protection_active"
    private const val KEY_WHITELISTED_PACKAGES = "whitelisted_packages"

    private const val KEY_URL = "flutter.latest_proactive_url"
    private const val KEY_URL_PACKAGE = "flutter.latest_proactive_pkg"
    private const val KEY_URL_TIME = "flutter.latest_proactive_time"

    private const val KEY_CALL_STATE = "flutter.latest_call_state"
    private const val KEY_CALL_NUMBER = "flutter.latest_call_number"
    private const val KEY_CALL_TIME = "flutter.latest_call_time"

    private const val KEY_TRIGGER_OVERLAY = "flutter.trigger_overlay"
    private const val KEY_OVERLAY_PAYLOAD = "flutter.latest_overlay_payload"
    private const val KEY_OVERLAY_PAYLOAD_TIME = "flutter.latest_overlay_payload_time"

    const val ACTION_URL_DETECTED = "com.example.risk_guard.URL_DETECTED"
    const val ACTION_CALL_DETECTED = "com.example.risk_guard.CALL_DETECTED"

    fun syncSecuritySettings(
        context: Context,
        isProtectionActive: Boolean,
        whitelistedPackages: List<String>,
    ) {
        context.getSharedPreferences(NATIVE_PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_PROTECTION_ACTIVE, isProtectionActive)
            .putStringSet(KEY_WHITELISTED_PACKAGES, whitelistedPackages.toSet())
            .apply()
    }

    fun isProtectionActive(context: Context): Boolean {
        return context.getSharedPreferences(NATIVE_PREFS, Context.MODE_PRIVATE)
            .getBoolean(KEY_PROTECTION_ACTIVE, false)
    }

    fun whitelistedPackages(context: Context): Set<String> {
        return context.getSharedPreferences(NATIVE_PREFS, Context.MODE_PRIVATE)
            .getStringSet(KEY_WHITELISTED_PACKAGES, emptySet())
            ?: emptySet()
    }

    fun storeUrlEvent(context: Context, url: String, packageName: String) {
        context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_URL, url)
            .putString(KEY_URL_PACKAGE, packageName)
            .putLong(KEY_URL_TIME, System.currentTimeMillis())
            .putString(KEY_TRIGGER_OVERLAY, "true")
            .apply()
    }

    fun storeCallEvent(context: Context, state: String, phoneNumber: String?) {
        context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_CALL_STATE, state)
            .putString(KEY_CALL_NUMBER, phoneNumber)
            .putLong(KEY_CALL_TIME, System.currentTimeMillis())
            .putString(KEY_TRIGGER_OVERLAY, "true")
            .apply()
    }

    fun storeOverlayPayload(context: Context, payload: Map<String, Any?>) {
        val jsonObject = JSONObject()
        payload.forEach { (key, value) ->
            jsonObject.put(key, value ?: JSONObject.NULL)
        }
        val jsonPayload = jsonObject.toString()
        context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_OVERLAY_PAYLOAD, jsonPayload)
            .putLong(KEY_OVERLAY_PAYLOAD_TIME, System.currentTimeMillis())
            .putString(KEY_TRIGGER_OVERLAY, "true")
            .apply()
    }

    fun broadcastUrl(context: Context, url: String, packageName: String) {
        val intent = Intent(ACTION_URL_DETECTED).apply {
            putExtra("url", url)
            putExtra("packageName", packageName)
        }
        context.sendBroadcast(intent)
    }

    fun broadcastCall(context: Context, state: String, phoneNumber: String?) {
        val intent = Intent(ACTION_CALL_DETECTED).apply {
            putExtra("state", state)
            putExtra("phoneNumber", phoneNumber)
        }
        context.sendBroadcast(intent)
    }

    fun clearAll(context: Context) {
        context.getSharedPreferences(NATIVE_PREFS, Context.MODE_PRIVATE)
            .edit()
            .clear()
            .apply()

        context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_URL)
            .remove(KEY_URL_PACKAGE)
            .remove(KEY_URL_TIME)
            .remove(KEY_CALL_STATE)
            .remove(KEY_CALL_NUMBER)
            .remove(KEY_CALL_TIME)
            .remove(KEY_TRIGGER_OVERLAY)
            .remove(KEY_OVERLAY_PAYLOAD)
            .remove(KEY_OVERLAY_PAYLOAD_TIME)
            .apply()
    }
}

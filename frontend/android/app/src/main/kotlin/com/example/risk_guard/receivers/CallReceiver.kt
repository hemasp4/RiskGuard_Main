package com.example.risk_guard.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.TelephonyManager
import android.util.Log
import androidx.core.content.ContextCompat
import com.example.risk_guard.ProtectionEventStore
import com.example.risk_guard.services.RiskGuardForegroundService

class CallReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED) {
            return
        }
        if (!ProtectionEventStore.isProtectionActive(context)) {
            return
        }

        val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE) ?: return
        val phoneNumber = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)

        Log.d("CallReceiver", "Phone State Changed: $state, Number: $phoneNumber")

        ProtectionEventStore.storeCallEvent(context, state, phoneNumber)
        ProtectionEventStore.broadcastCall(context, state, phoneNumber)

        val serviceIntent = Intent(context, RiskGuardForegroundService::class.java).apply {
            putExtra("phoneNumber", phoneNumber)
        }
        ContextCompat.startForegroundService(context, serviceIntent)
    }
}

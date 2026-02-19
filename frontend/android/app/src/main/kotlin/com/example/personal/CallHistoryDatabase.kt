package com.example.personal

import android.content.Context
import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.util.Log

/**
 * Database for storing call history with risk analysis results
 */
class CallHistoryDatabase(context: Context) : SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {
    
    companion object {
        private const val TAG = "CallHistoryDB"
        private const val DATABASE_NAME = "call_history.db"
        private const val DATABASE_VERSION = 1
        
        // Table name
        private const val TABLE_HISTORY = "call_history"
        
        // Columns
        private const val COL_ID = "id"
        private const val COL_PHONE_NUMBER = "phone_number"
        private const val COL_CALLER_NAME = "caller_name"
        private const val COL_CALL_TYPE = "call_type" // incoming/outgoing
        private const val COL_DURATION = "duration" // in milliseconds
        private const val COL_TIMESTAMP = "timestamp"
        private const val COL_RISK_SCORE = "risk_score"
        private const val COL_RISK_LEVEL = "risk_level"
        private const val COL_AI_PROBABILITY = "ai_probability"
        private const val COL_WAS_BLOCKED = "was_blocked"
    }
    
    override fun onCreate(db: SQLiteDatabase) {
        val createTable = """
            CREATE TABLE $TABLE_HISTORY (
                $COL_ID INTEGER PRIMARY KEY AUTOINCREMENT,
                $COL_PHONE_NUMBER TEXT NOT NULL,
                $COL_CALLER_NAME TEXT,
                $COL_CALL_TYPE TEXT NOT NULL,
                $COL_DURATION INTEGER DEFAULT 0,
                $COL_TIMESTAMP INTEGER NOT NULL,
                $COL_RISK_SCORE INTEGER DEFAULT 0,
                $COL_RISK_LEVEL TEXT,
                $COL_AI_PROBABILITY REAL DEFAULT 0.0,
                $COL_WAS_BLOCKED INTEGER DEFAULT 0
            )
        """.trimIndent()
        
        db.execSQL(createTable)
        
        // Create indexes for faster searches
        db.execSQL("CREATE INDEX idx_phone_number ON $TABLE_HISTORY($COL_PHONE_NUMBER)")
        db.execSQL("CREATE INDEX idx_timestamp ON $TABLE_HISTORY($COL_TIMESTAMP)")
        db.execSQL("CREATE INDEX idx_risk_score ON $TABLE_HISTORY($COL_RISK_SCORE)")
        
        Log.d(TAG, "Call history database created")
    }
    
    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        db.execSQL("DROP TABLE IF EXISTS $TABLE_HISTORY")
        onCreate(db)
    }
    
    /**
     * Add a call to history
     */
    fun addCall(
        phoneNumber: String,
        callerName: String?,
        callType: String,
        duration: Long = 0,
        riskScore: Int = 0,
        riskLevel: String? = null,
        aiProbability: Float = 0f,
        wasBlocked: Boolean = false
    ): Long {
        val db = writableDatabase
        val values = ContentValues().apply {
            put(COL_PHONE_NUMBER, phoneNumber)
            put(COL_CALLER_NAME, callerName)
            put(COL_CALL_TYPE, callType)
            put(COL_DURATION, duration)
            put(COL_TIMESTAMP, System.currentTimeMillis())
            put(COL_RISK_SCORE, riskScore)
            put(COL_RISK_LEVEL, riskLevel)
            put(COL_AI_PROBABILITY, aiProbability)
            put(COL_WAS_BLOCKED, if (wasBlocked) 1 else 0)
        }
        
        return try {
            val id = db.insert(TABLE_HISTORY, null, values)
            Log.d(TAG, "Call added to history: $phoneNumber (ID: $id)")
            id
        } catch (e: Exception) {
            Log.e(TAG, "Error adding call to history", e)
            -1
        }
    }
    
    /**
     * Get all calls from history
     */
    fun getAllCalls(): List<CallHistoryRecord> {
        val calls = mutableListOf<CallHistoryRecord>()
        val db = readableDatabase
        
        val cursor = db.query(
            TABLE_HISTORY,
            null,
            null,
            null,
            null,
            null,
            "$COL_TIMESTAMP DESC"
        )
        
        cursor.use {
            while (it.moveToNext()) {
                calls.add(CallHistoryRecord(
                    id = it.getLong(it.getColumnIndexOrThrow(COL_ID)),
                    phoneNumber = it.getString(it.getColumnIndexOrThrow(COL_PHONE_NUMBER)),
                    callerName = it.getString(it.getColumnIndexOrThrow(COL_CALLER_NAME)),
                    callType = it.getString(it.getColumnIndexOrThrow(COL_CALL_TYPE)),
                    duration = it.getLong(it.getColumnIndexOrThrow(COL_DURATION)),
                    timestamp = it.getLong(it.getColumnIndexOrThrow(COL_TIMESTAMP)),
                    riskScore = it.getInt(it.getColumnIndexOrThrow(COL_RISK_SCORE)),
                    riskLevel = it.getString(it.getColumnIndexOrThrow(COL_RISK_LEVEL)),
                    aiProbability = it.getFloat(it.getColumnIndexOrThrow(COL_AI_PROBABILITY)),
                    wasBlocked = it.getInt(it.getColumnIndexOrThrow(COL_WAS_BLOCKED)) == 1
                ))
            }
        }
        
        Log.d(TAG, "Retrieved ${calls.size} calls from history")
        return calls
    }
    
    /**
     * Search calls by phone number or name
     */
    fun searchCalls(query: String): List<CallHistoryRecord> {
        val calls = mutableListOf<CallHistoryRecord>()
        val db = readableDatabase
        
        val selection = "$COL_PHONE_NUMBER LIKE ? OR $COL_CALLER_NAME LIKE ?"
        val selectionArgs = arrayOf("%$query%", "%$query%")
        
        val cursor = db.query(
            TABLE_HISTORY,
            null,
            selection,
            selectionArgs,
            null,
            null,
            "$COL_TIMESTAMP DESC"
        )
        
        cursor.use {
            while (it.moveToNext()) {
                calls.add(CallHistoryRecord(
                    id = it.getLong(it.getColumnIndexOrThrow(COL_ID)),
                    phoneNumber = it.getString(it.getColumnIndexOrThrow(COL_PHONE_NUMBER)),
                    callerName = it.getString(it.getColumnIndexOrThrow(COL_CALLER_NAME)),
                    callType = it.getString(it.getColumnIndexOrThrow(COL_CALL_TYPE)),
                    duration = it.getLong(it.getColumnIndexOrThrow(COL_DURATION)),
                    timestamp = it.getLong(it.getColumnIndexOrThrow(COL_TIMESTAMP)),
                    riskScore = it.getInt(it.getColumnIndexOrThrow(COL_RISK_SCORE)),
                    riskLevel = it.getString(it.getColumnIndexOrThrow(COL_RISK_LEVEL)),
                    aiProbability = it.getFloat(it.getColumnIndexOrThrow(COL_AI_PROBABILITY)),
                    wasBlocked = it.getInt(it.getColumnIndexOrThrow(COL_WAS_BLOCKED)) == 1
                ))
            }
        }
        
        return calls
    }
    
    /**
     * Filter calls by risk level
     */
    fun filterByRisk(minRiskScore: Int): List<CallHistoryRecord> {
        val calls = mutableListOf<CallHistoryRecord>()
        val db = readableDatabase
        
        val selection = "$COL_RISK_SCORE >= ?"
        val selectionArgs = arrayOf(minRiskScore.toString())
        
        val cursor = db.query(
            TABLE_HISTORY,
            null,
            selection,
            selectionArgs,
            null,
            null,
            "$COL_TIMESTAMP DESC"
        )
        
        cursor.use {
            while (it.moveToNext()) {
                calls.add(CallHistoryRecord(
                    id = it.getLong(it.getColumnIndexOrThrow(COL_ID)),
                    phoneNumber = it.getString(it.getColumnIndexOrThrow(COL_PHONE_NUMBER)),
                    callerName = it.getString(it.getColumnIndexOrThrow(COL_CALLER_NAME)),
                    callType = it.getString(it.getColumnIndexOrThrow(COL_CALL_TYPE)),
                    duration = it.getLong(it.getColumnIndexOrThrow(COL_DURATION)),
                    timestamp = it.getLong(it.getColumnIndexOrThrow(COL_TIMESTAMP)),
                    riskScore = it.getInt(it.getColumnIndexOrThrow(COL_RISK_SCORE)),
                    riskLevel = it.getString(it.getColumnIndexOrThrow(COL_RISK_LEVEL)),
                    aiProbability = it.getFloat(it.getColumnIndexOrThrow(COL_AI_PROBABILITY)),
                    wasBlocked = it.getInt(it.getColumnIndexOrThrow(COL_WAS_BLOCKED)) == 1
                ))
            }
        }
        
        return calls
    }
    
    /**
     * Delete a call from history
     */
    fun deleteCall(id: Long): Boolean {
        val db = writableDatabase
        val rows = db.delete(TABLE_HISTORY, "$COL_ID = ?", arrayOf(id.toString()))
        return rows > 0
    }
    
    /**
     * Clear all history
     */
    fun clearHistory(): Boolean {
        val db = writableDatabase
        return try {
            db.delete(TABLE_HISTORY, null, null)
            Log.d(TAG, "Call history cleared")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error clearing history", e)
            false
        }
    }
    
    /**
     * Get number of threats blocked today
     */
    fun getThreatsBlockedToday(): Int {
        val db = readableDatabase
        val todayStart = getTodayStartTimestamp()
        
        val selection = "$COL_WAS_BLOCKED = 1 AND $COL_TIMESTAMP >= ?"
        val selectionArgs = arrayOf(todayStart.toString())
        
        val cursor = db.query(
            TABLE_HISTORY,
            arrayOf("COUNT(*) as count"),
            selection,
            selectionArgs,
            null,
            null,
            null
        )
        
        return cursor.use {
            if (it.moveToFirst()) it.getInt(0) else 0
        }
    }
    
    /**
     * Get number of threats blocked this week
     */
    fun getThreatsBlockedThisWeek(): Int {
        val db = readableDatabase
        val weekStart = getWeekStartTimestamp()
        
        val selection = "$COL_WAS_BLOCKED = 1 AND $COL_TIMESTAMP >= ?"
        val selectionArgs = arrayOf(weekStart.toString())
        
        val cursor = db.query(
            TABLE_HISTORY,
            arrayOf("COUNT(*) as count"),
            selection,
            selectionArgs,
            null,
            null,
            null
        )
        
        return cursor.use {
            if (it.moveToFirst()) it.getInt(0) else 0
        }
    }
    
    /**
     * Get count of high-risk calls (risk score >= 70)
     */
    fun getHighRiskCallsCount(): Int {
        val db = readableDatabase
        
        val selection = "$COL_RISK_SCORE >= ?"
        val selectionArgs = arrayOf("70")
        
        val cursor = db.query(
            TABLE_HISTORY,
            arrayOf("COUNT(*) as count"),
            selection,
            selectionArgs,
            null,
            null,
            null
        )
        
        return cursor.use {
            if (it.moveToFirst()) it.getInt(0) else 0
        }
    }
    
    /**
     * Get total calls count
     */
    fun getTotalCallsCount(): Int {
        val db = readableDatabase
        
        val cursor = db.query(
            TABLE_HISTORY,
            arrayOf("COUNT(*) as count"),
            null,
            null,
            null,
            null,
            null
        )
        
        return cursor.use {
            if (it.moveToFirst()) it.getInt(0) else 0
        }
    }
    
    /**
     * Get timestamp for start of today (midnight)
     */
    private fun getTodayStartTimestamp(): Long {
        val calendar = java.util.Calendar.getInstance()
        calendar.set(java.util.Calendar.HOUR_OF_DAY, 0)
        calendar.set(java.util.Calendar.MINUTE, 0)
        calendar.set(java.util.Calendar.SECOND, 0)
        calendar.set(java.util.Calendar.MILLISECOND, 0)
        return calendar.timeInMillis
    }
    
    /**
     * Get timestamp for start of this week (Monday)
     */
    private fun getWeekStartTimestamp(): Long {
        val calendar = java.util.Calendar.getInstance()
        calendar.firstDayOfWeek = java.util.Calendar.MONDAY
        calendar.set(java.util.Calendar.DAY_OF_WEEK, java.util.Calendar.MONDAY)
        calendar.set(java.util.Calendar.HOUR_OF_DAY, 0)
        calendar.set(java.util.Calendar.MINUTE, 0)
        calendar.set(java.util.Calendar.SECOND, 0)
        calendar.set(java.util.Calendar.MILLISECOND, 0)
        return calendar.timeInMillis
    }
}

/**
 * Data class for call history records
 */
data class CallHistoryRecord(
    val id: Long,
    val phoneNumber: String,
    val callerName: String?,
    val callType: String,
    val duration: Long,
    val timestamp: Long,
    val riskScore: Int,
    val riskLevel: String?,
    val aiProbability: Float,
    val wasBlocked: Boolean
)

package com.example.personal

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.util.Log

/**
 * Database for managing blocked numbers and blocking settings
 */
class BlockedNumbersDatabase(context: Context) : SQLiteOpenHelper(
    context,
    DATABASE_NAME,
    null,
    DATABASE_VERSION
) {
    companion object {
        private const val TAG = "BlockedNumbersDB"
        private const val DATABASE_NAME = "blocked_numbers.db"
        private const val DATABASE_VERSION = 1
        
        // Blocked numbers table
        private const val TABLE_BLOCKED = "blocked_numbers"
        private const val COLUMN_ID = "id"
        private const val COLUMN_PHONE = "phone_number"
        private const val COLUMN_BLOCKED_AT = "blocked_at"
        private const val COLUMN_REASON = "reason"
        private const val COLUMN_AUTO_BLOCKED = "auto_blocked"
        
        // Blocking settings table
        private const val TABLE_SETTINGS = "blocking_settings"
        private const val COLUMN_SETTING_ID = "id"
        private const val COLUMN_AUTO_BLOCK_ENABLED = "auto_block_enabled"
        private const val COLUMN_AUTO_BLOCK_THRESHOLD = "auto_block_threshold"
        private const val COLUMN_SEND_AUTO_RESPONSE = "send_auto_response"
        private const val COLUMN_AUTO_RESPONSE_MESSAGE = "auto_response_message"
    }
    
    override fun onCreate(db: SQLiteDatabase) {
        // Create blocked numbers table
        val createBlockedTable = """
            CREATE TABLE $TABLE_BLOCKED (
                $COLUMN_ID INTEGER PRIMARY KEY AUTOINCREMENT,
                $COLUMN_PHONE TEXT UNIQUE NOT NULL,
                $COLUMN_BLOCKED_AT INTEGER NOT NULL,
                $COLUMN_REASON TEXT,
                $COLUMN_AUTO_BLOCKED INTEGER DEFAULT 0
            )
        """.trimIndent()
        
        // Create blocking settings table
        val createSettingsTable = """
            CREATE TABLE $TABLE_SETTINGS (
                $COLUMN_SETTING_ID INTEGER PRIMARY KEY,
                $COLUMN_AUTO_BLOCK_ENABLED INTEGER DEFAULT 0,
                $COLUMN_AUTO_BLOCK_THRESHOLD INTEGER DEFAULT 70,
                $COLUMN_SEND_AUTO_RESPONSE INTEGER DEFAULT 0,
                $COLUMN_AUTO_RESPONSE_MESSAGE TEXT
            )
        """.trimIndent()
        
        db.execSQL(createBlockedTable)
        db.execSQL(createSettingsTable)
        
        // Insert default settings
        val defaultSettings = ContentValues().apply {
            put(COLUMN_SETTING_ID, 1)
            put(COLUMN_AUTO_BLOCK_ENABLED, 0)
            put(COLUMN_AUTO_BLOCK_THRESHOLD, 70)
            put(COLUMN_SEND_AUTO_RESPONSE, 0)
            put(COLUMN_AUTO_RESPONSE_MESSAGE, "This number is blocked. Please do not call again.")
        }
        db.insert(TABLE_SETTINGS, null, defaultSettings)
        
        Log.d(TAG, "Database created successfully")
    }
    
    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        db.execSQL("DROP TABLE IF EXISTS $TABLE_BLOCKED")
        db.execSQL("DROP TABLE IF EXISTS $TABLE_SETTINGS")
        onCreate(db)
    }
    
    /**
     * Block a phone number
     */
    fun blockNumber(phoneNumber: String, reason: String? = null, autoBlocked: Boolean = false): Boolean {
        return try {
            val db = writableDatabase
            val values = ContentValues().apply {
                put(COLUMN_PHONE, phoneNumber)
                put(COLUMN_BLOCKED_AT, System.currentTimeMillis())
                put(COLUMN_REASON, reason)
                put(COLUMN_AUTO_BLOCKED, if (autoBlocked) 1 else 0)
            }
            
            val result = db.insertWithOnConflict(
                TABLE_BLOCKED,
                null,
                values,
                SQLiteDatabase.CONFLICT_REPLACE
            )
            
            Log.d(TAG, "Number blocked: $phoneNumber (auto: $autoBlocked)")
            result != -1L
        } catch (e: Exception) {
            Log.e(TAG, "Error blocking number", e)
            false
        }
    }
    
    /**
     * Unblock a phone number
     */
    fun unblockNumber(phoneNumber: String): Boolean {
        return try {
            val db = writableDatabase
            val result = db.delete(
                TABLE_BLOCKED,
                "$COLUMN_PHONE = ?",
                arrayOf(phoneNumber)
            )
            
            Log.d(TAG, "Number unblocked: $phoneNumber")
            result > 0
        } catch (e: Exception) {
            Log.e(TAG, "Error unblocking number", e)
            false
        }
    }
    
    /**
     * Check if a number is blocked
     */
    fun isBlocked(phoneNumber: String): Boolean {
        return try {
            val db = readableDatabase
            val cursor = db.query(
                TABLE_BLOCKED,
                arrayOf(COLUMN_ID),
                "$COLUMN_PHONE = ?",
                arrayOf(phoneNumber),
                null,
                null,
                null
            )
            
            val blocked = cursor.use { it.count > 0 }
            Log.d(TAG, "Checking if blocked: $phoneNumber = $blocked")
            blocked
        } catch (e: Exception) {
            Log.e(TAG, "Error checking blocked status", e)
            false
        }
    }
    
    /**
     * Get all blocked numbers
     */
    fun getBlockedNumbers(): List<BlockedNumber> {
        val blocked = mutableListOf<BlockedNumber>()
        
        try {
            val db = readableDatabase
            val cursor = db.query(
                TABLE_BLOCKED,
                null,
                null,
                null,
                null,
                null,
                "$COLUMN_BLOCKED_AT DESC"
            )
            
            cursor.use {
                while (it.moveToNext()) {
                    blocked.add(
                        BlockedNumber(
                            id = it.getLong(it.getColumnIndexOrThrow(COLUMN_ID)),
                            phoneNumber = it.getString(it.getColumnIndexOrThrow(COLUMN_PHONE)),
                            blockedAt = it.getLong(it.getColumnIndexOrThrow(COLUMN_BLOCKED_AT)),
                            reason = it.getString(it.getColumnIndexOrThrow(COLUMN_REASON)),
                            autoBlocked = it.getInt(it.getColumnIndexOrThrow(COLUMN_AUTO_BLOCKED)) == 1
                        )
                    )
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting blocked numbers", e)
        }
        
        return blocked
    }
    
    /**
     * Get blocking settings
     */
    fun getSettings(): BlockingSettings {
        return try {
            val db = readableDatabase
            val cursor = db.query(
                TABLE_SETTINGS,
                null,
                "$COLUMN_SETTING_ID = ?",
                arrayOf("1"),
                null,
                null,
                null
            )
            
            cursor.use {
                if (it.moveToFirst()) {
                    BlockingSettings(
                        autoBlockEnabled = it.getInt(it.getColumnIndexOrThrow(COLUMN_AUTO_BLOCK_ENABLED)) == 1,
                        autoBlockThreshold = it.getInt(it.getColumnIndexOrThrow(COLUMN_AUTO_BLOCK_THRESHOLD)),
                        sendAutoResponse = it.getInt(it.getColumnIndexOrThrow(COLUMN_SEND_AUTO_RESPONSE)) == 1,
                        autoResponseMessage = it.getString(it.getColumnIndexOrThrow(COLUMN_AUTO_RESPONSE_MESSAGE)) ?: ""
                    )
                } else {
                    BlockingSettings()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting settings", e)
            BlockingSettings()
        }
    }
    
    /**
     * Update blocking settings
     */
    fun updateSettings(settings: BlockingSettings): Boolean {
        return try {
            val db = writableDatabase
            val values = ContentValues().apply {
                put(COLUMN_AUTO_BLOCK_ENABLED, if (settings.autoBlockEnabled) 1 else 0)
                put(COLUMN_AUTO_BLOCK_THRESHOLD, settings.autoBlockThreshold)
                put(COLUMN_SEND_AUTO_RESPONSE, if (settings.sendAutoResponse) 1 else 0)
                put(COLUMN_AUTO_RESPONSE_MESSAGE, settings.autoResponseMessage)
            }
            
            val result = db.update(
                TABLE_SETTINGS,
                values,
                "$COLUMN_SETTING_ID = ?",
                arrayOf("1")
            )
            
            Log.d(TAG, "Settings updated successfully")
            result > 0
        } catch (e: Exception) {
            Log.e(TAG, "Error updating settings", e)
            false
        }
    }
}

/**
 * Data class for blocked number
 */
data class BlockedNumber(
    val id: Long,
    val phoneNumber: String,
    val blockedAt: Long,
    val reason: String?,
    val autoBlocked: Boolean
)

/**
 * Data class for blocking settings
 */
data class BlockingSettings(
    val autoBlockEnabled: Boolean = false,
    val autoBlockThreshold: Int = 70,
    val sendAutoResponse: Boolean = false,
    val autoResponseMessage: String = "This number is blocked. Please do not call again."
)

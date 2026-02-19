package com.example.personal

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.util.Log

/**
 * Database helper for managing saved contacts during calls
 */
class ContactsDatabase(context: Context) : SQLiteOpenHelper(
    context,
    DATABASE_NAME,
    null,
    DATABASE_VERSION
) {
    
    companion object {
        private const val TAG = "ContactsDatabase"
        private const val DATABASE_NAME = "riskguard_contacts.db"
        private const val DATABASE_VERSION = 2
        
        // Table name
        private const val TABLE_CONTACTS = "saved_contacts"
        
        // Column names
        private const val COLUMN_ID = "id"
        private const val COLUMN_PHONE = "phone_number"
        private const val COLUMN_NAME = "name"
        private const val COLUMN_EMAIL = "email"
        private const val COLUMN_CATEGORY = "category"
        private const val COLUMN_COMPANY = "company"
        private const val COLUMN_NOTES = "notes"
        private const val COLUMN_TAGS = "tags"
        private const val COLUMN_SAVED_AT = "saved_at"
    }
    
    override fun onCreate(db: SQLiteDatabase) {
        val createTable = """
            CREATE TABLE $TABLE_CONTACTS (
                $COLUMN_ID INTEGER PRIMARY KEY AUTOINCREMENT,
                $COLUMN_PHONE TEXT NOT NULL UNIQUE,
                $COLUMN_NAME TEXT,
                $COLUMN_EMAIL TEXT,
                $COLUMN_CATEGORY TEXT,
                $COLUMN_COMPANY TEXT,
                $COLUMN_NOTES TEXT,
                $COLUMN_TAGS TEXT,
                $COLUMN_SAVED_AT INTEGER NOT NULL
            )
        """.trimIndent()
        
        db.execSQL(createTable)
        Log.d(TAG, "Contacts table created")
    }
    
    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        Log.d(TAG, "Upgrading database from version $oldVersion to $newVersion")
        
        when (oldVersion) {
            1 -> {
                // Migrate from version 1 to 2: Add email and category columns
                try {
                    db.execSQL("ALTER TABLE $TABLE_CONTACTS ADD COLUMN $COLUMN_EMAIL TEXT")
                    db.execSQL("ALTER TABLE $TABLE_CONTACTS ADD COLUMN $COLUMN_CATEGORY TEXT")
                    Log.d(TAG, "Successfully added email and category columns")
                } catch (e: Exception) {
                    Log.e(TAG, "Error during migration", e)
                    // If migration fails, recreate table
                    db.execSQL("DROP TABLE IF EXISTS $TABLE_CONTACTS")
                    onCreate(db)
                }
            }
            else -> {
                // For any other version, just recreate
                db.execSQL("DROP TABLE IF EXISTS $TABLE_CONTACTS")
                onCreate(db)
            }
        }
    }
    
    /**
     * Save a contact to database
     */
    fun saveContact(
        phoneNumber: String,
        name: String?,
        email: String?,
        category: String?,
        company: String?,
        notes: String?,
        tags: String?
    ): Boolean {
        return try {
            val db = writableDatabase
            val values = ContentValues().apply {
                put(COLUMN_PHONE, phoneNumber)
                put(COLUMN_NAME, name)
                put(COLUMN_EMAIL, email)
                put(COLUMN_CATEGORY, category)
                put(COLUMN_COMPANY, company)
                put(COLUMN_NOTES, notes)
                put(COLUMN_TAGS, tags)
                put(COLUMN_SAVED_AT, System.currentTimeMillis())
            }
            
            val result = db.insertWithOnConflict(
                TABLE_CONTACTS,
                null,
                values,
                SQLiteDatabase.CONFLICT_REPLACE
            )
            
            Log.d(TAG, "Contact saved: $phoneNumber -> $name (email: $email, category: $category)")
            result != -1L
        } catch (e: Exception) {
            Log.e(TAG, "Error saving contact", e)
            false
        }
    }
    
    /**
     * Get contact by phone number
     */
    fun getContactByPhone(phoneNumber: String): SavedContact? {
        return try {
            val db = readableDatabase
            val cursor = db.query(
                TABLE_CONTACTS,
                null,
                "$COLUMN_PHONE = ?",
                arrayOf(phoneNumber),
                null,
                null,
                null
            )
            
            cursor.use {
                if (it.moveToFirst()) {
                    SavedContact(
                        id = it.getLong(it.getColumnIndexOrThrow(COLUMN_ID)),
                        phoneNumber = it.getString(it.getColumnIndexOrThrow(COLUMN_PHONE)),
                        name = it.getString(it.getColumnIndexOrThrow(COLUMN_NAME)),
                        email = it.getStringOrNull(it.getColumnIndexOrThrow(COLUMN_EMAIL)),
                        category = it.getStringOrNull(it.getColumnIndexOrThrow(COLUMN_CATEGORY)),
                        company = it.getStringOrNull(it.getColumnIndexOrThrow(COLUMN_COMPANY)),
                        notes = it.getStringOrNull(it.getColumnIndexOrThrow(COLUMN_NOTES)),
                        tags = it.getStringOrNull(it.getColumnIndexOrThrow(COLUMN_TAGS)),
                        savedAt = it.getLong(it.getColumnIndexOrThrow(COLUMN_SAVED_AT))
                    )
                } else {
                    null
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting contact", e)
            null
        }
    }
    
    /**
     * Helper function to safely get string or null
     */
    private fun android.database.Cursor.getStringOrNull(columnIndex: Int): String? {
        return if (isNull(columnIndex)) null else getString(columnIndex)
    }
    
    /**
     * Check if a number is known (saved in database)
     */
    fun isKnownNumber(phoneNumber: String): Boolean {
        return getContactByPhone(phoneNumber) != null
    }
    
    /**
     * Update contact information
     */
    fun updateContact(
        phoneNumber: String,
        name: String?,
        email: String?,
        category: String?,
        company: String?,
        notes: String?,
        tags: String?
    ): Boolean {
        return saveContact(phoneNumber, name, email, category, company, notes, tags)
    }
    
    /**
     * Delete a contact
     */
    fun deleteContact(phoneNumber: String): Boolean {
        return try {
            val db = writableDatabase
            val result = db.delete(
                TABLE_CONTACTS,
                "$COLUMN_PHONE = ?",
                arrayOf(phoneNumber)
            )
            Log.d(TAG, "Contact deleted: $phoneNumber")
            result > 0
        } catch (e: Exception) {
            Log.e(TAG, "Error deleting contact", e)
            false
        }
    }

    /**
     * Get all saved contacts
     */
    fun getAllContacts(): List<SavedContact> {
        val contacts = mutableListOf<SavedContact>()
        try {
            val db = readableDatabase
            val cursor = db.query(
                TABLE_CONTACTS,
                null,
                null,
                null,
                null,
                null,
                "$COLUMN_SAVED_AT DESC"
            )
            
            cursor.use {
                while (it.moveToNext()) {
                    contacts.add(
                        SavedContact(
                            id = it.getLong(it.getColumnIndexOrThrow(COLUMN_ID)),
                            phoneNumber = it.getString(it.getColumnIndexOrThrow(COLUMN_PHONE)),
                            name = it.getString(it.getColumnIndexOrThrow(COLUMN_NAME)),
                            email = it.getStringOrNull(it.getColumnIndexOrThrow(COLUMN_EMAIL)),
                            category = it.getStringOrNull(it.getColumnIndexOrThrow(COLUMN_CATEGORY)),
                            company = it.getStringOrNull(it.getColumnIndexOrThrow(COLUMN_COMPANY)),
                            notes = it.getStringOrNull(it.getColumnIndexOrThrow(COLUMN_NOTES)),
                            tags = it.getStringOrNull(it.getColumnIndexOrThrow(COLUMN_TAGS)),
                            savedAt = it.getLong(it.getColumnIndexOrThrow(COLUMN_SAVED_AT))
                        )
                    )
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting all contacts", e)
        }
        return contacts
    }
}

/**
 * Data class for saved contact
 */
data class SavedContact(
    val id: Long,
    val phoneNumber: String,
    val name: String?,
    val email: String?,
    val category: String?,
    val company: String?,
    val notes: String?,
    val tags: String?,
    val savedAt: Long
)

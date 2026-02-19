package com.example.personal

import android.app.*
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.media.MediaRecorder
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.text.Editable
import android.text.InputType
import android.text.TextWatcher
import android.util.Log
import android.view.*
import android.widget.*
import androidx.core.app.NotificationCompat
import java.io.File
import java.text.SimpleDateFormat
import java.util.*

/**
 * Foreground service that displays risk overlay during calls.
 * Uses SYSTEM_ALERT_WINDOW permission to show overlay on top of other apps.
 * Records call audio for AI analysis when call is active.
 */
class CallOverlayService : Service() {
    
    companion object {
        private const val TAG = "CallOverlayService"
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "riskguard_call_service"
        
        const val ACTION_SHOW_OVERLAY = "com.example.personal.SHOW_OVERLAY"
        const val ACTION_HIDE_OVERLAY = "com.example.personal.HIDE_OVERLAY"
        const val ACTION_UPDATE_OVERLAY = "com.example.personal.UPDATE_OVERLAY"
        const val ACTION_UPDATE_RISK = "com.example.personal.UPDATE_RISK"
        const val ACTION_START_RECORDING = "com.example.personal.START_RECORDING"
        const val ACTION_STOP_RECORDING = "com.example.personal.STOP_RECORDING"
        const val ACTION_UPDATE_AI_RESULT = "com.example.personal.UPDATE_AI_RESULT"
        const val ACTION_SHOW_POST_CALL_DETAILS = "com.example.personal.SHOW_POST_CALL_DETAILS"
        
        const val EXTRA_PHONE_NUMBER = "phone_number"
        const val EXTRA_IS_INCOMING = "is_incoming"
        const val EXTRA_RISK_SCORE = "risk_score"
        const val EXTRA_RISK_LEVEL = "risk_level"
        const val EXTRA_EXPLANATION = "explanation"
        const val EXTRA_AI_PROBABILITY = "ai_probability"
        const val EXTRA_AI_IS_SYNTHETIC = "ai_is_synthetic"
        
        var currentRecordingPath: String? = null
            private set
            
        private var isManualRecording = false
    }
    
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var floatingIconView: View? = null
    private var hubDialog: AlertDialog? = null
    private var isOverlayVisible = false
    private var currentPhoneNumber: String = ""
    private var isIncomingCall = true
    
    // Contact database
    private lateinit var contactsDb: ContactsDatabase
    private var isKnownNumber = false
    
    // Audio recording
    private var mediaRecorder: MediaRecorder? = null
    private var isRecording = false
    private var recordingStartTime: Long = 0
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Service created")
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        contactsDb = ContactsDatabase(this)
        createNotificationChannel()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Service start command: ${intent?.action}")
        
        startForeground(NOTIFICATION_ID, createNotification())
        
        when (intent?.action) {
            ACTION_SHOW_OVERLAY -> {
                currentPhoneNumber = intent.getStringExtra(EXTRA_PHONE_NUMBER) ?: ""
                isIncomingCall = intent.getBooleanExtra(EXTRA_IS_INCOMING, true)
                showOverlay()
            }
            ACTION_HIDE_OVERLAY -> {
                stopRecording()
                hideOverlay()
                stopSelf()
            }
            ACTION_UPDATE_OVERLAY -> {
                currentPhoneNumber = intent.getStringExtra(EXTRA_PHONE_NUMBER) ?: currentPhoneNumber
                isIncomingCall = intent.getBooleanExtra(EXTRA_IS_INCOMING, isIncomingCall)
                updateOverlayContent()
            }
            ACTION_UPDATE_RISK -> {
                val score = intent.getIntExtra(EXTRA_RISK_SCORE, 0)
                val level = intent.getStringExtra(EXTRA_RISK_LEVEL) ?: "Unknown"
                val explanation = intent.getStringExtra(EXTRA_EXPLANATION) ?: ""
                updateRiskDisplay(score, level, explanation)
            }
            ACTION_START_RECORDING -> {
                startRecording()
            }
            ACTION_STOP_RECORDING -> {
                stopRecording()
            }
            ACTION_UPDATE_AI_RESULT -> {
                val probability = intent.getFloatExtra(EXTRA_AI_PROBABILITY, 0f)
                val isSynthetic = intent.getBooleanExtra(EXTRA_AI_IS_SYNTHETIC, false)
                updateAIResult(probability, isSynthetic)
            }
            ACTION_SHOW_POST_CALL_DETAILS -> {
                showPostCallDetails()
            }
        }
        
        return START_STICKY
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Service destroyed")
        stopRecording()
        hideOverlay()
    }
    
    // ========== Audio Recording ==========
    
    private fun startRecording() {
        if (isRecording) {
            Log.d(TAG, "Already recording")
            return
        }
        
        try {
            val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
            val fileName = "RiskGuard_Call_$timestamp.m4a"
            
            // Save to a more accessible public folder in Music
            val musicDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC)
            val recordingsDir = File(musicDir, "RiskGuard_Recordings")
            
            if (!recordingsDir.exists()) {
                recordingsDir.mkdirs()
            }
            currentRecordingPath = File(recordingsDir, fileName).absolutePath
            
            mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(this)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }
            
            mediaRecorder?.apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioSamplingRate(44100)
                setAudioEncodingBitRate(128000)
                setOutputFile(currentRecordingPath)
                prepare()
                start()
            }
            
            isRecording = true
            recordingStartTime = System.currentTimeMillis()
            updateRecordingStatus(true)
            
            Log.d(TAG, "Recording started: $currentRecordingPath")
            
            // Notify Flutter that recording started
            MethodChannelHandler.sendRecordingStarted(currentRecordingPath!!)
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start recording", e)
            isRecording = false
            currentRecordingPath = null
        }
    }
    
    private fun stopRecording() {
        if (!isRecording) {
            return
        }
        
        try {
            mediaRecorder?.apply {
                stop()
                release()
            }
            mediaRecorder = null
            isRecording = false
            
            val recordingPath = currentRecordingPath
            updateRecordingStatus(false)
            
            Log.d(TAG, "Recording stopped: $recordingPath")
            
            // Notify Flutter with the recording path for AI analysis
            recordingPath?.let {
                MethodChannelHandler.sendRecordingStopped(it)
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop recording", e)
            mediaRecorder?.release()
            mediaRecorder = null
            isRecording = false
        }
    }
    
    private fun updateRecordingStatus(recording: Boolean) {
        overlayView?.let { view ->
            view.findViewWithTag<LinearLayout>("recording_indicator")?.visibility = 
                if (recording) View.VISIBLE else View.GONE
        }
    }
    
    private fun updateAIResult(probability: Float, isSynthetic: Boolean) {
        val percentText = "${(probability * 100).toInt()}%"
        val statusText = if (isSynthetic) "⚠️ AI Voice Detected" else "✓ Human Voice"
        val color = if (isSynthetic) Color.parseColor("#EF4444") else Color.parseColor("#10B981") // Modern theme colors
        
        overlayView?.let { view ->
            view.findViewWithTag<TextView>("ai_probability")?.apply {
                text = percentText
                setTextColor(color)
            }
            view.findViewWithTag<TextView>("ai_status")?.apply {
                text = statusText
                setTextColor(color)
            }
            view.findViewWithTag<LinearLayout>("ai_result_section")?.apply {
                visibility = View.VISIBLE
                setBackgroundColor(if (isSynthetic) Color.parseColor("#1AEF4444") else Color.parseColor("#1A10B981"))
            }
        }
        
        // Update Hub if open
        hubDialog?.window?.decorView?.findViewWithTag<TextView>("hub_ai_status")?.apply {
            text = statusText
            setTextColor(color)
        }
    }
    
    // ========== Notification ==========
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "RiskGuard Call Protection",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows when RiskGuard is protecting your calls"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )
        
        val recordingText = if (isRecording) " • Recording" else ""
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("RiskGuard Active")
            .setContentText("Protecting your call$recordingText")
            .setSmallIcon(android.R.drawable.ic_menu_call)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
    
    // ========== Overlay ==========
    
    private fun canDrawOverlay(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }
    
    private fun showOverlay() {
        if (!canDrawOverlay()) {
            Log.w(TAG, "Cannot draw overlay - permission not granted")
            return
        }
        
        if (isOverlayVisible) {
            updateOverlayContent()
            return
        }
        
        try {
            createFloatingIcon()
            createMainOverlay()
            isOverlayVisible = true
            
            // Check if number is known
            isKnownNumber = contactsDb.isKnownNumber(currentPhoneNumber)
            Log.d(TAG, "Overlay shown for: $currentPhoneNumber (known: $isKnownNumber)")
            
            // Auto-start recording when overlay is shown (call detected)
            startRecording()
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show overlay", e)
        }
    }
    
    private fun createFloatingIcon() {
        if (floatingIconView != null) return
        
        // Create a modern circular floating action button
        val iconSize = (56 * resources.displayMetrics.density).toInt() // 56dp FAB size
        
        floatingIconView = FrameLayout(this).apply {
            layoutParams = FrameLayout.LayoutParams(iconSize, iconSize)
            
            // Create gradient background
            val gradientDrawable = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                colors = intArrayOf(
                    Color.parseColor("#8B5CF6"), // Purple
                    Color.parseColor("#6366F1")  // Indigo
                )
                gradientType = GradientDrawable.LINEAR_GRADIENT
            }
            background = gradientDrawable
            elevation = 8f
            
            // Add App Icon
            addView(ImageView(context).apply {
                setImageResource(R.mipmap.ic_launcher)
                layoutParams = FrameLayout.LayoutParams(
                    (40 * resources.displayMetrics.density).toInt(),
                    (40 * resources.displayMetrics.density).toInt(),
                    Gravity.CENTER
                )
            })
            
            // Add saved indicator badge if contact is known
            if (isKnownNumber) {
                addView(View(context).apply {
                    val badgeSize = (14 * resources.displayMetrics.density).toInt()
                    layoutParams = FrameLayout.LayoutParams(badgeSize, badgeSize).apply {
                        gravity = Gravity.BOTTOM or Gravity.END
                        bottomMargin = (4 * resources.displayMetrics.density).toInt()
                        marginEnd = (4 * resources.displayMetrics.density).toInt()
                    }
                    val badgeDrawable = GradientDrawable().apply {
                        shape = GradientDrawable.OVAL
                        setColor(Color.parseColor("#10B981")) // Green
                        setStroke(4, Color.WHITE)
                    }
                    background = badgeDrawable
                })
            }
        }
        
        val params = WindowManager.LayoutParams().apply {
            width = iconSize
            height = iconSize
            type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }
            flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
            format = PixelFormat.TRANSLUCENT
            gravity = Gravity.TOP or Gravity.START // Changed to start for better visibility
            x = (16 * resources.displayMetrics.density).toInt()
            y = (200 * resources.displayMetrics.density).toInt()
        }
        
        // Make icon draggable
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        
        floatingIconView?.setOnTouchListener { v, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    params.x = initialX + (event.rawX - initialTouchX).toInt()
                    params.y = initialY + (event.rawY - initialTouchY).toInt()
                    windowManager?.updateViewLayout(floatingIconView, params)
                    true
                }
                MotionEvent.ACTION_UP -> {
                    // If movement was minimal, treat as click
                    val deltaX = Math.abs(initialTouchX - event.rawX)
                    val deltaY = Math.abs(initialTouchY - event.rawY)
                    if (deltaX < 10 && deltaY < 10) {
                        showFeatureHub()
                    }
                    true
                }
                else -> false
            }
        }
        
        try {
            windowManager?.addView(floatingIconView, params)
            Log.d(TAG, "Floating icon added to window")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to add floating icon", e)
        }
    }
    
    private fun createMainOverlay() {
        if (overlayView != null) return
        
        overlayView = createOverlayLayout()
        
        val params = WindowManager.LayoutParams().apply {
            width = WindowManager.LayoutParams.MATCH_PARENT
            height = WindowManager.LayoutParams.WRAP_CONTENT
            type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }
            flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
            format = PixelFormat.TRANSLUCENT
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            y = 100
        }
        
        try {
            windowManager?.addView(overlayView, params)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to add main overlay", e)
        }
    }
    
    private fun createOverlayLayout(): View {
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#E62D2A3E")) // Modern purple from theme
            setPadding(48, 32, 48, 32)
            
            // Header
            addView(LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                
                addView(ImageView(context).apply {
                    setImageResource(android.R.drawable.ic_menu_call)
                    layoutParams = LinearLayout.LayoutParams(64, 64).apply {
                        marginEnd = 24
                    }
                })
                
                addView(LinearLayout(context).apply {
                    orientation = LinearLayout.VERTICAL
                    
                    addView(TextView(context).apply {
                        tag = "title"
                        text = if (isIncomingCall) "Incoming Call" else "Outgoing Call"
                        setTextColor(Color.WHITE)
                        textSize = 18f
                    })
                    
                    addView(TextView(context).apply {
                        tag = "phone_number"
                        text = formatPhoneNumber(currentPhoneNumber)
                        setTextColor(Color.parseColor("#B4B4C7"))
                        textSize = 14f
                    })
                })
            })
            
            // Recording Indicator
            addView(LinearLayout(context).apply {
                tag = "recording_indicator"
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                visibility = View.GONE
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    topMargin = 16
                }
                
                addView(View(context).apply {
                    setBackgroundColor(Color.parseColor("#FF3D71"))
                    layoutParams = LinearLayout.LayoutParams(16, 16).apply {
                        marginEnd = 12
                    }
                })
                
                addView(TextView(context).apply {
                    text = "🎙️ Recording for AI Analysis..."
                    setTextColor(Color.parseColor("#FF3D71"))
                    textSize = 12f
                })
            })
            
            // Divider
            addView(View(context).apply {
                setBackgroundColor(Color.parseColor("#33FFFFFF"))
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    2
                ).apply {
                    topMargin = 24
                    bottomMargin = 24
                }
            })
            
            // Risk Score Section
            addView(LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                
                addView(TextView(context).apply {
                    tag = "risk_score"
                    text = "..."
                    setTextColor(Color.parseColor("#00D68F"))
                    textSize = 48f
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        marginEnd = 24
                    }
                })
                
                addView(LinearLayout(context).apply {
                    orientation = LinearLayout.VERTICAL
                    
                    addView(TextView(context).apply {
                        tag = "risk_level"
                        text = "ANALYZING..."
                        setTextColor(Color.parseColor("#00D68F"))
                        textSize = 14f
                    })
                    
                    addView(TextView(context).apply {
                        tag = "explanation"
                        text = "Checking call risk..."
                        setTextColor(Color.parseColor("#B4B4C7"))
                        textSize = 12f
                    })
                })
            })
            
            // AI Voice Detection Section (ALWAYS VISIBLE - shows progress)
            addView(LinearLayout(context).apply {
                tag = "ai_result_section"
                orientation = LinearLayout.VERTICAL
                setBackgroundColor(Color.parseColor("#1A8B5CF6")) // Purple tint
                setPadding(24, 20, 24, 20)
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    topMargin = 20
                }
                
                // Header
                addView(LinearLayout(context).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER_VERTICAL
                    
                    addView(TextView(context).apply {
                        text = "🤖 AI Voice Analysis"
                        setTextColor(Color.parseColor("#8B5CF6")) // Purple
                        textSize = 16f
                        layoutParams = LinearLayout.LayoutParams(
                            0,
                            LinearLayout.LayoutParams.WRAP_CONTENT,
                            1f
                        )
                    })
                })
                
                // Status and Probability
                addView(LinearLayout(context).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER_VERTICAL
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        topMargin = 12
                    }
                    
                    addView(TextView(context).apply {
                        tag = "ai_status"
                        text = "🔄 Analyzing..."
                        setTextColor(Color.parseColor("#06B6D4")) // Cyan
                        textSize = 18f
                        layoutParams = LinearLayout.LayoutParams(
                            0,
                            LinearLayout.LayoutParams.WRAP_CONTENT,
                            1f
                        )
                    })
                    
                    addView(TextView(context).apply {
                        tag = "ai_probability"
                        text = "---"
                        setTextColor(Color.parseColor("#F9FAFB"))
                        textSize = 24f
                    })
                })
            })
            
            // Close button
            addView(TextView(context).apply {
                text = "✕ Dismiss"
                setTextColor(Color.parseColor("#8F9BB3"))
                textSize = 12f
                gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    topMargin = 24
                }
                setOnClickListener {
                    overlayView?.visibility = View.GONE
                }
            })
        }
    }
    
    private fun toggleOverlayExpanded() {
        overlayView?.let { view ->
            view.visibility = if (view.visibility == View.VISIBLE) View.GONE else View.VISIBLE
        }
    }
    
    private fun updateOverlayContent() {
        overlayView?.let { view ->
            view.findViewWithTag<TextView>("title")?.text = 
                if (isIncomingCall) "Incoming Call" else "Outgoing Call"
            view.findViewWithTag<TextView>("phone_number")?.text = 
                formatPhoneNumber(currentPhoneNumber)
        }
    }
    
    private fun updateRiskDisplay(score: Int, level: String, explanation: String) {
        val color = when {
            score <= 30 -> Color.parseColor("#00D68F")  // Green
            score <= 70 -> Color.parseColor("#FFAA00")  // Amber
            else -> Color.parseColor("#FF3D71")         // Red
        }
        
        overlayView?.let { view ->
            view.findViewWithTag<TextView>("risk_score")?.apply {
                text = score.toString()
                setTextColor(color)
            }
            view.findViewWithTag<TextView>("risk_level")?.apply {
                text = level.uppercase()
                setTextColor(color)
            }
            view.findViewWithTag<TextView>("explanation")?.text = explanation
        }
        
        // Update Hub if open
        hubDialog?.window?.decorView?.findViewWithTag<TextView>("hub_risk_score")?.apply {
            text = score.toString()
            setTextColor(color)
        }
    }
    
    private fun hideOverlay() {
        try {
            overlayView?.let { 
                windowManager?.removeView(it)
                overlayView = null
            }
            floatingIconView?.let {
                windowManager?.removeView(it)
                floatingIconView = null
            }
            isOverlayVisible = false
            Log.d(TAG, "Overlay hidden")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to hide overlay", e)
        }
    }
    
    private fun formatPhoneNumber(number: String): String {
        return if (number.length >= 10) {
            val cleaned = number.replace(Regex("[^0-9+]"), "")
            if (cleaned.startsWith("+")) {
                "${cleaned.substring(0, 3)} ${cleaned.substring(3, 8)} ${cleaned.substring(8)}"
            } else {
                "${cleaned.substring(0, 5)} ${cleaned.substring(5)}"
            }
        } else {
            number
        }
    }
    
    /**
     * Update risk score from external source (called via MethodChannel)
     */
    fun updateRisk(score: Int, level: String, explanation: String) {
        updateRiskDisplay(score, level, explanation)
    }
    
    /**
     * Show unified Feature Hub when floating icon is clicked
     */
    private fun showFeatureHub() {
        val contact = contactsDb.getContactByPhone(currentPhoneNumber)
        
        // Create a scrollable container for the hub
        val scrollView = ScrollView(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT
            )
        }
        
        val hubLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(40, 40, 40, 40)
            setBackgroundColor(Color.parseColor("#1A1B2E")) // Deep dark background
            
            // --- HEADER ---
            addView(LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(0, 0, 0, 32)
                
                addView(ImageView(context).apply {
                    setImageResource(R.mipmap.ic_launcher)
                    layoutParams = LinearLayout.LayoutParams(80, 80)
                })
                
                addView(LinearLayout(context).apply {
                    orientation = LinearLayout.VERTICAL
                    setPadding(24, 0, 0, 0)
                    
                    addView(TextView(context).apply {
                        text = "RiskGuard Feature Hub"
                        textSize = 22f
                        setTextColor(Color.parseColor("#F9FAFB"))
                        setTypeface(null, android.graphics.Typeface.BOLD)
                    })
                    
                    addView(TextView(context).apply {
                        text = formatPhoneNumber(currentPhoneNumber)
                        textSize = 14f
                        setTextColor(Color.parseColor("#9CA3AF"))
                        setPadding(0, 4, 0, 0)
                    })
                })
            })

            // --- RISK & AI STATUS (Consolidated) ---
            addView(createHubSection(context, "🛡️ Live Protection", Color.parseColor("#8B5CF6")).apply {
                val statusLayout = LinearLayout(context).apply {
                    orientation = LinearLayout.HORIZONTAL
                    setPadding(24, 16, 24, 16)
                    
                    // Risk Score
                    addView(LinearLayout(context).apply {
                        orientation = LinearLayout.VERTICAL
                        layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                        gravity = Gravity.CENTER
                        
                        addView(TextView(context).apply {
                            tag = "hub_risk_score"
                            text = overlayView?.findViewWithTag<TextView>("risk_score")?.text ?: "..."
                            textSize = 40f
                            setTextColor(overlayView?.findViewWithTag<TextView>("risk_score")?.currentTextColor ?: Color.parseColor("#10B981"))
                            setTypeface(null, android.graphics.Typeface.BOLD)
                        })
                        addView(TextView(context).apply {
                            text = "RISK SCORE"
                            textSize = 11f
                            setTextColor(Color.parseColor("#9CA3AF"))
                            setTypeface(null, android.graphics.Typeface.BOLD)
                        })
                    })
                    
                    // AI Status
                    addView(LinearLayout(context).apply {
                        orientation = LinearLayout.VERTICAL
                        layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1.5f)
                        gravity = Gravity.CENTER
                        
                        addView(TextView(context).apply {
                            tag = "hub_ai_status"
                            text = overlayView?.findViewWithTag<TextView>("ai_status")?.text ?: "Analyzing..."
                            textSize = 18f
                            setTextColor(overlayView?.findViewWithTag<TextView>("ai_status")?.currentTextColor ?: Color.parseColor("#8B5CF6"))
                            setTypeface(null, android.graphics.Typeface.BOLD)
                        })
                        addView(TextView(context).apply {
                            text = "VOICE ANALYSIS"
                            textSize = 11f
                            setTextColor(Color.parseColor("#9CA3AF"))
                            setTypeface(null, android.graphics.Typeface.BOLD)
                        })
                    })
                }
                addView(statusLayout)
            })

            // --- CONTACT INFORMATION (Editable with Instant Save) ---
            addView(createHubSection(context, "👤 Contact Info", Color.parseColor("#3B82F6")).apply {
                val formLayout = LinearLayout(context).apply {
                    orientation = LinearLayout.VERTICAL
                    setPadding(32, 16, 32, 32)
                    
                    // Name Field
                    addView(createHubLabel(context, "Name"))
                    val nameInput = createHubEditText(context, "Caller Name", contact?.name ?: "").apply {
                        addTextChangedListener(object : TextWatcher {
                            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
                            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
                            override fun afterTextChanged(s: Editable?) {
                                saveFieldInstantly("name", s.toString())
                            }
                        })
                    }
                    addView(nameInput)
                    
                    // Email Field
                    addView(createHubLabel(context, "Email"))
                    val emailInput = createHubEditText(context, "Email Address", contact?.email ?: "").apply {
                        inputType = InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS
                        addTextChangedListener(object : TextWatcher {
                            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
                            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
                            override fun afterTextChanged(s: Editable?) {
                                saveFieldInstantly("email", s.toString())
                            }
                        })
                    }
                    addView(emailInput)
                    
                    // Category Spinner
                    addView(createHubLabel(context, "Category"))
                    val categories = arrayOf("Unknown Caller", "Business", "Personal", "Spam", "Verified")
                    val categorySpinner = Spinner(context).apply {
                        adapter = ArrayAdapter(context, android.R.layout.simple_spinner_item, categories).apply {
                            setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
                        }
                        // Spinner styling in code is limited, but we can set a background
                        val spinnerBg = GradientDrawable().apply {
                            setColor(Color.parseColor("#3F4050"))
                            cornerRadius = 12f
                        }
                        background = spinnerBg
                        setPadding(24, 16, 24, 16)
                        
                        val currentCat = contact?.category ?: "Unknown Caller"
                        val pos = categories.indexOf(currentCat).let { if (it >= 0) it else 0 }
                        setSelection(pos)
                        
                        onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
                            override fun onItemSelected(p0: AdapterView<*>?, p1: View?, p2: Int, p3: Long) {
                                saveFieldInstantly("category", categories[p2])
                            }
                            override fun onNothingSelected(p0: AdapterView<*>?) {}
                        }
                    }
                    addView(categorySpinner)

                    // Company Field
                    addView(createHubLabel(context, "Company"))
                    val companyInput = createHubEditText(context, "Company name", contact?.company ?: "").apply {
                        addTextChangedListener(object : TextWatcher {
                            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
                            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
                            override fun afterTextChanged(s: Editable?) {
                                saveFieldInstantly("company", s.toString())
                            }
                        })
                    }
                    addView(companyInput)

                    // Notes Field
                    addView(createHubLabel(context, "Notes"))
                    val notesInput = createHubEditText(context, "Call notes...", contact?.notes ?: "").apply {
                        addTextChangedListener(object : TextWatcher {
                            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
                            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
                            override fun afterTextChanged(s: Editable?) {
                                saveFieldInstantly("notes", s.toString())
                            }
                        })
                    }
                    addView(notesInput)
                }
                addView(formLayout)
            })

            // --- RECORDING OPTIONS ---
            addView(createHubSection(context, "🎙️ Recording Options", Color.parseColor("#EF4444")).apply {
                val recLayout = LinearLayout(context).apply {
                    orientation = LinearLayout.VERTICAL
                    setPadding(24, 16, 24, 16)
                    
                    addView(TextView(context).apply {
                        text = "Current Status: ${if (isRecording) "Recording..." else "Stopped"}"
                        tag = "hub_rec_status"
                        textSize = 14f
                        setTextColor(if (isRecording) Color.parseColor("#EF4444") else Color.parseColor("#6B7280"))
                    })
                    
                    addView(Button(context).apply {
                        text = (if (isRecording) "Stop Recording" else "Start Recording").uppercase()
                        tag = "hub_rec_button"
                        setTextColor(Color.WHITE)
                        setTypeface(null, android.graphics.Typeface.BOLD)
                        val btnBg = GradientDrawable().apply {
                            setColor(if (isRecording) Color.parseColor("#EF4444") else Color.parseColor("#8B5CF6"))
                            cornerRadius = 12f
                        }
                        background = btnBg
                        layoutParams = LinearLayout.LayoutParams(
                            LinearLayout.LayoutParams.MATCH_PARENT,
                            LinearLayout.LayoutParams.WRAP_CONTENT
                        ).apply {
                            topMargin = 16
                        }
                        setOnClickListener {
                            if (isRecording) {
                                stopRecording()
                                text = "START RECORDING"
                                (background as GradientDrawable).setColor(Color.parseColor("#8B5CF6"))
                                findViewWithTag<TextView>("hub_rec_status")?.apply {
                                    text = "Current Status: Stopped"
                                    setTextColor(Color.parseColor("#9CA3AF"))
                                }
                            } else {
                                startRecording()
                                text = "STOP RECORDING"
                                (background as GradientDrawable).setColor(Color.parseColor("#EF4444"))
                                findViewWithTag<TextView>("hub_rec_status")?.apply {
                                    text = "Current Status: Recording..."
                                    setTextColor(Color.parseColor("#EF4444"))
                                }
                            }
                        }
                    })
                    
                    addView(Button(context).apply {
                        text = "📁 OPEN RECORDINGS"
                        setTextColor(Color.WHITE)
                        setTypeface(null, android.graphics.Typeface.BOLD)
                        val btnBg = GradientDrawable().apply {
                            setColor(Color.parseColor("#3F4050"))
                            cornerRadius = 12f
                        }
                        background = btnBg
                        layoutParams = LinearLayout.LayoutParams(
                            LinearLayout.LayoutParams.MATCH_PARENT,
                            LinearLayout.LayoutParams.WRAP_CONTENT
                        ).apply {
                            topMargin = 12
                        }
                        setOnClickListener {
                            try {
                                val musicDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC)
                                val recordingsDir = File(musicDir, "RiskGuard_Recordings")
                                val intent = Intent(Intent.ACTION_VIEW).apply {
                                    setDataAndType(android.net.Uri.fromFile(recordingsDir), "resource/folder")
                                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                }
                                context.startActivity(intent)
                            } catch (e: Exception) {
                                Toast.makeText(context, "Could not open folder", Toast.LENGTH_SHORT).show()
                            }
                        }
                    })
                    
                    addView(TextView(context).apply {
                        text = "Path: ${currentRecordingPath ?: "None"}"
                        tag = "hub_rec_path"
                        textSize = 10f
                        setTextColor(Color.parseColor("#9CA3AF"))
                        layoutParams = LinearLayout.LayoutParams(
                            LinearLayout.LayoutParams.MATCH_PARENT,
                            LinearLayout.LayoutParams.WRAP_CONTENT
                        ).apply {
                            topMargin = 8
                        }
                    })
                }
                addView(recLayout)
            })

            // --- ACTION BUTTONS ---
            addView(LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.END
                setPadding(0, 32, 0, 0)
                
                addView(Button(context).apply {
                    text = "CLOSE HUB"
                    setTextColor(Color.WHITE)
                    setTypeface(null, android.graphics.Typeface.BOLD)
                    val btnBg = GradientDrawable().apply {
                        setColor(Color.parseColor("#3F4050"))
                        cornerRadius = 12f
                    }
                    background = btnBg
                    setPadding(48, 24, 48, 24)
                    setOnClickListener { view ->
                        dismissDialog(view)
                    }
                })
            })
        }
        
        scrollView.addView(hubLayout)
        
        hubDialog = AlertDialog.Builder(this, android.R.style.Theme_Material_Dialog_NoActionBar)
            .setView(scrollView)
            .setOnDismissListener { hubDialog = null }
            .create()
            
        hubDialog?.let { dialog ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                dialog.window?.setType(WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY)
            } else {
                @Suppress("DEPRECATION")
                dialog.window?.setType(WindowManager.LayoutParams.TYPE_SYSTEM_ALERT)
            }
            dialog.show()
        }
    }

    private fun createHubSection(context: Context, title: String, color: Int): LinearLayout {
        return LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            val bg = GradientDrawable().apply {
                setColor(Color.parseColor("#2D2E3F")) // Dark card color
                cornerRadius = 24f
                setStroke(1, Color.parseColor("#3F4050")) // Subtle border
            }
            background = bg
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = 32
            }
            
            // Section Header
            addView(TextView(context).apply {
                text = title.uppercase()
                textSize = 11f
                setTextColor(color)
                setTypeface(null, android.graphics.Typeface.BOLD)
                setPadding(32, 24, 32, 8)
                letterSpacing = 0.1f
            })
        }
    }

    private fun createHubLabel(context: Context, text: String): TextView {
        return TextView(context).apply {
            this.text = text
            textSize = 12f
            setTextColor(Color.parseColor("#9CA3AF"))
            setPadding(0, 16, 0, 4)
            setTypeface(null, android.graphics.Typeface.BOLD)
        }
    }

    private fun createHubEditText(context: Context, hint: String, text: String): EditText {
        return EditText(context).apply {
            this.hint = hint
            setHintTextColor(Color.parseColor("#4B5563"))
            setText(text)
            textSize = 16f
            setTextColor(Color.parseColor("#F9FAFB"))
            setBackgroundColor(Color.TRANSPARENT)
            setPadding(0, 4, 0, 20)
            
            // Add a bottom line for better alignment feel
            val bottomLine = GradientDrawable().apply {
                setStroke(1, Color.parseColor("#3F4050"))
            }
            // we can't easily set a partial border in code without more complexity, 
            // but we can use setCompoundDrawables or a wrapper. 
            // For now, let's just use better padding and focus colors.
        }
    }

    private fun saveFieldInstantly(field: String, value: String) {
        val contact = contactsDb.getContactByPhone(currentPhoneNumber)
        
        val name = if (field == "name") value else (contact?.name ?: "Unknown")
        val email = if (field == "email") value else (contact?.email ?: "")
        val category = if (field == "category") value else (contact?.category ?: "Unknown Caller")
        val company = if (field == "company") value else (contact?.company ?: "")
        val notes = if (field == "notes") value else (contact?.notes ?: "")
        
        val success = contactsDb.saveContact(
            phoneNumber = currentPhoneNumber,
            name = name,
            email = if (email.isNotEmpty()) email else null,
            category = category,
            company = if (company.isNotEmpty()) company else null,
            notes = if (notes.isNotEmpty()) notes else null,
            tags = contact?.tags
        )
        if (success) {
            val wasNewContact = !isKnownNumber
            isKnownNumber = true
            Log.d("CallOverlayService", "Field $field saved instantly: $value")
            
            // Show visual feedback
            showSaveIndicator("✓ ${field.capitalize()} saved")
            
            // Update floating icon badge if this was first save
            if (wasNewContact) {
                updateFloatingIconBadge()
            }
            
            // Notify Flutter with ALL fields
            MethodChannelHandler.sendContactSaved(
                phoneNumber = currentPhoneNumber,
                name = name,
                email = if (email.isNotEmpty()) email else null,
                category = category,
                company = if (company.isNotEmpty()) company else null,
                notes = if (notes.isNotEmpty()) notes else null
            )
        }
    }

    /**
     * Show visual indicator when field is saved
     */
    private fun showSaveIndicator(message: String) {
        Handler(Looper.getMainLooper()).post {
            Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
        }
    }
    
    /**
     * Update floating icon badge when contact status changes
     */
    private fun updateFloatingIconBadge() {
        floatingIconView?.let {
            windowManager?.removeView(it)
            floatingIconView = null
        }
        createFloatingIcon()
    }
    
    private fun dismissDialog(view: View) {
        var parent = view.parent
        while (parent != null) {
            if (parent is android.app.Dialog) {
                parent.dismiss()
                break
            }
            parent = (parent as? android.view.View)?.parent
        }
    }
    
    /**
     * Show post-call details after call ends
     */
    private fun showPostCallDetails() {
        showFeatureHub() // User existing Feature Hub for summary
    }

    /**
     * Recreate floating icon to update badge
     */
    private fun recreateFloatingIcon() {
        floatingIconView?.let {
            windowManager?.removeView(it)
            floatingIconView = null
        }
        createFloatingIcon()
    }
}

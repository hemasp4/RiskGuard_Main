/// Application-wide constants
import 'package:flutter/foundation.dart' show kIsWeb;

class AppConstants {
  // App Info
  static const String appName = 'RiskGuard';
  static const String appVersion = '2.0.0';
  static const String appTagline = 'AI-Powered Digital Protection';

  // API Endpoints - Auto-detect platform
  // Web/iOS simulator: localhost
  // Android emulator: 10.0.2.2 (special alias for host machine)
  // Physical device: use your computer's LAN IP address
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000';
    }
    // For mobile, use emulator URL by default
    // Change to your LAN IP for physical device testing
    return 'http://10.0.2.2:8000';
  }

  static const String apiVersion = 'v1';

  // Alternative URLs for different environments
  static const String localUrl = 'http://localhost:8000';
  static const String emulatorUrl = 'http://10.0.2.2:8000';

  // API Routes
  static String get apiBase => '$baseUrl/api/$apiVersion';
  static String get voiceAnalysisEndpoint => '$apiBase/analyze/voice';
  static String get voiceRealtimeEndpoint => '$apiBase/analyze/voice/realtime';
  static String get textAnalysisEndpoint => '$apiBase/analyze/text';
  static String get imageAnalysisEndpoint => '$apiBase/analyze/image';
  static String get videoAnalysisEndpoint => '$apiBase/analyze/video';
  static String get riskScoringEndpoint => '$apiBase/score/calculate';
  static String get apiStatusEndpoint => '$apiBase/status';

  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration analysisTimeout = Duration(seconds: 60);
  static const Duration realtimeTimeout = Duration(seconds: 10);
  static const Duration overlayDisplayDuration = Duration(seconds: 5);

  // Analysis Thresholds
  static const int minVoiceSampleDuration = 3; // seconds
  static const int maxVoiceSampleDuration = 30; // seconds
  static const int minTextLength = 10; // characters
  static const int maxTextLength = 5000; // characters

  // AI Detection Thresholds
  static const double aiDetectionThreshold = 0.5; // 50% probability
  static const double highRiskThreshold = 0.7; // 70% for high risk
  static const double lowRiskThreshold = 0.3; // 30% for low risk

  // Scoring Weights (sum should be 1.0)
  static const double callMetadataWeight = 0.25;
  static const double voiceAnalysisWeight = 0.30;
  static const double contentAnalysisWeight = 0.30;
  static const double historyWeight = 0.15;

  // Storage Keys
  static const String themeKey = 'app_theme';
  static const String onboardingCompleteKey = 'onboarding_complete';
  static const String callHistoryKey = 'call_history';
  static const String analysisHistoryKey = 'analysis_history';

  // Method Channel
  static const String methodChannelName = 'com.riskguard.app/channel';

  // Notification Channel
  static const String notificationChannelId = 'riskguard_service';
  static const String notificationChannelName = 'RiskGuard Service';
  static const String notificationChannelDesc =
      'Notifications for call monitoring service';

  // Feature Flags
  static const bool enableVoiceAnalysis = true;
  static const bool enableVideoAnalysis = true;
  static const bool enableImageAnalysis = true;
  static const bool enableTextAnalysis = true;
  static const bool enableCloudAnalysis = true;
  static const bool enableOfflineMode = true;
  static const bool enableRealtimeAnalysis = true;
}

/// Animation durations for consistent UX
class AnimationDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration verySlow = Duration(milliseconds: 800);
}

/// Spacing constants for consistent layouts
class Spacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

/// Border radius constants
class BorderRadii {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double round = 100.0;
}

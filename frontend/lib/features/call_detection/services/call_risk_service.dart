import 'dart:async';
import 'dart:developer' as developer;
import '../../../core/constants/risk_levels.dart';
import '../../../core/services/method_channel_service.dart';
import '../../voice_analysis/services/voice_analyzer_service.dart';

/// Model for call risk analysis result
class CallRiskResult {
  final String phoneNumber;
  final int riskScore;
  final RiskLevel riskLevel;
  final RiskCategory category;
  final String explanation;
  final DateTime analyzedAt;
  final List<String> riskFactors;

  // AI Voice analysis results
  final double? aiVoiceProbability;
  final bool? isAIVoice;
  final String? recordingPath;

  CallRiskResult({
    required this.phoneNumber,
    required this.riskScore,
    required this.riskLevel,
    required this.category,
    required this.explanation,
    required this.analyzedAt,
    this.riskFactors = const [],
    this.aiVoiceProbability,
    this.isAIVoice,
    this.recordingPath,
  });

  CallRiskResult copyWith({
    double? aiVoiceProbability,
    bool? isAIVoice,
    String? recordingPath,
    int? riskScore,
    RiskLevel? riskLevel,
  }) {
    return CallRiskResult(
      phoneNumber: phoneNumber,
      riskScore: riskScore ?? this.riskScore,
      riskLevel: riskLevel ?? this.riskLevel,
      category: category,
      explanation: explanation,
      analyzedAt: analyzedAt,
      riskFactors: riskFactors,
      aiVoiceProbability: aiVoiceProbability ?? this.aiVoiceProbability,
      isAIVoice: isAIVoice ?? this.isAIVoice,
      recordingPath: recordingPath ?? this.recordingPath,
    );
  }

  Map<String, dynamic> toJson() => {
    'phoneNumber': phoneNumber,
    'riskScore': riskScore,
    'riskLevel': riskLevel.name,
    'category': category.name,
    'explanation': explanation,
    'analyzedAt': analyzedAt.toIso8601String(),
    'riskFactors': riskFactors,
    'aiVoiceProbability': aiVoiceProbability,
    'isAIVoice': isAIVoice,
    'recordingPath': recordingPath,
  };
}

/// Service for analyzing call risk with real-time AI voice detection
class CallRiskService {
  final MethodChannelService _methodChannel = MethodChannelService();
  final VoiceAnalyzerService _voiceAnalyzer = VoiceAnalyzerService();

  // Singleton
  static final CallRiskService _instance = CallRiskService._internal();
  factory CallRiskService() => _instance;
  CallRiskService._internal();

  // Stream controller for call events
  final _callStateController = StreamController<CallRiskResult>.broadcast();
  Stream<CallRiskResult> get callStateStream => _callStateController.stream;

  // Current call tracking
  CallRiskResult? _currentCallRisk;
  CallRiskResult? get currentCallRisk => _currentCallRisk;

  /// Initialize the service and set up listeners
  void initialize() {
    _methodChannel.initialize(
      onCallStateChanged: _handleCallStateChanged,
      onCallEnded: _handleCallEnded,
      onRecordingStarted: _handleRecordingStarted,
      onRecordingStopped: _handleRecordingStopped,
      onContactSaved: _handleContactSaved,
      onContactUpdated: _handleContactUpdated,
    );
  }

  /// Handle incoming call state change from native
  Future<void> _handleCallStateChanged(
    String phoneNumber,
    bool isIncoming,
  ) async {
    _log('Call state changed: $phoneNumber, incoming: $isIncoming');

    // Analyze the phone number
    final result = await analyzePhoneNumber(phoneNumber, isIncoming);
    _currentCallRisk = result;
    _callStateController.add(result);

    // Update the native overlay with risk info
    await _methodChannel.showRiskOverlay(
      riskScore: result.riskScore,
      riskLevel: RiskLevels.getLabel(result.riskLevel),
      explanation: result.explanation,
      phoneNumber: phoneNumber,
    );
  }

  /// Handle call ended event
  void _handleCallEnded() {
    _log('Call ended');
    _currentCallRisk = null;
    _methodChannel.hideRiskOverlay();
  }

  /// Handle recording started event from native
  void _handleRecordingStarted(String filePath) {
    _log('Recording started: $filePath');

    // Update current call result with recording path
    if (_currentCallRisk != null) {
      _currentCallRisk = _currentCallRisk!.copyWith(recordingPath: filePath);
      _callStateController.add(_currentCallRisk!);
    }
  }

  /// Handle recording stopped - trigger AI analysis
  Future<void> _handleRecordingStopped(String filePath) async {
    _log('Recording stopped: $filePath, starting AI analysis...');

    try {
      // Analyze the recorded audio for AI voice detection
      final voiceResult = await _voiceAnalyzer.analyzeAudio(filePath);

      _log(
        'AI Analysis complete: synthetic=${voiceResult.syntheticProbability}, isAI=${voiceResult.isLikelyAI}',
      );

      // Update the overlay with AI results
      await _methodChannel.updateAIResult(
        probability: voiceResult.syntheticProbability,
        isSynthetic: voiceResult.isLikelyAI,
      );

      // Update current call result with AI analysis
      if (_currentCallRisk != null) {
        // Update risk score based on AI detection
        int newScore = _currentCallRisk!.riskScore;
        if (voiceResult.isLikelyAI) {
          newScore = (newScore + 40).clamp(0, 100);
        }

        _currentCallRisk = _currentCallRisk!.copyWith(
          aiVoiceProbability: voiceResult.syntheticProbability,
          isAIVoice: voiceResult.isLikelyAI,
          riskScore: newScore,
          riskLevel: RiskLevels.fromScore(newScore),
        );
        _callStateController.add(_currentCallRisk!);

        // Update overlay with new risk score if AI detected
        if (voiceResult.isLikelyAI) {
          await _methodChannel.showRiskOverlay(
            riskScore: newScore,
            riskLevel: 'HIGH RISK - AI VOICE',
            explanation: 'Warning: AI-generated voice detected!',
            phoneNumber: _currentCallRisk!.phoneNumber,
          );
        }
      }
    } catch (e) {
      _log('AI Analysis failed: $e');
    }
  }

  /// Handle contact saved event from native
  void _handleContactSaved(
    String phoneNumber,
    String name,
    String? email,
    String? category,
  ) {
    _log(
      'Contact saved: $name ($phoneNumber) - email: $email, category: $category',
    );

    // If this is for the current call, update the call risk result
    if (_currentCallRisk != null &&
        _currentCallRisk!.phoneNumber == phoneNumber) {
      // Broadcast the update to listeners
      _callStateController.add(_currentCallRisk!);
    }
  }

  /// Handle contact updated event from native
  void _handleContactUpdated(
    String phoneNumber,
    String name,
    String? email,
    String? category,
  ) {
    _log(
      'Contact updated: $name ($phoneNumber) - email: $email, category: $category',
    );

    // If this is for the current call, update the call risk result
    if (_currentCallRisk != null &&
        _currentCallRisk!.phoneNumber == phoneNumber) {
      // Broadcast the update to listeners
      _callStateController.add(_currentCallRisk!);
    }
  }

  /// Analyze a phone number for risk
  Future<CallRiskResult> analyzePhoneNumber(
    String phoneNumber,
    bool isIncoming,
  ) async {
    // Get basic analysis from native
    final nativeAnalysis = await _methodChannel.analyzePhoneNumber(phoneNumber);

    // Calculate comprehensive risk score
    int riskScore = nativeAnalysis['riskScore'] as int? ?? 0;
    final riskFactors = <String>[];

    // Add risk factors based on patterns
    // Unknown number check
    if (!await _isKnownContact(phoneNumber)) {
      riskScore += 15;
      riskFactors.add('Unknown caller');
    }

    // Time-based risk (calls at unusual hours)
    final hour = DateTime.now().hour;
    if (hour < 7 || hour > 22) {
      riskScore += 10;
      riskFactors.add('Call at unusual hour');
    }

    // International number
    if (phoneNumber.startsWith('+') && !phoneNumber.startsWith('+91')) {
      riskScore += 15;
      riskFactors.add('International number');
    }

    // Known spam patterns (example prefixes)
    final spamPrefixes = ['140', '180', '18000'];
    for (final prefix in spamPrefixes) {
      if (phoneNumber.contains(prefix)) {
        riskScore += 25;
        riskFactors.add('Matches spam pattern');
        break;
      }
    }

    // Clamp score to 0-100
    riskScore = riskScore.clamp(0, 100);

    // Determine risk level and category
    final riskLevel = RiskLevels.fromScore(riskScore);
    final category = _determineCategory(riskScore, riskFactors);

    // Generate explanation
    final explanation = _generateExplanation(
      riskLevel,
      riskFactors,
      isIncoming,
    );

    return CallRiskResult(
      phoneNumber: phoneNumber,
      riskScore: riskScore,
      riskLevel: riskLevel,
      category: category,
      explanation: explanation,
      analyzedAt: DateTime.now(),
      riskFactors: riskFactors,
    );
  }

  /// Check if phone number is in contacts (placeholder)
  Future<bool> _isKnownContact(String phoneNumber) async {
    return false;
  }

  /// Determine risk category based on factors
  RiskCategory _determineCategory(int score, List<String> factors) {
    if (factors.contains('Matches spam pattern')) {
      return RiskCategory.scamCall;
    }
    if (factors.contains('Unknown caller')) {
      return RiskCategory.unknown;
    }
    return RiskCategory.unknown;
  }

  /// Generate human-readable explanation
  String _generateExplanation(
    RiskLevel level,
    List<String> factors,
    bool isIncoming,
  ) {
    final callType = isIncoming ? 'incoming call' : 'outgoing call';

    switch (level) {
      case RiskLevel.low:
        return 'This $callType appears to be safe. No suspicious patterns detected.';
      case RiskLevel.medium:
        if (factors.isNotEmpty) {
          return 'This $callType shows some caution signs: ${factors.join(", ")}. Stay alert.';
        }
        return 'This $callType has moderate risk indicators. Exercise caution.';
      case RiskLevel.high:
        if (factors.isNotEmpty) {
          return 'Warning: This $callType shows high-risk patterns: ${factors.join(", ")}. Be very careful.';
        }
        return 'Warning: This $callType has multiple high-risk indicators. Proceed with extreme caution.';
      case RiskLevel.unknown:
        return 'Unable to analyze this $callType. No data available.';
    }
  }

  /// Start call monitoring
  Future<bool> startMonitoring() async {
    _log('Starting call monitoring...');
    return await _methodChannel.startCallMonitoringService();
  }

  /// Stop call monitoring
  Future<bool> stopMonitoring() async {
    _log('Stopping call monitoring...');
    return await _methodChannel.stopCallMonitoringService();
  }

  /// Dispose resources
  void dispose() {
    _callStateController.close();
  }

  void _log(String message) {
    developer.log('[CallRiskService] $message');
  }
}

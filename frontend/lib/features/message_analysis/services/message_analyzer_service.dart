/// Message Analyzer Service - NLP-based phishing, scam, and AI text detection
/// Connects to RiskGuard backend using Hugging Face AI models
library;

import 'package:dio/dio.dart';
import 'dart:developer' as developer;
import '../../../core/constants/app_constants.dart';

/// Types of message threats
enum ThreatType {
  phishing,
  urgency,
  fakeOffer,
  suspiciousLink,
  impersonation,
  financialScam,
  socialEngineering,
  aiGenerated,
  safe,
}

extension ThreatTypeExtension on ThreatType {
  String get label {
    switch (this) {
      case ThreatType.phishing:
        return 'Phishing Attempt';
      case ThreatType.urgency:
        return 'Urgency Manipulation';
      case ThreatType.fakeOffer:
        return 'Fake Offer';
      case ThreatType.suspiciousLink:
        return 'Suspicious Link';
      case ThreatType.impersonation:
        return 'Impersonation';
      case ThreatType.financialScam:
        return 'Financial Scam';
      case ThreatType.socialEngineering:
        return 'Social Engineering';
      case ThreatType.aiGenerated:
        return 'AI-Generated Text';
      case ThreatType.safe:
        return 'Safe';
    }
  }

  String get icon {
    switch (this) {
      case ThreatType.phishing:
        return '🎣';
      case ThreatType.urgency:
        return '⚠️';
      case ThreatType.fakeOffer:
        return '🎁';
      case ThreatType.suspiciousLink:
        return '🔗';
      case ThreatType.impersonation:
        return '🎭';
      case ThreatType.financialScam:
        return '💰';
      case ThreatType.socialEngineering:
        return '🕵️';
      case ThreatType.aiGenerated:
        return '🤖';
      case ThreatType.safe:
        return '✅';
    }
  }
}

/// Result of message analysis
class MessageAnalysisResult {
  // Phishing/Scam detection
  final int riskScore;
  final List<ThreatType> detectedThreats;
  final List<String> suspiciousPatterns;
  final List<String> extractedUrls;
  final String explanation;
  final bool isSafe;

  // AI-Generated text detection
  final double aiGeneratedProbability;
  final double aiConfidence;
  final bool isAiGenerated;
  final String aiExplanation;

  final DateTime analyzedAt;

  MessageAnalysisResult({
    required this.riskScore,
    required this.detectedThreats,
    required this.suspiciousPatterns,
    required this.extractedUrls,
    required this.explanation,
    required this.isSafe,
    required this.aiGeneratedProbability,
    required this.aiConfidence,
    required this.isAiGenerated,
    required this.aiExplanation,
    required this.analyzedAt,
  });

  factory MessageAnalysisResult.fromJson(Map<String, dynamic> json) {
    final threats =
        (json['threats'] as List?)
            ?.map(
              (t) => ThreatType.values.firstWhere(
                (e) => e.name == t,
                orElse: () => ThreatType.safe,
              ),
            )
            .toList() ??
        [];

    // Add AI-generated threat if detected
    final aiProb = (json['aiGeneratedProbability'] as num?)?.toDouble() ?? 0.0;
    if (aiProb >= AppConstants.aiDetectionThreshold &&
        !threats.contains(ThreatType.aiGenerated)) {
      threats.add(ThreatType.aiGenerated);
    }

    return MessageAnalysisResult(
      riskScore: json['riskScore'] ?? 0,
      detectedThreats: threats,
      suspiciousPatterns: List<String>.from(json['patterns'] ?? []),
      extractedUrls: List<String>.from(json['urls'] ?? []),
      explanation: json['explanation'] ?? '',
      isSafe: json['isSafe'] ?? true,
      aiGeneratedProbability: aiProb,
      aiConfidence: (json['aiConfidence'] as num?)?.toDouble() ?? 0.0,
      isAiGenerated: json['isAiGenerated'] ?? false,
      aiExplanation: json['aiExplanation'] ?? '',
      analyzedAt: DateTime.now(),
    );
  }

  factory MessageAnalysisResult.error(String message) {
    return MessageAnalysisResult(
      riskScore: 0,
      detectedThreats: [],
      suspiciousPatterns: [message],
      extractedUrls: [],
      explanation: 'Analysis failed. Please try again.',
      isSafe: true,
      aiGeneratedProbability: 0.0,
      aiConfidence: 0.0,
      isAiGenerated: false,
      aiExplanation: '',
      analyzedAt: DateTime.now(),
    );
  }

  factory MessageAnalysisResult.safe() {
    return MessageAnalysisResult(
      riskScore: 0,
      detectedThreats: [],
      suspiciousPatterns: [],
      extractedUrls: [],
      explanation: 'Message is safe.',
      isSafe: true,
      aiGeneratedProbability: 0.0,
      aiConfidence: 0.0,
      isAiGenerated: false,
      aiExplanation: '',
      analyzedAt: DateTime.now(),
    );
  }

  factory MessageAnalysisResult.loading() {
    return MessageAnalysisResult(
      riskScore: 0,
      detectedThreats: [],
      suspiciousPatterns: ['Analyzing...'],
      extractedUrls: [],
      explanation: 'Analysis in progress...',
      isSafe: true,
      aiGeneratedProbability: 0.0,
      aiConfidence: 0.0,
      isAiGenerated: false,
      aiExplanation: '',
      analyzedAt: DateTime.now(),
    );
  }

  /// Check if this result indicates AI-generated content
  bool get isAiDetected =>
      aiGeneratedProbability >= AppConstants.aiDetectionThreshold;

  /// Get overall risk level
  String get overallRiskLevel {
    final maxRisk = [
      riskScore / 100,
      aiGeneratedProbability,
    ].reduce((a, b) => a > b ? a : b);
    if (maxRisk >= AppConstants.highRiskThreshold) return 'high';
    if (maxRisk >= AppConstants.aiDetectionThreshold) return 'medium';
    return 'low';
  }

  /// Get combined explanation
  String get combinedExplanation {
    if (isAiGenerated && !isSafe) {
      return '$explanation\n\n$aiExplanation';
    } else if (isAiGenerated) {
      return aiExplanation;
    } else {
      return explanation;
    }
  }
}

/// Service for analyzing text messages
class MessageAnalyzerService {
  late final Dio _dio;

  MessageAnalyzerService({Dio? dio}) {
    _dio =
        dio ??
        Dio(
          BaseOptions(
            baseUrl: AppConstants.baseUrl,
            connectTimeout: AppConstants.apiTimeout,
            receiveTimeout: AppConstants.analysisTimeout,
          ),
        );
  }

  /// Analyze a message for threats and AI-generated content
  Future<MessageAnalysisResult> analyzeMessage(String message) async {
    if (message.trim().isEmpty || message.length < AppConstants.minTextLength) {
      if (message.isEmpty) return MessageAnalysisResult.safe();
      return MessageAnalysisResult.error(
        'Text too short. Please provide at least ${AppConstants.minTextLength} characters.',
      );
    }

    if (message.length > AppConstants.maxTextLength) {
      return MessageAnalysisResult.error(
        'Text too long. Maximum ${AppConstants.maxTextLength} characters allowed.',
      );
    }

    try {
      developer.log('Starting text analysis...');
      return await _cloudAnalysis(message);
    } catch (e) {
      developer.log('Message analysis error: $e');
      return MessageAnalysisResult.error(e.toString());
    }
  }

  /// Cloud-based NLP analysis using backend with Hugging Face
  Future<MessageAnalysisResult> _cloudAnalysis(String message) async {
    final response = await _dio.post(
      AppConstants.textAnalysisEndpoint,
      data: {'text': message},
    );

    if (response.statusCode == 200) {
      developer.log('Text analysis response received');
      return MessageAnalysisResult.fromJson(response.data);
    }

    throw Exception('Analysis failed with status: ${response.statusCode}');
  }

  /// Check if the backend is available
  Future<bool> isBackendAvailable() async {
    try {
      final response = await _dio.get(
        '/health',
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

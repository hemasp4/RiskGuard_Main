/// Voice Analyzer Service - Detects synthetic and AI-generated voices
/// Connects to the RiskGuard backend using Hugging Face AI models
/// Supports both mobile (file path) and web (bytes) platforms
library;

import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/constants/app_constants.dart';

/// Voice classification types
enum VoiceClassification { human, aiGenerated, uncertain }

extension VoiceClassificationExtension on VoiceClassification {
  String get label {
    switch (this) {
      case VoiceClassification.human:
        return 'Human Voice';
      case VoiceClassification.aiGenerated:
        return 'AI Generated';
      case VoiceClassification.uncertain:
        return 'Uncertain';
    }
  }

  String get icon {
    switch (this) {
      case VoiceClassification.human:
        return '👤';
      case VoiceClassification.aiGenerated:
        return '🤖';
      case VoiceClassification.uncertain:
        return '❓';
    }
  }
}

/// Result of voice analysis
class VoiceAnalysisResult {
  final double syntheticProbability;
  final double confidence;
  final List<String> detectedPatterns;
  final String explanation;
  final bool isLikelyAI;
  final VoiceClassification classification;
  final String analysisMethod;

  VoiceAnalysisResult({
    required this.syntheticProbability,
    required this.confidence,
    required this.detectedPatterns,
    required this.explanation,
    required this.isLikelyAI,
    required this.classification,
    this.analysisMethod = 'cloud',
  });

  factory VoiceAnalysisResult.fromJson(Map<String, dynamic> json) {
    final syntheticProb = (json['syntheticProbability'] as num).toDouble();
    return VoiceAnalysisResult(
      syntheticProbability: syntheticProb,
      confidence: (json['confidence'] as num).toDouble(),
      detectedPatterns: List<String>.from(json['detectedPatterns'] ?? []),
      explanation: json['explanation'] as String? ?? '',
      isLikelyAI: json['isLikelyAI'] as bool? ?? false,
      classification: _classifyVoice(syntheticProb),
      analysisMethod: json['analysisMethod'] as String? ?? 'cloud',
    );
  }

  factory VoiceAnalysisResult.error(String message) {
    return VoiceAnalysisResult(
      syntheticProbability: 0.0,
      confidence: 0.0,
      detectedPatterns: [message],
      explanation: 'Analysis failed. Please try again.',
      isLikelyAI: false,
      classification: VoiceClassification.uncertain,
      analysisMethod: 'error',
    );
  }

  factory VoiceAnalysisResult.loading() {
    return VoiceAnalysisResult(
      syntheticProbability: 0.0,
      confidence: 0.0,
      detectedPatterns: ['Analyzing...'],
      explanation: 'Analysis in progress...',
      isLikelyAI: false,
      classification: VoiceClassification.uncertain,
      analysisMethod: 'pending',
    );
  }

  Map<String, dynamic> toJson() => {
    'syntheticProbability': syntheticProbability,
    'confidence': confidence,
    'detectedPatterns': detectedPatterns,
    'explanation': explanation,
    'isLikelyAI': isLikelyAI,
    'classification': classification.name,
    'analysisMethod': analysisMethod,
  };

  static VoiceClassification _classifyVoice(double syntheticProbability) {
    if (syntheticProbability < AppConstants.lowRiskThreshold) {
      return VoiceClassification.human;
    } else if (syntheticProbability > AppConstants.aiDetectionThreshold) {
      return VoiceClassification.aiGenerated;
    } else {
      return VoiceClassification.uncertain;
    }
  }

  /// Check if this result indicates AI-generated content
  bool get isAiDetected =>
      syntheticProbability >= AppConstants.aiDetectionThreshold;

  /// Get risk level color representation
  String get riskLevel {
    if (syntheticProbability >= AppConstants.highRiskThreshold) return 'high';
    if (syntheticProbability >= AppConstants.aiDetectionThreshold)
      return 'medium';
    return 'low';
  }
}

/// Service for analyzing voice recordings
class VoiceAnalyzerService {
  late final Dio _dio;

  VoiceAnalyzerService({Dio? dio}) {
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

  /// Analyze audio from bytes (works on Web + Mobile)
  Future<VoiceAnalysisResult> analyzeAudioBytes(
    Uint8List audioBytes,
    String fileName,
  ) async {
    try {
      developer.log('Starting voice analysis from bytes: $fileName');

      final formData = FormData.fromMap({
        'audio': MultipartFile.fromBytes(audioBytes, filename: fileName),
      });

      final response = await _dio.post(
        AppConstants.voiceAnalysisEndpoint,
        data: formData,
      );

      if (response.statusCode == 200) {
        developer.log('Voice analysis response received');
        return VoiceAnalysisResult.fromJson(response.data);
      }

      throw Exception('Analysis failed with status: ${response.statusCode}');
    } catch (e) {
      developer.log('Voice analysis error: $e');
      return VoiceAnalysisResult.error(e.toString());
    }
  }

  /// Analyze an audio file by path (mobile only)
  Future<VoiceAnalysisResult> analyzeAudio(String audioPath) async {
    if (kIsWeb) {
      return VoiceAnalysisResult.error(
        'Use analyzeAudioBytes() on web platform',
      );
    }

    try {
      developer.log('Starting voice analysis for: $audioPath');
      return await _cloudAnalysis(audioPath);
    } catch (e) {
      developer.log('Voice analysis error: $e');
      return VoiceAnalysisResult.error(e.toString());
    }
  }

  /// Real-time voice analysis for call detection (mobile only)
  Future<VoiceAnalysisResult> analyzeAudioRealtime(String audioPath) async {
    if (kIsWeb) {
      return VoiceAnalysisResult.error(
        'Real-time analysis not available on web',
      );
    }

    try {
      final formData = FormData.fromMap({
        'audio': await MultipartFile.fromFile(
          audioPath,
          filename: 'realtime_sample.wav',
        ),
      });

      final response = await _dio.post(
        AppConstants.voiceRealtimeEndpoint,
        data: formData,
        options: Options(receiveTimeout: AppConstants.realtimeTimeout),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return VoiceAnalysisResult(
          syntheticProbability: (data['syntheticProbability'] as num)
              .toDouble(),
          confidence: (data['confidence'] as num).toDouble(),
          detectedPatterns: [],
          explanation: data['status'] == 'analyzed'
              ? 'Real-time analysis complete'
              : data['message'] ?? '',
          isLikelyAI: data['isLikelyAI'] ?? false,
          classification: VoiceClassification.values.firstWhere(
            (c) =>
                c.name ==
                (data['isLikelyAI'] == true ? 'aiGenerated' : 'human'),
            orElse: () => VoiceClassification.uncertain,
          ),
          analysisMethod: 'realtime',
        );
      }

      throw Exception('Real-time analysis failed: ${response.statusCode}');
    } catch (e) {
      developer.log('Real-time voice analysis error: $e');
      return VoiceAnalysisResult.error(e.toString());
    }
  }

  /// Cloud-based analysis using backend API (mobile only - uses file path)
  Future<VoiceAnalysisResult> _cloudAnalysis(String filePath) async {
    developer.log('Sending audio to backend for analysis...');

    final formData = FormData.fromMap({
      'audio': await MultipartFile.fromFile(
        filePath,
        filename: 'voice_sample.wav',
      ),
    });

    final response = await _dio.post(
      AppConstants.voiceAnalysisEndpoint,
      data: formData,
    );

    if (response.statusCode == 200) {
      developer.log('Voice analysis response received');
      return VoiceAnalysisResult.fromJson(response.data);
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

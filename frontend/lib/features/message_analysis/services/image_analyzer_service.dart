/// Image Analyzer Service - Detects AI-generated images
/// Uses Hugging Face umm-maybe/AI-image-detector via backend
/// Supports both mobile (file path) and web (bytes) platforms
library;

import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/constants/app_constants.dart';

/// Image classification types
enum ImageClassification { authentic, aiGenerated, uncertain }

extension ImageClassificationExtension on ImageClassification {
  String get label {
    switch (this) {
      case ImageClassification.authentic:
        return 'Authentic Image';
      case ImageClassification.aiGenerated:
        return 'AI Generated';
      case ImageClassification.uncertain:
        return 'Uncertain';
    }
  }

  String get icon {
    switch (this) {
      case ImageClassification.authentic:
        return '✅';
      case ImageClassification.aiGenerated:
        return '🤖';
      case ImageClassification.uncertain:
        return '❓';
    }
  }
}

/// Result of image analysis
class ImageAnalysisResult {
  final double aiGeneratedProbability;
  final double confidence;
  final List<String> detectedPatterns;
  final String explanation;
  final bool isAiGenerated;
  final ImageClassification classification;
  final String analysisMethod;
  final String modelUsed;
  final DateTime analyzedAt;

  ImageAnalysisResult({
    required this.aiGeneratedProbability,
    required this.confidence,
    required this.detectedPatterns,
    required this.explanation,
    required this.isAiGenerated,
    required this.classification,
    this.analysisMethod = 'cloud',
    this.modelUsed = 'umm-maybe/AI-image-detector',
    DateTime? analyzedAt,
  }) : analyzedAt = analyzedAt ?? DateTime.now();

  factory ImageAnalysisResult.fromJson(Map<String, dynamic> json) {
    final aiProb = (json['aiGeneratedProbability'] as num).toDouble();
    return ImageAnalysisResult(
      aiGeneratedProbability: aiProb,
      confidence: (json['confidence'] as num).toDouble(),
      detectedPatterns: List<String>.from(json['detectedPatterns'] ?? []),
      explanation: json['explanation'] as String? ?? '',
      isAiGenerated: json['isAiGenerated'] as bool? ?? false,
      classification: _classifyImage(aiProb),
      analysisMethod: json['analysisMethod'] as String? ?? 'cloud',
      modelUsed: json['modelUsed'] as String? ?? 'unknown',
    );
  }

  factory ImageAnalysisResult.error(String message) {
    return ImageAnalysisResult(
      aiGeneratedProbability: 0.0,
      confidence: 0.0,
      detectedPatterns: [message],
      explanation: 'Analysis failed. Please try again.',
      isAiGenerated: false,
      classification: ImageClassification.uncertain,
      analysisMethod: 'error',
      modelUsed: 'none',
    );
  }

  factory ImageAnalysisResult.loading() {
    return ImageAnalysisResult(
      aiGeneratedProbability: 0.0,
      confidence: 0.0,
      detectedPatterns: ['Analyzing...'],
      explanation: 'Analysis in progress...',
      isAiGenerated: false,
      classification: ImageClassification.uncertain,
      analysisMethod: 'pending',
      modelUsed: 'loading',
    );
  }

  Map<String, dynamic> toJson() => {
    'aiGeneratedProbability': aiGeneratedProbability,
    'confidence': confidence,
    'detectedPatterns': detectedPatterns,
    'explanation': explanation,
    'isAiGenerated': isAiGenerated,
    'classification': classification.name,
    'analysisMethod': analysisMethod,
    'modelUsed': modelUsed,
    'analyzedAt': analyzedAt.toIso8601String(),
  };

  static ImageClassification _classifyImage(double aiProbability) {
    if (aiProbability < AppConstants.lowRiskThreshold) {
      return ImageClassification.authentic;
    } else if (aiProbability > AppConstants.aiDetectionThreshold) {
      return ImageClassification.aiGenerated;
    } else {
      return ImageClassification.uncertain;
    }
  }

  /// Check if this result indicates AI-generated content
  bool get isAiDetected =>
      aiGeneratedProbability >= AppConstants.aiDetectionThreshold;

  /// Get risk level color representation
  String get riskLevel {
    if (aiGeneratedProbability >= AppConstants.highRiskThreshold) return 'high';
    if (aiGeneratedProbability >= AppConstants.aiDetectionThreshold)
      return 'medium';
    return 'low';
  }
}

/// Service for analyzing images for AI-generated content
class ImageAnalyzerService {
  late final Dio _dio;

  ImageAnalyzerService({Dio? dio}) {
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

  /// Analyze image from bytes (works on Web + Mobile)
  Future<ImageAnalysisResult> analyzeImageBytes(
    Uint8List imageBytes,
    String fileName,
  ) async {
    try {
      developer.log('Starting image analysis from bytes: $fileName');

      // Determine content type from filename
      String contentType = 'image/jpeg';
      final lowerName = fileName.toLowerCase();
      if (lowerName.endsWith('.png')) {
        contentType = 'image/png';
      } else if (lowerName.endsWith('.webp')) {
        contentType = 'image/webp';
      } else if (lowerName.endsWith('.gif')) {
        contentType = 'image/gif';
      }

      final formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(
          imageBytes,
          filename: fileName,
          contentType: DioMediaType.parse(contentType),
        ),
      });

      final response = await _dio.post(
        AppConstants.imageAnalysisEndpoint,
        data: formData,
      );

      if (response.statusCode == 200) {
        developer.log('Image analysis response received');
        return ImageAnalysisResult.fromJson(response.data);
      }

      throw Exception('Analysis failed with status: ${response.statusCode}');
    } catch (e) {
      developer.log('Image analysis error: $e');
      return ImageAnalysisResult.error(e.toString());
    }
  }

  /// Analyze an image file by path (mobile only)
  Future<ImageAnalysisResult> analyzeImage(String imagePath) async {
    if (kIsWeb) {
      return ImageAnalysisResult.error(
        'Use analyzeImageBytes() on web platform',
      );
    }

    try {
      developer.log('Starting image analysis for: $imagePath');
      return await _cloudAnalysis(imagePath);
    } catch (e) {
      developer.log('Image analysis error: $e');
      return ImageAnalysisResult.error(e.toString());
    }
  }

  /// Cloud-based analysis using backend API (mobile only - uses file path)
  Future<ImageAnalysisResult> _cloudAnalysis(String filePath) async {
    developer.log('Sending image to backend for analysis...');

    // Determine content type from extension
    String contentType = 'image/jpeg';
    if (filePath.toLowerCase().endsWith('.png')) {
      contentType = 'image/png';
    } else if (filePath.toLowerCase().endsWith('.webp')) {
      contentType = 'image/webp';
    } else if (filePath.toLowerCase().endsWith('.gif')) {
      contentType = 'image/gif';
    }

    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(
        filePath,
        filename: 'image_sample${_getExtension(filePath)}',
        contentType: DioMediaType.parse(contentType),
      ),
    });

    final response = await _dio.post(
      AppConstants.imageAnalysisEndpoint,
      data: formData,
    );

    if (response.statusCode == 200) {
      developer.log('Image analysis response received');
      return ImageAnalysisResult.fromJson(response.data);
    }

    throw Exception('Analysis failed with status: ${response.statusCode}');
  }

  String _getExtension(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex >= 0) {
      return path.substring(dotIndex);
    }
    return '.jpg';
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

/// Video Analyzer Service - Detects deepfakes and AI-generated videos
/// Uses frame extraction + Hugging Face image detection via backend
/// Supports both mobile (file path) and web (bytes) platforms
library;

import 'dart:typed_data';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/constants/app_constants.dart';

/// Video threat types
enum VideoThreatType { deepfake, faceSwap, lipSync, manipulation, safe }

extension VideoThreatExtension on VideoThreatType {
  String get label {
    switch (this) {
      case VideoThreatType.deepfake:
        return 'Deepfake Detected';
      case VideoThreatType.faceSwap:
        return 'Face Swap';
      case VideoThreatType.lipSync:
        return 'Lip Sync Manipulation';
      case VideoThreatType.manipulation:
        return 'Video Manipulation';
      case VideoThreatType.safe:
        return 'Authentic Video';
    }
  }

  String get icon {
    switch (this) {
      case VideoThreatType.deepfake:
        return '🎭';
      case VideoThreatType.faceSwap:
        return '👥';
      case VideoThreatType.lipSync:
        return '👄';
      case VideoThreatType.manipulation:
        return '✂️';
      case VideoThreatType.safe:
        return '✅';
    }
  }
}

/// Result of video analysis
class VideoAnalysisResult {
  final String videoPath;
  final double deepfakeProbability;
  final double confidence;
  final int analyzedFrames;
  final List<Map<String, dynamic>> frameResults;
  final List<VideoThreatType> detectedThreats;
  final List<String> manipulationPatterns;
  final String explanation;
  final bool isAuthentic;
  final String analysisMethod;
  final DateTime analyzedAt;

  VideoAnalysisResult({
    required this.videoPath,
    required this.deepfakeProbability,
    required this.confidence,
    required this.analyzedFrames,
    required this.frameResults,
    required this.detectedThreats,
    required this.manipulationPatterns,
    required this.explanation,
    required this.isAuthentic,
    this.analysisMethod = 'cloud',
    DateTime? analyzedAt,
  }) : analyzedAt = analyzedAt ?? DateTime.now();

  factory VideoAnalysisResult.fromJson(
    Map<String, dynamic> json,
    String videoPath,
  ) {
    final deepfakeProb = (json['deepfakeProbability'] as num).toDouble();

    // Parse threats
    List<VideoThreatType> threats = [];
    if (json['detectedPatterns'] != null) {
      final patterns = List<String>.from(json['detectedPatterns']);
      if (patterns.any((p) => p.toLowerCase().contains('deepfake'))) {
        threats.add(VideoThreatType.deepfake);
      }
      if (patterns.any((p) => p.toLowerCase().contains('manipulation'))) {
        threats.add(VideoThreatType.manipulation);
      }
    }

    if (threats.isEmpty) {
      threats.add(
        deepfakeProb > AppConstants.aiDetectionThreshold
            ? VideoThreatType.deepfake
            : VideoThreatType.safe,
      );
    }

    return VideoAnalysisResult(
      videoPath: videoPath,
      deepfakeProbability: deepfakeProb,
      confidence: (json['confidence'] as num).toDouble(),
      analyzedFrames: json['analyzedFrames'] ?? 0,
      frameResults: List<Map<String, dynamic>>.from(json['frameResults'] ?? []),
      detectedThreats: threats,
      manipulationPatterns: List<String>.from(json['detectedPatterns'] ?? []),
      explanation: json['explanation'] ?? '',
      isAuthentic: json['isDeepfake'] != true,
      analysisMethod: json['analysisMethod'] ?? 'cloud',
    );
  }

  factory VideoAnalysisResult.error(String videoPath, String message) {
    return VideoAnalysisResult(
      videoPath: videoPath,
      deepfakeProbability: 0.0,
      confidence: 0.0,
      analyzedFrames: 0,
      frameResults: [],
      detectedThreats: [],
      manipulationPatterns: [message],
      explanation: 'Analysis failed. Please try again.',
      isAuthentic: true,
      analysisMethod: 'error',
    );
  }

  factory VideoAnalysisResult.safe(String videoPath) {
    return VideoAnalysisResult(
      videoPath: videoPath,
      deepfakeProbability: 0.0,
      confidence: 1.0,
      analyzedFrames: 0,
      frameResults: [],
      detectedThreats: [VideoThreatType.safe],
      manipulationPatterns: [],
      explanation: 'Video is authentic.',
      isAuthentic: true,
      analysisMethod: 'manual',
    );
  }

  factory VideoAnalysisResult.loading(String videoPath) {
    return VideoAnalysisResult(
      videoPath: videoPath,
      deepfakeProbability: 0.0,
      confidence: 0.0,
      analyzedFrames: 0,
      frameResults: [],
      detectedThreats: [],
      manipulationPatterns: ['Analyzing video frames...'],
      explanation: 'Extracting and analyzing frames...',
      isAuthentic: true,
      analysisMethod: 'pending',
    );
  }

  Map<String, dynamic> toJson() => {
    'videoPath': videoPath,
    'deepfakeProbability': deepfakeProbability,
    'confidence': confidence,
    'analyzedFrames': analyzedFrames,
    'frameResults': frameResults,
    'detectedThreats': detectedThreats.map((t) => t.name).toList(),
    'manipulationPatterns': manipulationPatterns,
    'explanation': explanation,
    'isAuthentic': isAuthentic,
    'analysisMethod': analysisMethod,
    'analyzedAt': analyzedAt.toIso8601String(),
  };

  /// Check if this result indicates AI-generated/deepfake content
  bool get isAiDetected =>
      deepfakeProbability >= AppConstants.aiDetectionThreshold;

  /// Get risk level color representation
  String get riskLevel {
    if (deepfakeProbability >= AppConstants.highRiskThreshold) return 'high';
    if (deepfakeProbability >= AppConstants.aiDetectionThreshold) {
      return 'medium';
    }
    return 'low';
  }
}

/// Service for analyzing videos for deepfakes and manipulation
class VideoAnalyzerService {
  late final Dio _dio;

  VideoAnalyzerService({Dio? dio}) {
    _dio =
        dio ??
        Dio(
          BaseOptions(
            baseUrl: AppConstants.baseUrl,
            connectTimeout: AppConstants.apiTimeout,
            receiveTimeout: const Duration(
              seconds: 120,
            ), // Longer timeout for video
          ),
        );
  }

  /// Analyze a video from bytes (works on Web + Mobile)
  Future<VideoAnalysisResult> analyzeVideoBytes(
    Uint8List videoBytes,
    String fileName,
  ) async {
    try {
      developer.log(
        'Starting video analysis from bytes: $fileName (${videoBytes.length} bytes)',
      );

      if (videoBytes.length < 1000) {
        return VideoAnalysisResult.error(fileName, 'Video file is too small');
      }

      // Determine content type from extension
      String contentType = 'video/mp4';
      final lowerName = fileName.toLowerCase();
      if (lowerName.endsWith('.mov')) {
        contentType = 'video/quicktime';
      } else if (lowerName.endsWith('.avi')) {
        contentType = 'video/x-msvideo';
      } else if (lowerName.endsWith('.webm')) {
        contentType = 'video/webm';
      } else if (lowerName.endsWith('.mkv')) {
        contentType = 'video/x-matroska';
      }

      final formData = FormData.fromMap({
        'video': MultipartFile.fromBytes(
          videoBytes,
          filename: fileName,
          contentType: DioMediaType.parse(contentType),
        ),
      });

      final response = await _dio.post(
        AppConstants.videoAnalysisEndpoint,
        data: formData,
      );

      if (response.statusCode == 200) {
        developer.log('Video analysis response received');
        return VideoAnalysisResult.fromJson(response.data, fileName);
      }

      throw Exception('Analysis failed with status: ${response.statusCode}');
    } catch (e) {
      developer.log('Video analysis error: $e');
      return VideoAnalysisResult.error(fileName, e.toString());
    }
  }

  /// Analyze a video file by path (mobile only)
  Future<VideoAnalysisResult> analyzeVideo(String videoPath) async {
    if (kIsWeb) {
      return VideoAnalysisResult.error(
        videoPath,
        'Use analyzeVideoBytes() on web platform',
      );
    }

    try {
      developer.log('Starting video analysis for: $videoPath');

      // Determine content type from extension
      String contentType = 'video/mp4';
      if (videoPath.toLowerCase().endsWith('.mov')) {
        contentType = 'video/quicktime';
      } else if (videoPath.toLowerCase().endsWith('.avi')) {
        contentType = 'video/x-msvideo';
      } else if (videoPath.toLowerCase().endsWith('.webm')) {
        contentType = 'video/webm';
      }

      final formData = FormData.fromMap({
        'video': await MultipartFile.fromFile(
          videoPath,
          filename: 'video_sample${_getExtension(videoPath)}',
          contentType: DioMediaType.parse(contentType),
        ),
      });

      final response = await _dio.post(
        AppConstants.videoAnalysisEndpoint,
        data: formData,
      );

      if (response.statusCode == 200) {
        developer.log('Video analysis response received');
        return VideoAnalysisResult.fromJson(response.data, videoPath);
      }

      throw Exception('Analysis failed with status: ${response.statusCode}');
    } catch (e) {
      developer.log('Video analysis error: $e');
      return VideoAnalysisResult.error(videoPath, e.toString());
    }
  }

  String _getExtension(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex >= 0) {
      return path.substring(dotIndex);
    }
    return '.mp4';
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

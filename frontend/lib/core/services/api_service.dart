/// API Service
///
/// Handles communication with the RiskGuard backend.
/// Supports configurable backend URL for Cloudflare tunnel integration.
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'langchain_router.dart';

/// API Service for backend communication
class ApiService {
  // Default backend URL (localhost for development)
  static const String _defaultBaseUrl = 'http://localhost:8000';
  static const String _baseUrlKey = 'riskguard_backend_url';

  late final Dio _dio;
  String _baseUrl = _defaultBaseUrl;

  // Singleton
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
      ),
    );

    // Add logging interceptor in debug mode
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: false, // Don't log payload for privacy
          responseBody: false,
          logPrint: (o) => debugPrint('[API] $o'),
        ),
      );
    }
  }

  /// Initialize service and load saved backend URL
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_baseUrlKey) ?? _defaultBaseUrl;
    _dio.options.baseUrl = _baseUrl;
    debugPrint('[ApiService] Initialized with URL: $_baseUrl');
  }

  /// Get current backend URL
  String get baseUrl => _baseUrl;

  /// Set backend URL (for Cloudflare tunnel)
  Future<void> setBackendUrl(String url) async {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    _dio.options.baseUrl = _baseUrl;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, _baseUrl);

    debugPrint('[ApiService] Backend URL set to: $_baseUrl');
  }

  /// Reset to default URL
  Future<void> resetToDefault() async {
    await setBackendUrl(_defaultBaseUrl);
  }

  /// Check if backend is reachable
  Future<bool> isBackendHealthy() async {
    try {
      final response = await _dio.get(
        '/health',
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[ApiService] Health check failed: $e');
      return false;
    }
  }

  /// Get API status
  Future<Map<String, dynamic>?> getApiStatus() async {
    try {
      final response = await _dio.get('/api/v1/status');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[ApiService] Status check failed: $e');
      return null;
    }
  }

  // ==================== Analysis Endpoints ====================

  /// Analyze text for AI-generated content
  Future<AnalysisResult> analyzeText(String text) async {
    try {
      final response = await _dio.post(
        '/api/v1/analyze/text',
        data: {'text': text},
      );

      return _parseAnalysisResult(response.data, InputType.text);
    } catch (e) {
      debugPrint('[ApiService] Text analysis failed: $e');
      return AnalysisResult.safe(
        inputType: InputType.text,
        explanation: 'Cloud analysis unavailable: ${e.toString()}',
        wasLocal: false,
      );
    }
  }

  /// Analyze voice for deepfake detection
  Future<AnalysisResult> analyzeVoice(
    Uint8List audioData, {
    String? filename,
  }) async {
    try {
      final formData = FormData.fromMap({
        'audio': MultipartFile.fromBytes(
          audioData,
          filename: filename ?? 'audio.wav',
        ),
      });

      final response = await _dio.post('/api/v1/analyze/voice', data: formData);

      return _parseAnalysisResult(response.data, InputType.audio);
    } catch (e) {
      debugPrint('[ApiService] Voice analysis failed: $e');
      return AnalysisResult.safe(
        inputType: InputType.audio,
        explanation: 'Cloud analysis unavailable: ${e.toString()}',
        wasLocal: false,
      );
    }
  }

  /// Analyze voice in real-time (streaming chunks)
  Future<AnalysisResult> analyzeVoiceRealtime(Uint8List audioChunk) async {
    try {
      final formData = FormData.fromMap({
        'audio': MultipartFile.fromBytes(audioChunk, filename: 'chunk.wav'),
      });

      final response = await _dio.post(
        '/api/v1/analyze/voice/realtime',
        data: formData,
      );

      return _parseAnalysisResult(response.data, InputType.audio);
    } catch (e) {
      debugPrint('[ApiService] Realtime voice analysis failed: $e');
      return AnalysisResult.safe(
        inputType: InputType.audio,
        explanation: 'Cloud analysis unavailable',
        wasLocal: false,
      );
    }
  }

  /// Analyze image for AI-generated content
  Future<AnalysisResult> analyzeImage(
    dynamic imageData, {
    String? filename,
  }) async {
    try {
      FormData formData;

      if (imageData is Uint8List) {
        formData = FormData.fromMap({
          'image': MultipartFile.fromBytes(
            imageData,
            filename: filename ?? 'image.jpg',
          ),
        });
      } else if (imageData is String) {
        // File path (mobile only)
        formData = FormData.fromMap({
          'image': await MultipartFile.fromFile(imageData),
        });
      } else {
        throw ArgumentError(
          'Invalid image data type: use Uint8List or String path',
        );
      }

      final response = await _dio.post('/api/v1/analyze/image', data: formData);

      return _parseAnalysisResult(response.data, InputType.image);
    } catch (e) {
      debugPrint('[ApiService] Image analysis failed: $e');
      return AnalysisResult.safe(
        inputType: InputType.image,
        explanation: 'Cloud analysis unavailable: ${e.toString()}',
        wasLocal: false,
      );
    }
  }

  /// Analyze video for deepfakes
  Future<AnalysisResult> analyzeVideo(
    dynamic videoData, {
    String? filename,
  }) async {
    try {
      FormData formData;

      if (videoData is Uint8List) {
        formData = FormData.fromMap({
          'video': MultipartFile.fromBytes(
            videoData,
            filename: filename ?? 'video.mp4',
          ),
        });
      } else if (videoData is String) {
        // File path (mobile only)
        formData = FormData.fromMap({
          'video': await MultipartFile.fromFile(videoData),
        });
      } else {
        throw ArgumentError(
          'Invalid video data type: use Uint8List or String path',
        );
      }

      final response = await _dio.post('/api/v1/analyze/video', data: formData);

      return _parseAnalysisResult(response.data, InputType.video);
    } catch (e) {
      debugPrint('[ApiService] Video analysis failed: $e');
      return AnalysisResult.safe(
        inputType: InputType.video,
        explanation: 'Cloud analysis unavailable: ${e.toString()}',
        wasLocal: false,
      );
    }
  }

  // ==================== Helpers ====================

  AnalysisResult _parseAnalysisResult(
    Map<String, dynamic> data,
    InputType inputType,
  ) {
    final confidence = (data['confidence'] as num?)?.toDouble() ?? 0.5;
    final isAiGenerated = data['is_ai_generated'] as bool? ?? false;
    final riskScore = (data['risk_score'] as num?)?.toDouble() ?? confidence;

    // Build explanation from backend response
    String explanation =
        data['explanation'] as String? ??
        data['message'] as String? ??
        'Analysis complete';

    // Add details if available
    final details = data['details'] as Map<String, dynamic>?;
    if (details != null && details.isNotEmpty) {
      final detailStrings = details.entries
          .map((e) => '${e.key}: ${e.value}')
          .take(3) // Limit to 3 details
          .join(', ');
      explanation = '$explanation ($detailStrings)';
    }

    if (isAiGenerated || riskScore > 0.6) {
      return AnalysisResult.threat(
        confidence: riskScore,
        explanation: explanation,
        threatType: _getThreatType(inputType, data),
        inputType: inputType,
        wasLocal: false,
      );
    }

    return AnalysisResult.safe(
      inputType: inputType,
      explanation: explanation,
      wasLocal: false,
    );
  }

  String _getThreatType(InputType type, Map<String, dynamic> data) {
    // Try to get threat type from backend
    final backendType = data['threat_type'] as String?;
    if (backendType != null) return backendType;

    // Default threat types based on input type
    switch (type) {
      case InputType.text:
        return 'ai_generated_text';
      case InputType.audio:
        return 'synthetic_voice';
      case InputType.image:
        return 'ai_generated_image';
      case InputType.video:
        return 'deepfake_video';
      case InputType.url:
        return 'phishing';
      case InputType.unknown:
        return 'unknown';
    }
  }
}

/// Hybrid Analysis Service
/// Combines local TFLite analysis with cloud fallback
class HybridAnalysisService {
  final LangChainRouter _router = LangChainRouter();
  final ApiService _api = ApiService();

  // Singleton
  static final HybridAnalysisService _instance =
      HybridAnalysisService._internal();
  factory HybridAnalysisService() => _instance;
  HybridAnalysisService._internal();

  /// Analyze with hybrid approach: local first, cloud if uncertain
  Future<AnalysisResult> analyze(dynamic input, InputType type) async {
    debugPrint('[HybridAnalysis] Starting hybrid analysis for ${type.name}');

    // Step 1: Run local analysis
    final localResult = await _router.analyzeWithType(input, type);

    debugPrint(
      '[HybridAnalysis] Local result: confidence=${localResult.confidence}, threat=${localResult.isThreat}',
    );

    // Step 2: Check if we need cloud verification
    if (localResult.needsCloudVerification) {
      debugPrint('[HybridAnalysis] Local uncertain, trying cloud...');

      try {
        final cloudResult = await _runCloudAnalysis(input, type);
        debugPrint(
          '[HybridAnalysis] Cloud result: confidence=${cloudResult.confidence}, threat=${cloudResult.isThreat}',
        );
        return cloudResult;
      } catch (e) {
        debugPrint('[HybridAnalysis] Cloud failed, using local result');
        return localResult;
      }
    }

    return localResult;
  }

  Future<AnalysisResult> _runCloudAnalysis(
    dynamic input,
    InputType type,
  ) async {
    switch (type) {
      case InputType.text:
        return await _api.analyzeText(input as String);
      case InputType.audio:
        return await _api.analyzeVoice(input as Uint8List);
      case InputType.image:
        return await _api.analyzeImage(input);
      case InputType.video:
        return await _api.analyzeVideo(input);
      case InputType.url:
        // URL analysis is done locally
        return await _router.analyzeWithType(input, type);
      case InputType.unknown:
        return AnalysisResult.safe(inputType: type);
    }
  }

  /// Quick analysis using local-only (for real-time)
  Future<AnalysisResult> analyzeLocalOnly(dynamic input, InputType type) async {
    return await _router.analyzeWithType(input, type);
  }

  /// Full analysis using cloud-only (for manual uploads)
  Future<AnalysisResult> analyzeCloudOnly(dynamic input, InputType type) async {
    return await _runCloudAnalysis(input, type);
  }
}

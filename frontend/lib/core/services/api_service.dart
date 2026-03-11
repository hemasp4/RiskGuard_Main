/// Centralized API client for RiskGuard backend communication.
/// Handles JSON POST, multipart file upload, GET, and error handling.
/// Privacy-first: no request payload logging.
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import '../models/analysis_models.dart';

// ══════════════════════════════════════════════════════════════════════════════
// API RESULT WRAPPER
// ══════════════════════════════════════════════════════════════════════════════

class ApiResult<T> {
  final T? data;
  final String? error;
  final int? statusCode;

  bool get isSuccess => data != null && error == null;
  bool get isError => error != null;

  ApiResult.success(this.data) : error = null, statusCode = 200;
  ApiResult.failure(this.error, {this.statusCode}) : data = null;
}

// ══════════════════════════════════════════════════════════════════════════════
// API SERVICE (SINGLETON)
// ══════════════════════════════════════════════════════════════════════════════

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final String _baseUrl = ApiConfig.baseUrl;

  // ── Helpers ────────────────────────────────────────────────────────────────

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Map<String, String> get _jsonHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// Parse error message from response body
  String _parseError(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      return body['detail'] ??
          body['message'] ??
          'Server error ${response.statusCode}';
    } catch (_) {
      return 'Server error ${response.statusCode}';
    }
  }

  // ── Health ─────────────────────────────────────────────────────────────────

  /// Check if the backend is reachable
  Future<bool> isBackendHealthy() async {
    try {
      final response = await http
          .get(_uri(ApiConfig.health))
          .timeout(ApiConfig.healthTimeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Get backend status info
  Future<ApiResult<Map<String, dynamic>>> getStatus() async {
    try {
      final response = await http
          .get(_uri(ApiConfig.status))
          .timeout(ApiConfig.defaultTimeout);
      if (response.statusCode == 200) {
        return ApiResult.success(jsonDecode(response.body));
      }
      return ApiResult.failure(
        _parseError(response),
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResult.failure('Connection failed: ${e.toString()}');
    }
  }

  // ── Text Analysis ──────────────────────────────────────────────────────────

  Future<ApiResult<TextAnalysisResult>> analyzeText(
    String text, {
    bool useCloudAI = true,
  }) async {
    try {
      final response = await http
          .post(
            _uri(ApiConfig.textAnalysis),
            headers: _jsonHeaders,
            body: jsonEncode({'text': text, 'useCloudAI': useCloudAI}),
          )
          .timeout(ApiConfig.defaultTimeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return ApiResult.success(TextAnalysisResult.fromJson(json));
      }
      return ApiResult.failure(
        _parseError(response),
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResult.failure('Text analysis failed: ${e.toString()}');
    }
  }

  // ── Voice Analysis ─────────────────────────────────────────────────────────

  /// Upload full audio file for analysis
  Future<ApiResult<VoiceAnalysisResult>> analyzeVoice(
    Uint8List audioBytes, {
    String filename = 'recording.wav',
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        _uri(ApiConfig.voiceAnalysis),
      );
      request.files.add(
        http.MultipartFile.fromBytes('audio', audioBytes, filename: filename),
      );

      final streamedResponse = await request.send().timeout(
        ApiConfig.uploadTimeout,
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return ApiResult.success(VoiceAnalysisResult.fromJson(json));
      }
      return ApiResult.failure(
        _parseError(response),
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResult.failure('Voice analysis failed: ${e.toString()}');
    }
  }

  /// Send real-time audio chunk for quick analysis
  Future<ApiResult<RealtimeVoiceResult>> analyzeVoiceRealtime(
    Uint8List chunkBytes, {
    int chunkIndex = 0,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        _uri(ApiConfig.voiceRealtime),
      );
      request.files.add(
        http.MultipartFile.fromBytes(
          'audio',
          chunkBytes,
          filename: 'chunk_$chunkIndex.wav',
        ),
      );

      final streamedResponse = await request.send().timeout(
        ApiConfig.defaultTimeout,
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return ApiResult.success(RealtimeVoiceResult.fromJson(json));
      }
      return ApiResult.failure(
        _parseError(response),
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResult.failure(
        'Realtime voice analysis failed: ${e.toString()}',
      );
    }
  }

  // ── Image Analysis ─────────────────────────────────────────────────────────

  Future<ApiResult<ImageAnalysisResult>> analyzeImage(
    Uint8List imageBytes, {
    String filename = 'image.png',
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        _uri(ApiConfig.imageAnalysis),
      );
      request.files.add(
        http.MultipartFile.fromBytes('image', imageBytes, filename: filename),
      );

      final streamedResponse = await request.send().timeout(
        ApiConfig.uploadTimeout,
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return ApiResult.success(ImageAnalysisResult.fromJson(json));
      }
      return ApiResult.failure(
        _parseError(response),
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResult.failure('Image analysis failed: ${e.toString()}');
    }
  }

  // ── Video Analysis ─────────────────────────────────────────────────────────

  Future<ApiResult<VideoAnalysisResult>> analyzeVideo(
    Uint8List videoBytes, {
    String filename = 'video.mp4',
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        _uri(ApiConfig.videoAnalysis),
      );
      request.files.add(
        http.MultipartFile.fromBytes('video', videoBytes, filename: filename),
      );

      final streamedResponse = await request.send().timeout(
        ApiConfig.uploadTimeout,
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return ApiResult.success(VideoAnalysisResult.fromJson(json));
      }
      return ApiResult.failure(
        _parseError(response),
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResult.failure('Video analysis failed: ${e.toString()}');
    }
  }

  // ── Risk Scoring ───────────────────────────────────────────────────────────

  Future<ApiResult<RiskScoringResult>> calculateRisk({
    int? callScore,
    int? voiceScore,
    int? contentScore,
    int? historyScore,
    List<String>? riskFactors,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (callScore != null) body['callScore'] = callScore;
      if (voiceScore != null) body['voiceScore'] = voiceScore;
      if (contentScore != null) body['contentScore'] = contentScore;
      if (historyScore != null) body['historyScore'] = historyScore;
      if (riskFactors != null) body['riskFactors'] = riskFactors;

      final response = await http
          .post(
            _uri(ApiConfig.riskCalculate),
            headers: _jsonHeaders,
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.defaultTimeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return ApiResult.success(RiskScoringResult.fromJson(json));
      }
      return ApiResult.failure(
        _parseError(response),
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResult.failure('Risk calculation failed: ${e.toString()}');
    }
  }

  // ── Blockchain Evidence ───────────────────────────────────────────────────

  /// File evidence to the blockchain backend (IPFS + SHA256 + SQLite)
  Future<ApiResult<BlockchainReportResult>> fileBlockchainReport({
    required Uint8List imageBytes,
    String filename = 'evidence.png',
    String profileUrl = '',
    String threatType = 'Deepfake',
    String aiResult = 'AI-Generated',
    double confidence = 0.0,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        _uri(ApiConfig.blockchainReport),
      );
      request.files.add(
        http.MultipartFile.fromBytes('file', imageBytes, filename: filename),
      );
      request.fields['profile_url'] = profileUrl;
      request.fields['threat_type'] = threatType;
      request.fields['ai_result'] = aiResult;
      request.fields['confidence'] = confidence.toString();

      final streamedResponse = await request.send().timeout(
        ApiConfig.uploadTimeout,
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return ApiResult.success(BlockchainReportResult.fromJson(json));
      }
      return ApiResult.failure(
        _parseError(response),
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResult.failure('Blockchain report failed: ${e.toString()}');
    }
  }
}

/// LangChain Router - Smart Model Orchestration
///
/// This router intelligently activates only the required AI models
/// based on input type. Models are loaded lazily and cached for reuse.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

/// Input types that the router can handle
enum InputType { url, text, audio, image, video, unknown }

/// Result of analysis with confidence and explanation
class AnalysisResult {
  final double confidence;
  final bool isThreat;
  final String explanation;
  final String threatType;
  final InputType inputType;
  final DateTime timestamp;
  final bool wasLocalAnalysis;

  const AnalysisResult({
    required this.confidence,
    required this.isThreat,
    required this.explanation,
    required this.threatType,
    required this.inputType,
    required this.timestamp,
    this.wasLocalAnalysis = true,
  });

  /// Safe result (no threat detected)
  factory AnalysisResult.safe({
    required InputType inputType,
    String explanation = 'No threats detected',
    bool wasLocal = true,
  }) {
    return AnalysisResult(
      confidence: 0.95,
      isThreat: false,
      explanation: explanation,
      threatType: 'none',
      inputType: inputType,
      timestamp: DateTime.now(),
      wasLocalAnalysis: wasLocal,
    );
  }

  /// Threat result
  factory AnalysisResult.threat({
    required double confidence,
    required String explanation,
    required String threatType,
    required InputType inputType,
    bool wasLocal = true,
  }) {
    return AnalysisResult(
      confidence: confidence,
      isThreat: true,
      explanation: explanation,
      threatType: threatType,
      inputType: inputType,
      timestamp: DateTime.now(),
      wasLocalAnalysis: wasLocal,
    );
  }

  /// Result is uncertain, needs cloud analysis
  bool get needsCloudVerification => confidence < 0.90 && confidence > 0.10;

  Map<String, dynamic> toJson() => {
    'confidence': confidence,
    'isThreat': isThreat,
    'explanation': explanation,
    'threatType': threatType,
    'inputType': inputType.name,
    'timestamp': timestamp.toIso8601String(),
    'wasLocalAnalysis': wasLocalAnalysis,
  };
}

/// LangChain-style router that activates only needed models
class LangChainRouter {
  // Singleton instance
  static final LangChainRouter _instance = LangChainRouter._internal();
  factory LangChainRouter() => _instance;
  LangChainRouter._internal();

  // Model cache (lazy loaded)
  bool _textModelLoaded = false;
  bool _audioModelLoaded = false;
  bool _imageModelLoaded = false;

  // Confidence threshold for local-only results
  static const double localConfidenceThreshold = 0.90;

  /// Analyze any input - automatically detects type and routes
  Future<AnalysisResult> analyze(dynamic input) async {
    final inputType = detectInputType(input);

    debugPrint('[LangChainRouter] Detected input type: ${inputType.name}');

    switch (inputType) {
      case InputType.url:
        return await _analyzeUrl(input as String);
      case InputType.text:
        return await _analyzeText(input as String);
      case InputType.audio:
        return await _analyzeAudio(input);
      case InputType.image:
        return await _analyzeImage(input);
      case InputType.video:
        return await _analyzeVideo(input);
      case InputType.unknown:
        return AnalysisResult.safe(
          inputType: inputType,
          explanation: 'Unable to determine input type',
        );
    }
  }

  /// Detect the type of input for routing
  InputType detectInputType(dynamic input) {
    if (input == null) return InputType.unknown;

    if (input is String) {
      // Check if it's a URL
      if (_isUrl(input)) return InputType.url;
      // Otherwise treat as text
      return InputType.text;
    }

    if (input is Uint8List) {
      // Binary data - could be audio, image, or video
      // For now, we need additional context
      return InputType.unknown;
    }

    if (input is Map) {
      // Check for type hint in map
      final type = input['type'] as String?;
      if (type == 'audio') return InputType.audio;
      if (type == 'image') return InputType.image;
      if (type == 'video') return InputType.video;
    }

    return InputType.unknown;
  }

  /// Analyze with explicit type (for when caller knows the type)
  Future<AnalysisResult> analyzeWithType(dynamic input, InputType type) async {
    debugPrint('[LangChainRouter] Analyzing as explicit type: ${type.name}');

    switch (type) {
      case InputType.url:
        return await _analyzeUrl(input is String ? input : input.toString());
      case InputType.text:
        return await _analyzeText(input is String ? input : input.toString());
      case InputType.audio:
        return await _analyzeAudio(input);
      case InputType.image:
        return await _analyzeImage(input);
      case InputType.video:
        return await _analyzeVideo(input);
      case InputType.unknown:
        return AnalysisResult.safe(inputType: type);
    }
  }

  // ==================== URL Analysis ====================

  Future<AnalysisResult> _analyzeUrl(String url) async {
    debugPrint('[LangChainRouter] Analyzing URL: $url');

    // URL analysis doesn't need ML models - pure pattern matching
    final riskScore = _calculateUrlRisk(url);

    if (riskScore > 0.7) {
      return AnalysisResult.threat(
        confidence: riskScore,
        explanation: _getUrlExplanation(url),
        threatType: 'phishing',
        inputType: InputType.url,
      );
    }

    return AnalysisResult.safe(
      inputType: InputType.url,
      explanation: 'URL appears safe',
    );
  }

  double _calculateUrlRisk(String url) {
    double risk = 0.0;
    final urlLower = url.toLowerCase();

    // Check for IP-based URLs (suspicious)
    if (RegExp(r'https?://\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}').hasMatch(url)) {
      risk += 0.4;
    }

    // Check for typosquatting patterns
    final typosquatPatterns = [
      'faceb00k',
      'g00gle',
      'amaz0n',
      'paypa1',
      'app1e',
      'micros0ft',
      'netf1ix',
      'instgram',
      'twiter',
      'linkedln',
    ];
    for (final pattern in typosquatPatterns) {
      if (urlLower.contains(pattern)) {
        risk += 0.5;
        break;
      }
    }

    // Check for suspicious TLDs
    final suspiciousTlds = ['.xyz', '.tk', '.ml', '.ga', '.cf', '.gq', '.top'];
    for (final tld in suspiciousTlds) {
      if (urlLower.endsWith(tld) || urlLower.contains('$tld/')) {
        risk += 0.3;
        break;
      }
    }

    // Check for excessive subdomains
    final uri = Uri.tryParse(url);
    if (uri != null && uri.host.split('.').length > 4) {
      risk += 0.2;
    }

    // Check for urgency keywords in URL
    final urgencyPatterns = [
      'urgent',
      'verify',
      'suspended',
      'confirm',
      'secure',
      'update',
      'login',
      'password',
      'account',
    ];
    for (final pattern in urgencyPatterns) {
      if (urlLower.contains(pattern)) {
        risk += 0.1;
      }
    }

    return risk.clamp(0.0, 1.0);
  }

  String _getUrlExplanation(String url) {
    final explanations = <String>[];
    final urlLower = url.toLowerCase();

    if (RegExp(r'https?://\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}').hasMatch(url)) {
      explanations.add('URL uses an IP address instead of a domain name');
    }

    final typosquatPatterns = {
      'faceb00k': 'Facebook',
      'g00gle': 'Google',
      'amaz0n': 'Amazon',
      'paypa1': 'PayPal',
      'app1e': 'Apple',
    };
    for (final entry in typosquatPatterns.entries) {
      if (urlLower.contains(entry.key)) {
        explanations.add('URL mimics ${entry.value} (typosquatting)');
        break;
      }
    }

    final suspiciousTlds = ['.xyz', '.tk', '.ml', '.ga', '.cf'];
    for (final tld in suspiciousTlds) {
      if (urlLower.contains(tld)) {
        explanations.add('Uses suspicious domain extension ($tld)');
        break;
      }
    }

    if (explanations.isEmpty) {
      return 'URL contains suspicious patterns';
    }

    return explanations.join('. ');
  }

  // ==================== Text Analysis ====================

  Future<AnalysisResult> _analyzeText(String text) async {
    debugPrint('[LangChainRouter] Analyzing text (${text.length} chars)');

    // Lazy load text model
    await _ensureTextModelLoaded();

    // For now, use pattern-based detection
    // TODO: Replace with actual TFLite inference
    final riskScore = _calculateTextRisk(text);

    if (riskScore > 0.6) {
      return AnalysisResult.threat(
        confidence: riskScore,
        explanation: _getTextExplanation(text),
        threatType: 'ai_generated',
        inputType: InputType.text,
      );
    }

    return AnalysisResult.safe(
      inputType: InputType.text,
      explanation: 'Text appears authentic',
    );
  }

  Future<void> _ensureTextModelLoaded() async {
    if (_textModelLoaded) return;

    debugPrint('[LangChainRouter] Loading text model (lazy)...');
    // TODO: Load actual TFLite model
    // final interpreter = await Interpreter.fromAsset('assets/models/text_classifier.tflite');
    _textModelLoaded = true;
    debugPrint('[LangChainRouter] Text model loaded');
  }

  double _calculateTextRisk(String text) {
    double risk = 0.0;

    // Check for phishing keywords
    final phishingKeywords = [
      'verify your account',
      'suspended',
      'unusual activity',
      'click here immediately',
      'confirm your identity',
      'update your payment',
      'expire within',
      'act now',
      'limited time offer',
      'you have won',
      'congratulations',
    ];

    final textLower = text.toLowerCase();
    for (final keyword in phishingKeywords) {
      if (textLower.contains(keyword)) {
        risk += 0.15;
      }
    }

    // Check for AI-generated text patterns (uniformity)
    final sentences = text.split(RegExp(r'[.!?]'));
    if (sentences.length > 3) {
      // Check sentence length variance (AI text tends to be uniform)
      final lengths = sentences
          .map((s) => s.trim().length)
          .where((l) => l > 0)
          .toList();
      if (lengths.isNotEmpty) {
        final avgLength = lengths.reduce((a, b) => a + b) / lengths.length;
        final variance =
            lengths.map((l) => (l - avgLength).abs()).reduce((a, b) => a + b) /
            lengths.length;

        // Low variance suggests AI-generated
        if (variance < 10 && sentences.length > 5) {
          risk += 0.3;
        }
      }
    }

    // Check for excessive formality markers
    final formalityMarkers = [
      'furthermore',
      'moreover',
      'additionally',
      'in conclusion',
      'therefore',
    ];
    int formalityCount = 0;
    for (final marker in formalityMarkers) {
      if (textLower.contains(marker)) formalityCount++;
    }
    if (formalityCount >= 3) {
      risk += 0.2;
    }

    return risk.clamp(0.0, 1.0);
  }

  String _getTextExplanation(String text) {
    final explanations = <String>[];
    final textLower = text.toLowerCase();

    // Check specific patterns
    if (textLower.contains('verify') || textLower.contains('confirm')) {
      explanations.add(
        'Contains verification/confirmation requests typical of phishing',
      );
    }

    if (textLower.contains('urgent') || textLower.contains('immediately')) {
      explanations.add('Uses urgency tactics common in scam messages');
    }

    if (textLower.contains('click here') || textLower.contains('click below')) {
      explanations.add('Contains suspicious call-to-action links');
    }

    // Check for low variance (AI pattern)
    final sentences = text.split(RegExp(r'[.!?]'));
    if (sentences.length > 5) {
      explanations.add('Text shows unnaturally uniform sentence patterns');
    }

    if (explanations.isEmpty) {
      return 'Text shows patterns consistent with AI-generated content';
    }

    return explanations.join('. ');
  }

  // ==================== Audio Analysis ====================

  Future<AnalysisResult> _analyzeAudio(dynamic audioData) async {
    debugPrint('[LangChainRouter] Analyzing audio');

    // Lazy load audio model
    await _ensureAudioModelLoaded();

    // TODO: Implement actual audio analysis with TFLite YAMNet
    // For now, return placeholder result
    return AnalysisResult.safe(
      inputType: InputType.audio,
      explanation: 'Audio analysis pending TFLite integration',
    );
  }

  Future<void> _ensureAudioModelLoaded() async {
    if (_audioModelLoaded) return;

    debugPrint('[LangChainRouter] Loading audio model (lazy)...');
    // TODO: Load YAMNet TFLite model
    _audioModelLoaded = true;
    debugPrint('[LangChainRouter] Audio model loaded');
  }

  // ==================== Image Analysis ====================

  Future<AnalysisResult> _analyzeImage(dynamic imageData) async {
    debugPrint('[LangChainRouter] Analyzing image');

    // Lazy load image model
    await _ensureImageModelLoaded();

    // TODO: Implement actual image analysis with TFLite MobileNet
    // For now, return placeholder result
    return AnalysisResult.safe(
      inputType: InputType.image,
      explanation: 'Image analysis pending TFLite integration',
    );
  }

  Future<void> _ensureImageModelLoaded() async {
    if (_imageModelLoaded) return;

    debugPrint('[LangChainRouter] Loading image model (lazy)...');
    // TODO: Load MobileNetV2 TFLite model
    _imageModelLoaded = true;
    debugPrint('[LangChainRouter] Image model loaded');
  }

  // ==================== Video Analysis ====================

  Future<AnalysisResult> _analyzeVideo(dynamic videoData) async {
    debugPrint('[LangChainRouter] Analyzing video');

    // Video analysis extracts frames and uses image model
    await _ensureImageModelLoaded();

    // TODO: Extract keyframes and analyze each
    // For now, return placeholder result
    return AnalysisResult.safe(
      inputType: InputType.video,
      explanation: 'Video analysis pending keyframe extraction',
    );
  }

  // ==================== Helpers ====================

  bool _isUrl(String text) {
    final trimmed = text.trim();
    return trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('www.') ||
        RegExp(r'^[a-zA-Z0-9][-a-zA-Z0-9]*\.[a-zA-Z]{2,}').hasMatch(trimmed);
  }

  /// Clear model cache (useful for memory management)
  void clearCache() {
    _textModelLoaded = false;
    _audioModelLoaded = false;
    _imageModelLoaded = false;
    debugPrint('[LangChainRouter] Model cache cleared');
  }

  /// Get info about loaded models
  Map<String, bool> getLoadedModels() => {
    'text': _textModelLoaded,
    'audio': _audioModelLoaded,
    'image': _imageModelLoaded,
  };
}

/// Dart data models matching the FastAPI backend Pydantic schemas exactly.
/// These are used to deserialize JSON responses from the backend.

// ══════════════════════════════════════════════════════════════════════════════
// TEXT ANALYSIS
// ══════════════════════════════════════════════════════════════════════════════

class TextAnalysisResult {
  final int riskScore;
  final List<String> threats;
  final List<String> patterns;
  final List<String> urls;
  final String explanation;
  final bool isSafe;
  final double aiGeneratedProbability;
  final double aiConfidence;
  final bool isAiGenerated;
  final String aiExplanation;
  final String analysisMethod;
  final Map<String, dynamic>? aiSubScores;

  TextAnalysisResult({
    required this.riskScore,
    required this.threats,
    required this.patterns,
    required this.urls,
    required this.explanation,
    required this.isSafe,
    required this.aiGeneratedProbability,
    required this.aiConfidence,
    required this.isAiGenerated,
    required this.aiExplanation,
    required this.analysisMethod,
    this.aiSubScores,
  });

  factory TextAnalysisResult.fromJson(Map<String, dynamic> json) {
    return TextAnalysisResult(
      riskScore: (json['riskScore'] ?? 0) as int,
      threats: List<String>.from(json['threats'] ?? []),
      patterns: List<String>.from(json['patterns'] ?? []),
      urls: List<String>.from(json['urls'] ?? []),
      explanation: json['explanation'] ?? '',
      isSafe: json['isSafe'] ?? true,
      aiGeneratedProbability: (json['aiGeneratedProbability'] ?? 0.0)
          .toDouble(),
      aiConfidence: (json['aiConfidence'] ?? 0.0).toDouble(),
      isAiGenerated: json['isAiGenerated'] ?? false,
      aiExplanation: json['aiExplanation'] ?? '',
      analysisMethod: json['analysisMethod'] ?? 'unknown',
      aiSubScores: json['aiSubScores'] as Map<String, dynamic>?,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// VOICE ANALYSIS
// ══════════════════════════════════════════════════════════════════════════════

class VoiceAnalysisResult {
  final double syntheticProbability;
  final double confidence;
  final List<String> detectedPatterns;
  final String explanation;
  final bool isLikelyAI;
  final String analysisMethod;
  final double processingTimeMs;
  final Map<String, dynamic>? subScores;

  VoiceAnalysisResult({
    required this.syntheticProbability,
    required this.confidence,
    required this.detectedPatterns,
    required this.explanation,
    required this.isLikelyAI,
    required this.analysisMethod,
    required this.processingTimeMs,
    this.subScores,
  });

  factory VoiceAnalysisResult.fromJson(Map<String, dynamic> json) {
    return VoiceAnalysisResult(
      syntheticProbability: (json['syntheticProbability'] ?? 0.0).toDouble(),
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      detectedPatterns: List<String>.from(json['detectedPatterns'] ?? []),
      explanation: json['explanation'] ?? '',
      isLikelyAI: json['isLikelyAI'] ?? false,
      analysisMethod: json['analysisMethod'] ?? 'unknown',
      processingTimeMs: (json['processingTimeMs'] ?? 0.0).toDouble(),
      subScores: json['subScores'] as Map<String, dynamic>?,
    );
  }
}

class RealtimeVoiceResult {
  final double syntheticProbability;
  final double confidence;
  final bool isLikelyAI;
  final String status;
  final double processingTimeMs;
  final double? vadSpeechRatio;
  final int? chunkIndex;

  RealtimeVoiceResult({
    required this.syntheticProbability,
    required this.confidence,
    required this.isLikelyAI,
    required this.status,
    required this.processingTimeMs,
    this.vadSpeechRatio,
    this.chunkIndex,
  });

  factory RealtimeVoiceResult.fromJson(Map<String, dynamic> json) {
    return RealtimeVoiceResult(
      syntheticProbability: (json['syntheticProbability'] ?? 0.0).toDouble(),
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      isLikelyAI: json['isLikelyAI'] ?? false,
      status: json['status'] ?? 'unknown',
      processingTimeMs: (json['processingTimeMs'] ?? 0.0).toDouble(),
      vadSpeechRatio: (json['vadSpeechRatio'] as num?)?.toDouble(),
      chunkIndex: json['chunkIndex'] as int?,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// IMAGE ANALYSIS
// ══════════════════════════════════════════════════════════════════════════════

class ImageAnalysisResult {
  final double aiGeneratedProbability;
  final double confidence;
  final List<String> detectedPatterns;
  final String explanation;
  final bool isAiGenerated;
  final String analysisMethod;
  final String modelUsed;
  final double processingTimeMs;
  final Map<String, dynamic>? subScores;

  ImageAnalysisResult({
    required this.aiGeneratedProbability,
    required this.confidence,
    required this.detectedPatterns,
    required this.explanation,
    required this.isAiGenerated,
    required this.analysisMethod,
    required this.modelUsed,
    required this.processingTimeMs,
    this.subScores,
  });

  factory ImageAnalysisResult.fromJson(Map<String, dynamic> json) {
    return ImageAnalysisResult(
      aiGeneratedProbability: (json['aiGeneratedProbability'] ?? 0.0)
          .toDouble(),
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      detectedPatterns: List<String>.from(json['detectedPatterns'] ?? []),
      explanation: json['explanation'] ?? '',
      isAiGenerated: json['isAiGenerated'] ?? false,
      analysisMethod: json['analysisMethod'] ?? 'unknown',
      modelUsed: json['modelUsed'] ?? 'unknown',
      processingTimeMs: (json['processingTimeMs'] ?? 0.0).toDouble(),
      subScores: json['subScores'] as Map<String, dynamic>?,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// VIDEO ANALYSIS
// ══════════════════════════════════════════════════════════════════════════════

class VideoAnalysisResult {
  final double deepfakeProbability;
  final double confidence;
  final int analyzedFrames;
  final List<Map<String, dynamic>> frameResults;
  final List<String> detectedPatterns;
  final String explanation;
  final bool isDeepfake;
  final String analysisMethod;
  final Map<String, dynamic>? subScores;

  VideoAnalysisResult({
    required this.deepfakeProbability,
    required this.confidence,
    required this.analyzedFrames,
    required this.frameResults,
    required this.detectedPatterns,
    required this.explanation,
    required this.isDeepfake,
    required this.analysisMethod,
    this.subScores,
  });

  factory VideoAnalysisResult.fromJson(Map<String, dynamic> json) {
    return VideoAnalysisResult(
      deepfakeProbability: (json['deepfakeProbability'] ?? 0.0).toDouble(),
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      analyzedFrames: (json['analyzedFrames'] ?? 0) as int,
      frameResults:
          (json['frameResults'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [],
      detectedPatterns: List<String>.from(json['detectedPatterns'] ?? []),
      explanation: json['explanation'] ?? '',
      isDeepfake: json['isDeepfake'] ?? false,
      analysisMethod: json['analysisMethod'] ?? 'unknown',
      subScores: json['subScores'] as Map<String, dynamic>?,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// RISK SCORING
// ══════════════════════════════════════════════════════════════════════════════

class RiskFactor {
  final String name;
  final int contribution;
  final String category;

  RiskFactor({
    required this.name,
    required this.contribution,
    required this.category,
  });

  factory RiskFactor.fromJson(Map<String, dynamic> json) {
    return RiskFactor(
      name: json['name'] ?? '',
      contribution: json['contribution'] ?? 0,
      category: json['category'] ?? '',
    );
  }
}

class RiskScoringResult {
  final int finalScore;
  final String riskLevel;
  final double confidence;
  final Map<String, int> componentScores;
  final List<RiskFactor> riskFactors;
  final String explanation;

  RiskScoringResult({
    required this.finalScore,
    required this.riskLevel,
    required this.confidence,
    required this.componentScores,
    required this.riskFactors,
    required this.explanation,
  });

  factory RiskScoringResult.fromJson(Map<String, dynamic> json) {
    return RiskScoringResult(
      finalScore: json['finalScore'] ?? 0,
      riskLevel: json['riskLevel'] ?? 'LOW',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      componentScores: Map<String, int>.from(
        (json['componentScores'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), (v as num).toInt()),
            ) ??
            {},
      ),
      riskFactors:
          (json['riskFactors'] as List?)
              ?.map((e) => RiskFactor.fromJson(e))
              .toList() ??
          [],
      explanation: json['explanation'] ?? '',
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SCAN HISTORY ENTRY (Local storage model)
// ══════════════════════════════════════════════════════════════════════════════

enum ScanType { text, voice, image, video }

class ScanHistoryEntry {
  final String id;
  final ScanType type;
  final DateTime timestamp;
  final String riskLevel; // LOW, MEDIUM, HIGH
  final int riskScore;
  final String summary;
  final String explanation;

  ScanHistoryEntry({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.riskLevel,
    required this.riskScore,
    required this.summary,
    required this.explanation,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'riskLevel': riskLevel,
      'riskScore': riskScore,
      'summary': summary,
      'explanation': explanation,
    };
  }

  factory ScanHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ScanHistoryEntry(
      id: json['id'] ?? '',
      type: ScanType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ScanType.text,
      ),
      timestamp: DateTime.parse(json['timestamp']),
      riskLevel: json['riskLevel'] ?? 'LOW',
      riskScore: json['riskScore'] ?? 0,
      summary: json['summary'] ?? '',
      explanation: json['explanation'] ?? '',
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// BLOCKCHAIN EVIDENCE
// ══════════════════════════════════════════════════════════════════════════════

class BlockchainReportResult {
  final int evidenceId;
  final String ipfsCid;
  final String ipfsUrl;
  final String fileHash;
  final String txHash;
  final int? batchId;
  final bool anchored;
  final String timestamp;
  final String profileUrl;
  final String threatType;
  final String aiResult;
  final double confidence;
  final String? merkleRoot;
  final String? explorerUrl;

  BlockchainReportResult({
    required this.evidenceId,
    required this.ipfsCid,
    required this.ipfsUrl,
    required this.fileHash,
    required this.txHash,
    this.batchId,
    required this.anchored,
    required this.timestamp,
    required this.profileUrl,
    required this.threatType,
    required this.aiResult,
    required this.confidence,
    this.merkleRoot,
    this.explorerUrl,
  });

  factory BlockchainReportResult.fromJson(Map<String, dynamic> json) {
    final evidence = json['evidence'] as Map<String, dynamic>? ?? json;
    return BlockchainReportResult(
      evidenceId: evidence['id'] ?? 0,
      ipfsCid: evidence['ipfs_cid'] ?? '',
      ipfsUrl: json['ipfs_url'] ?? '',
      fileHash: evidence['file_hash'] ?? '',
      txHash: evidence['tx_hash'] ?? '',
      batchId: evidence['batch_id'] as int?,
      anchored: evidence['anchored'] == true || evidence['anchored'] == 1,
      timestamp: evidence['timestamp'] ?? '',
      profileUrl: evidence['profile_url'] ?? '',
      threatType: evidence['threat_type'] ?? '',
      aiResult: evidence['ai_result'] ?? '',
      confidence: (evidence['confidence'] ?? 0.0).toDouble(),
      merkleRoot: evidence['merkle_root'] as String?,
      explorerUrl: json['explorer_url'] as String?,
    );
  }
}

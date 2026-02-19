/// Risk Scoring Engine - Combines multiple risk factors into a final trust score
library;

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/risk_levels.dart';
import '../../call_detection/services/call_risk_service.dart';
import '../../voice_analysis/services/voice_analyzer_service.dart';
import '../../message_analysis/services/message_analyzer_service.dart';

/// Comprehensive risk assessment result
class RiskAssessment {
  final int finalScore;
  final RiskLevel riskLevel;
  final double confidence;
  final Map<String, int> componentScores;
  final List<RiskFactor> riskFactors;
  final String explanation;
  final DateTime assessedAt;

  RiskAssessment({
    required this.finalScore,
    required this.riskLevel,
    required this.confidence,
    required this.componentScores,
    required this.riskFactors,
    required this.explanation,
    required this.assessedAt,
  });

  bool get isHighRisk => finalScore > 70;
  bool get isMediumRisk => finalScore > 30 && finalScore <= 70;
  bool get isLowRisk => finalScore <= 30;
}

/// Individual risk factor contributing to the score
class RiskFactor {
  final String name;
  final String description;
  final int contribution;
  final RiskCategory category;
  final double weight;

  RiskFactor({
    required this.name,
    required this.description,
    required this.contribution,
    required this.category,
    required this.weight,
  });
}

/// Main Risk Scoring Engine
class RiskScoringEngine {
  // Singleton
  static final RiskScoringEngine _instance = RiskScoringEngine._internal();
  factory RiskScoringEngine() => _instance;
  RiskScoringEngine._internal();

  // Historical data for pattern recognition
  final List<RiskAssessment> _assessmentHistory = [];

  /// Calculate comprehensive risk score from all available data
  RiskAssessment calculateRiskScore({
    CallRiskResult? callRisk,
    VoiceAnalysisResult? voiceAnalysis,
    MessageAnalysisResult? messageAnalysis,
    Map<String, dynamic>? historicalData,
  }) {
    final componentScores = <String, int>{};
    final riskFactors = <RiskFactor>[];
    double totalWeightedScore = 0;
    double totalWeight = 0;

    // 1. Call Metadata Score
    if (callRisk != null) {
      componentScores['call'] = callRisk.riskScore;
      totalWeightedScore +=
          callRisk.riskScore * AppConstants.callMetadataWeight;
      totalWeight += AppConstants.callMetadataWeight;

      for (final factor in callRisk.riskFactors) {
        riskFactors.add(
          RiskFactor(
            name: factor,
            description: 'Detected from call metadata',
            contribution: (callRisk.riskScore * 0.2).round(),
            category: callRisk.category,
            weight: AppConstants.callMetadataWeight,
          ),
        );
      }
    }

    // 2. Voice Analysis Score
    if (voiceAnalysis != null) {
      final voiceScore = (voiceAnalysis.syntheticProbability * 100).round();
      componentScores['voice'] = voiceScore;
      totalWeightedScore += voiceScore * AppConstants.voiceAnalysisWeight;
      totalWeight += AppConstants.voiceAnalysisWeight;

      if (voiceAnalysis.isLikelyAI) {
        riskFactors.add(
          RiskFactor(
            name: 'AI-Generated Voice',
            description: voiceAnalysis.explanation,
            contribution: voiceScore,
            category: RiskCategory.syntheticVoice,
            weight: AppConstants.voiceAnalysisWeight,
          ),
        );
      }

      for (final pattern in voiceAnalysis.detectedPatterns) {
        riskFactors.add(
          RiskFactor(
            name: pattern,
            description: 'Voice pattern anomaly',
            contribution: 10,
            category: RiskCategory.syntheticVoice,
            weight: 0.1,
          ),
        );
      }
    }

    // 3. Content/Message Analysis Score
    if (messageAnalysis != null) {
      componentScores['content'] = messageAnalysis.riskScore;
      totalWeightedScore +=
          messageAnalysis.riskScore * AppConstants.contentAnalysisWeight;
      totalWeight += AppConstants.contentAnalysisWeight;

      for (final threat in messageAnalysis.detectedThreats) {
        riskFactors.add(
          RiskFactor(
            name: threat.label,
            description: 'Detected threat pattern',
            contribution: 15,
            category: _mapThreatToCategory(threat),
            weight: AppConstants.contentAnalysisWeight,
          ),
        );
      }
    }

    // 4. Historical Behavior Score
    final historyScore = _calculateHistoryScore(historicalData);
    if (historyScore > 0) {
      componentScores['history'] = historyScore;
      totalWeightedScore += historyScore * AppConstants.historyWeight;
      totalWeight += AppConstants.historyWeight;
    }

    // Calculate final weighted score
    final finalScore = totalWeight > 0
        ? (totalWeightedScore / totalWeight).round().clamp(0, 100)
        : 0;

    // Calculate confidence based on available data
    double confidence = 0;
    if (componentScores.isNotEmpty) {
      confidence = (componentScores.length / 4) * 0.7 + 0.3;
    }

    // Determine risk level
    final riskLevel = RiskLevels.fromScore(finalScore);

    // Generate explanation
    final explanation = _generateExplanation(
      finalScore: finalScore,
      riskLevel: riskLevel,
      componentScores: componentScores,
      riskFactors: riskFactors,
    );

    final assessment = RiskAssessment(
      finalScore: finalScore,
      riskLevel: riskLevel,
      confidence: confidence,
      componentScores: componentScores,
      riskFactors: riskFactors,
      explanation: explanation,
      assessedAt: DateTime.now(),
    );

    // Store in history
    _addToHistory(assessment);

    return assessment;
  }

  /// Calculate history-based risk score
  int _calculateHistoryScore(Map<String, dynamic>? historicalData) {
    if (historicalData == null || historicalData.isEmpty) return 0;

    int score = 0;

    // Previous interactions with this number
    final previousRisks = historicalData['previousRiskScores'] as List<int>?;
    if (previousRisks != null && previousRisks.isNotEmpty) {
      final avgPrevious =
          previousRisks.reduce((a, b) => a + b) / previousRisks.length;
      score += avgPrevious.round();
    }

    // Known spam database hits
    if (historicalData['knownSpam'] == true) {
      score += 50;
    }

    // User reports
    final reportCount = historicalData['userReports'] as int? ?? 0;
    score += (reportCount * 10).clamp(0, 30);

    return score.clamp(0, 100);
  }

  /// Map threat type to risk category
  RiskCategory _mapThreatToCategory(ThreatType threat) {
    switch (threat) {
      case ThreatType.phishing:
        return RiskCategory.phishing;
      case ThreatType.urgency:
        return RiskCategory.urgencyManipulation;
      case ThreatType.fakeOffer:
        return RiskCategory.fakeOffer;
      case ThreatType.suspiciousLink:
        return RiskCategory.suspiciousLink;
      case ThreatType.financialScam:
        return RiskCategory.scamCall;
      default:
        return RiskCategory.unknown;
    }
  }

  /// Generate human-readable explanation
  String _generateExplanation({
    required int finalScore,
    required RiskLevel riskLevel,
    required Map<String, int> componentScores,
    required List<RiskFactor> riskFactors,
  }) {
    final buffer = StringBuffer();

    switch (riskLevel) {
      case RiskLevel.low:
        buffer.write('This interaction appears safe. ');
        if (componentScores.isEmpty) {
          buffer.write('No risk indicators were detected.');
        } else {
          buffer.write('Minor indicators found but within normal range.');
        }
        break;

      case RiskLevel.medium:
        buffer.write('Exercise caution with this interaction. ');
        final highestComponent = componentScores.entries.reduce(
          (a, b) => a.value > b.value ? a : b,
        );
        buffer.write(
          'Primary concern: ${_componentToReadable(highestComponent.key)} '
          '(score: ${highestComponent.value}). ',
        );
        break;

      case RiskLevel.high:
        buffer.write('Warning: High risk detected! ');
        if (riskFactors.isNotEmpty) {
          final topFactors = riskFactors.take(2).map((f) => f.name).join(', ');
          buffer.write('Key threats: $topFactors. ');
        }
        buffer.write('Do not share personal information.');
        break;

      case RiskLevel.unknown:
        buffer.write('Unable to fully assess risk. Limited data available.');
    }

    return buffer.toString();
  }

  String _componentToReadable(String component) {
    switch (component) {
      case 'call':
        return 'Call analysis';
      case 'voice':
        return 'Voice authenticity';
      case 'content':
        return 'Message content';
      case 'history':
        return 'Historical patterns';
      default:
        return component;
    }
  }

  /// Add assessment to history
  void _addToHistory(RiskAssessment assessment) {
    _assessmentHistory.insert(0, assessment);
    if (_assessmentHistory.length > 100) {
      _assessmentHistory.removeRange(100, _assessmentHistory.length);
    }
  }

  /// Get recent assessments
  List<RiskAssessment> get recentAssessments =>
      List.unmodifiable(_assessmentHistory);

  /// Clear history
  void clearHistory() {
    _assessmentHistory.clear();
  }

  /// Get average risk score from history
  double get averageRiskScore {
    if (_assessmentHistory.isEmpty) return 0;
    final sum = _assessmentHistory.fold<int>(0, (acc, a) => acc + a.finalScore);
    return sum / _assessmentHistory.length;
  }

  /// Get high risk count from history
  int get highRiskCount => _assessmentHistory.where((a) => a.isHighRisk).length;
}

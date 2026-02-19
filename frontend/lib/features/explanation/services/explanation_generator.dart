/// Explanation Generator - Converts technical analysis to user-friendly text
library;

import '../../../core/constants/risk_levels.dart';
import '../../risk_scoring/services/risk_scoring_engine.dart';

/// Template-based explanations for different risk scenarios
class ExplanationGenerator {
  // Singleton
  static final ExplanationGenerator _instance =
      ExplanationGenerator._internal();
  factory ExplanationGenerator() => _instance;
  ExplanationGenerator._internal();

  /// Generate explanation for a risk assessment
  String generateExplanation(RiskAssessment assessment) {
    final buffer = StringBuffer();

    // Opening based on risk level
    buffer.write(
      _getOpeningStatement(assessment.riskLevel, assessment.finalScore),
    );
    buffer.write(' ');

    // Add component-specific explanations
    if (assessment.componentScores.containsKey('call')) {
      buffer.write(_explainCallRisk(assessment.componentScores['call']!));
    }

    if (assessment.componentScores.containsKey('voice')) {
      buffer.write(_explainVoiceRisk(assessment.componentScores['voice']!));
    }

    if (assessment.componentScores.containsKey('content')) {
      buffer.write(_explainContentRisk(assessment.componentScores['content']!));
    }

    // Add recommendations
    buffer.write(_getRecommendation(assessment.riskLevel));

    return buffer.toString();
  }

  /// Generate simple one-line explanation
  String generateSimpleExplanation(int riskScore, RiskCategory category) {
    switch (category) {
      case RiskCategory.scamCall:
        return _scamCallExplanations[_getScoreIndex(riskScore)];
      case RiskCategory.syntheticVoice:
        return _syntheticVoiceExplanations[_getScoreIndex(riskScore)];
      case RiskCategory.phishing:
        return _phishingExplanations[_getScoreIndex(riskScore)];
      case RiskCategory.urgencyManipulation:
        return _urgencyExplanations[_getScoreIndex(riskScore)];
      case RiskCategory.fakeOffer:
        return _fakeOfferExplanations[_getScoreIndex(riskScore)];
      case RiskCategory.suspiciousLink:
        return _suspiciousLinkExplanations[_getScoreIndex(riskScore)];
      case RiskCategory.deepfakeVideo:
        return _deepfakeExplanations[_getScoreIndex(riskScore)];
      case RiskCategory.unknown:
        return _unknownExplanations[_getScoreIndex(riskScore)];
    }
  }

  int _getScoreIndex(int score) {
    if (score <= 30) return 0;
    if (score <= 60) return 1;
    return 2;
  }

  String _getOpeningStatement(RiskLevel level, int score) {
    switch (level) {
      case RiskLevel.low:
        return 'Good news! This interaction appears safe with a risk score of $score/100.';
      case RiskLevel.medium:
        return 'Caution advised. This interaction has a moderate risk score of $score/100.';
      case RiskLevel.high:
        return '⚠️ Warning! This interaction has a high risk score of $score/100.';
      case RiskLevel.unknown:
        return 'Risk assessment incomplete.';
    }
  }

  String _explainCallRisk(int score) {
    if (score <= 20) {
      return 'The call appears to be from a legitimate source. ';
    } else if (score <= 50) {
      return 'The call shows some unusual patterns but is not definitively suspicious. ';
    } else {
      return 'The call matches patterns commonly seen in scam operations. ';
    }
  }

  String _explainVoiceRisk(int score) {
    if (score <= 20) {
      return 'Voice analysis indicates natural human speech patterns. ';
    } else if (score <= 50) {
      return 'Voice shows some irregularities but is likely human. ';
    } else {
      return 'Voice analysis suggests possible AI-generation or manipulation. ';
    }
  }

  String _explainContentRisk(int score) {
    if (score <= 20) {
      return 'Message content appears normal with no suspicious elements. ';
    } else if (score <= 50) {
      return 'Message contains some potentially suspicious language patterns. ';
    } else {
      return 'Message shows strong indicators of phishing or scam content. ';
    }
  }

  String _getRecommendation(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return 'Continue with normal precaution.';
      case RiskLevel.medium:
        return 'Verify the identity of the caller or sender before sharing any personal information.';
      case RiskLevel.high:
        return 'DO NOT share any personal, financial, or login information. Consider blocking this contact.';
      case RiskLevel.unknown:
        return 'Proceed with caution until more information is available.';
    }
  }

  // Template arrays for different categories
  static const _scamCallExplanations = [
    'This call shows normal patterns consistent with legitimate calls.',
    'This call has some characteristics similar to known scam operations. Be cautious.',
    'This call shows patterns strongly associated with bank fraud and scam calls.',
  ];

  static const _syntheticVoiceExplanations = [
    'The voice appears natural with typical human speech characteristics.',
    'The voice shows some unusual patterns that may indicate manipulation.',
    'The voice shows characteristics of AI-generated or synthetic speech.',
  ];

  static const _phishingExplanations = [
    'This message appears legitimate with no phishing indicators.',
    'This message contains some phrases commonly used in phishing attempts.',
    'This message strongly matches known phishing templates. Do not click any links.',
  ];

  static const _urgencyExplanations = [
    'The message tone is appropriate and not manipulative.',
    'The message uses some urgency tactics to pressure quick action.',
    'The message uses aggressive urgency manipulation to bypass careful thinking.',
  ];

  static const _fakeOfferExplanations = [
    'Any offers mentioned appear reasonable and legitimate.',
    'Some claims seem too good to be true. Verify before proceeding.',
    'This contains clear signs of fake offers designed to deceive.',
  ];

  static const _suspiciousLinkExplanations = [
    'Links in this message appear safe and from legitimate domains.',
    'Some links use URL shorteners or unusual domains. Use caution.',
    'Links in this message lead to suspicious or potentially harmful websites.',
  ];

  static const _deepfakeExplanations = [
    'Video analysis shows no signs of manipulation.',
    'Video shows some irregularities that may indicate editing.',
    'Video shows strong signs of deepfake manipulation.',
  ];

  static const _unknownExplanations = [
    'No specific risk indicators detected.',
    'Some unusual patterns detected but insufficient for classification.',
    'Multiple risk indicators detected but category unclear.',
  ];

  /// Generate contextual tips based on risk factors
  List<String> generateTips(RiskAssessment assessment) {
    final tips = <String>[];

    if (assessment.isHighRisk) {
      tips.add('Block this number/sender if you believe it\'s a scam');
      tips.add(
        'Report this to relevant authorities if any money was requested',
      );
    }

    if (assessment.componentScores.containsKey('voice') &&
        assessment.componentScores['voice']! > 40) {
      tips.add(
        'Ask the caller to verify their identity through official channels',
      );
      tips.add(
        'Banks and officials will never ask for passwords over the phone',
      );
    }

    if (assessment.componentScores.containsKey('content') &&
        assessment.componentScores['content']! > 40) {
      tips.add('Never click links in suspicious messages');
      tips.add(
        'Manually type the official website URL instead of clicking links',
      );
    }

    if (tips.isEmpty) {
      tips.add('Stay vigilant and verify unexpected requests');
    }

    return tips;
  }
}

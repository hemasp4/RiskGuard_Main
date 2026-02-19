/// Risk level definitions and thresholds
enum RiskLevel { low, medium, high, unknown }

class RiskLevels {
  // Score thresholds
  static const int lowMax = 30;
  static const int mediumMax = 70;

  // Get risk level from score (0-100)
  static RiskLevel fromScore(int score) {
    if (score < 0) return RiskLevel.unknown;
    if (score <= lowMax) return RiskLevel.low;
    if (score <= mediumMax) return RiskLevel.medium;
    return RiskLevel.high;
  }

  // Get display label
  static String getLabel(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return 'LOW RISK';
      case RiskLevel.medium:
        return 'MEDIUM RISK';
      case RiskLevel.high:
        return 'HIGH RISK';
      case RiskLevel.unknown:
        return 'UNKNOWN';
    }
  }

  // Get description
  static String getDescription(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return 'This interaction appears safe';
      case RiskLevel.medium:
        return 'Exercise caution with this interaction';
      case RiskLevel.high:
        return 'This interaction shows high-risk patterns';
      case RiskLevel.unknown:
        return 'Unable to determine risk level';
    }
  }

  // Get icon name
  static String getIconName(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return 'shield_check';
      case RiskLevel.medium:
        return 'warning';
      case RiskLevel.high:
        return 'dangerous';
      case RiskLevel.unknown:
        return 'help_outline';
    }
  }
}

/// Risk categories for different types of threats
enum RiskCategory {
  scamCall,
  syntheticVoice,
  phishing,
  urgencyManipulation,
  fakeOffer,
  suspiciousLink,
  deepfakeVideo,
  unknown,
}

extension RiskCategoryExtension on RiskCategory {
  String get label {
    switch (this) {
      case RiskCategory.scamCall:
        return 'Scam Call';
      case RiskCategory.syntheticVoice:
        return 'AI Voice Detected';
      case RiskCategory.phishing:
        return 'Phishing Attempt';
      case RiskCategory.urgencyManipulation:
        return 'Urgency Manipulation';
      case RiskCategory.fakeOffer:
        return 'Fake Offer';
      case RiskCategory.suspiciousLink:
        return 'Suspicious Link';
      case RiskCategory.deepfakeVideo:
        return 'Deepfake Video';
      case RiskCategory.unknown:
        return 'Unknown Threat';
    }
  }

  String get description {
    switch (this) {
      case RiskCategory.scamCall:
        return 'This call matches patterns of known scam operations';
      case RiskCategory.syntheticVoice:
        return 'The voice shows characteristics of AI-generated speech';
      case RiskCategory.phishing:
        return 'This message attempts to steal your personal information';
      case RiskCategory.urgencyManipulation:
        return 'Uses high-pressure tactics to rush your decision';
      case RiskCategory.fakeOffer:
        return 'Contains unrealistic offers or promises';
      case RiskCategory.suspiciousLink:
        return 'Contains links to potentially malicious websites';
      case RiskCategory.deepfakeVideo:
        return 'Video shows signs of AI manipulation';
      case RiskCategory.unknown:
        return 'Unidentified risk pattern detected';
    }
  }
}

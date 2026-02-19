import 'package:flutter/material.dart';
import '../services/voice_analyzer_service.dart';
import '../../../core/theme/app_colors.dart';

/// Widget to display voice detection results with human vs AI indicator
class VoiceDetectionWidget extends StatelessWidget {
  final VoiceAnalysisResult? result;
  final bool isAnalyzing;

  const VoiceDetectionWidget({
    super.key,
    this.result,
    this.isAnalyzing = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isAnalyzing) {
      return _buildAnalyzingState();
    }

    if (result == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getClassificationColor(
            result!.classification,
          ).withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Classification Badge
          Row(
            children: [
              Text(
                result!.classification.icon,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result!.classification.label,
                      style: TextStyle(
                        color: _getClassificationColor(result!.classification),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Confidence: ${(result!.confidence * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: AppColors.textSecondaryDark,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _buildConfidenceMeter(result!.confidence),
            ],
          ),
          const SizedBox(height: 12),

          // Synthetic Probability Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'AI Probability',
                    style: TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${(result!.syntheticProbability * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: _getClassificationColor(result!.classification),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: result!.syntheticProbability,
                  minHeight: 8,
                  backgroundColor: AppColors.textSecondaryDark.withValues(
                    alpha: 0.2,
                  ),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getClassificationColor(result!.classification),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Explanation
          Text(
            result!.explanation,
            style: const TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 13,
            ),
          ),

          // Detected Patterns
          if (result!.detectedPatterns.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: result!.detectedPatterns.map((pattern) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    pattern,
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontSize: 10,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnalyzingState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            'Analyzing voice...',
            style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceMeter(double confidence) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          '${(confidence * 100).toInt()}%',
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Color _getClassificationColor(VoiceClassification classification) {
    switch (classification) {
      case VoiceClassification.human:
        return AppColors.success;
      case VoiceClassification.aiGenerated:
        return AppColors.error;
      case VoiceClassification.uncertain:
        return AppColors.warning;
    }
  }
}

/// Compact voice indicator for overlays
class CompactVoiceIndicator extends StatelessWidget {
  final VoiceClassification classification;
  final double confidence;

  const CompactVoiceIndicator({
    super.key,
    required this.classification,
    required this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getColor(classification).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getColor(classification), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(classification.icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            classification.label,
            style: TextStyle(
              color: _getColor(classification),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${(confidence * 100).toInt()}%',
            style: TextStyle(color: _getColor(classification), fontSize: 10),
          ),
        ],
      ),
    );
  }

  Color _getColor(VoiceClassification classification) {
    switch (classification) {
      case VoiceClassification.human:
        return AppColors.success;
      case VoiceClassification.aiGenerated:
        return AppColors.error;
      case VoiceClassification.uncertain:
        return AppColors.warning;
    }
  }
}

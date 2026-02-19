/// Message Analysis Screen - UI for analyzing text messages
/// Detects phishing/scams AND AI-generated text
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/constants/app_constants.dart';
import '../providers/message_analysis_provider.dart';
import '../services/message_analyzer_service.dart';

class MessageAnalysisScreen extends StatelessWidget {
  const MessageAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MessageAnalysisProvider(),
      child: const _MessageAnalysisContent(),
    );
  }
}

class _MessageAnalysisContent extends StatefulWidget {
  const _MessageAnalysisContent();

  @override
  State<_MessageAnalysisContent> createState() =>
      _MessageAnalysisContentState();
}

class _MessageAnalysisContentState extends State<_MessageAnalysisContent> {
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Message Analysis'),
        actions: [
          IconButton(
            icon: const Icon(Icons.content_paste),
            onPressed: _pasteFromClipboard,
            tooltip: 'Paste',
          ),
        ],
      ),
      body: Consumer<MessageAnalysisProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Card
                _buildInfoCard().animate().fadeIn(duration: 400.ms),

                const SizedBox(height: 24),

                // Text Input
                _buildTextInput(
                  provider,
                ).animate().fadeIn(duration: 400.ms, delay: 100.ms),

                const SizedBox(height: 16),

                // Analyze Button
                _buildAnalyzeButton(
                  provider,
                ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

                const SizedBox(height: 24),

                // Result
                if (provider.isAnalyzing) _buildLoadingIndicator(),

                if (provider.lastResult != null && !provider.isAnalyzing)
                  _ResultCard(result: provider.lastResult!)
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.1, end: 0),

                if (provider.errorMessage != null)
                  _buildErrorCard(provider.errorMessage!),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.security, color: AppColors.warning),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Phishing & AI Text Detection',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.textPrimaryDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Detects phishing, scams, and AI-generated text (ChatGPT, etc.)',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextInput(MessageAnalysisProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: _textController,
        maxLines: 6,
        minLines: 4,
        onChanged: provider.setMessage,
        style: AppTypography.bodyMedium.copyWith(
          color: AppColors.textPrimaryDark,
        ),
        decoration: InputDecoration(
          hintText: 'Paste suspicious message here...',
          hintStyle: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondaryDark,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: AppColors.cardDark,
          suffixIcon: _textController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  color: AppColors.textSecondaryDark,
                  onPressed: () {
                    _textController.clear();
                    provider.clearResult();
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildAnalyzeButton(MessageAnalysisProvider provider) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: provider.isAnalyzing
            ? null
            : () => provider.analyzeMessage(_textController.text),
        icon: Icon(provider.isAnalyzing ? Icons.hourglass_empty : Icons.search),
        label: Text(provider.isAnalyzing ? 'Analyzing...' : 'Analyze Message'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'Analyzing with AI detection...',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null && mounted) {
      _textController.text = data!.text!;
      context.read<MessageAnalysisProvider>().setMessage(data.text!);
    }
  }
}

/// Result card widget with AI detection display
class _ResultCard extends StatelessWidget {
  final MessageAnalysisResult result;

  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    // Determine colors based on both phishing risk and AI detection
    final isHighRisk = result.riskScore > 60 || result.isAiGenerated;
    final isMediumRisk = result.riskScore > 30 || result.aiGeneratedProbability > AppConstants.lowRiskThreshold;
    
    final Color primaryColor;
    if (result.isSafe && !result.isAiGenerated) {
      primaryColor = AppColors.success;
    } else if (isHighRisk) {
      primaryColor = AppColors.error;
    } else if (isMediumRisk) {
      primaryColor = AppColors.warning;
    } else {
      primaryColor = AppColors.success;
    }

    return Container(
      decoration: BoxDecoration(
        // Red background tint when AI is detected
        color: result.isAiGenerated 
            ? AppColors.error.withValues(alpha: 0.08)
            : AppColors.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.5), 
          width: result.isAiGenerated ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI Detection Banner (shown when AI is detected)
          if (result.isAiGenerated)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.smart_toy, color: AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '🤖 AI-GENERATED TEXT DETECTED',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // AI Detection Score (prominent display)
                if (result.aiGeneratedProbability > 0) ...[
                  _AIDetectionIndicator(
                    probability: result.aiGeneratedProbability,
                    confidence: result.aiConfidence,
                    explanation: result.aiExplanation,
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 16),
                ],

                // Phishing/Scam Header
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          result.riskScore.toString(),
                          style: AppTypography.headlineMedium.copyWith(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result.isSafe
                                ? 'Phishing Check: Safe'
                                : (result.riskScore > 60
                                      ? 'High Phishing Risk!'
                                      : 'Suspicious Patterns'),
                            style: AppTypography.titleMedium.copyWith(
                              color: result.isSafe ? AppColors.success : primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Phishing Risk: ${result.riskScore}/100',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      result.isSafe
                          ? Icons.verified_user
                          : Icons.warning_amber_rounded,
                      color: result.isSafe ? AppColors.success : primaryColor,
                      size: 28,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Risk meter
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: result.riskScore / 100,
                    backgroundColor: AppColors.surfaceDark,
                    valueColor: AlwaysStoppedAnimation(
                      result.riskScore > 60 ? AppColors.error : 
                      result.riskScore > 30 ? AppColors.warning : AppColors.success
                    ),
                    minHeight: 8,
                  ),
                ),

                const SizedBox(height: 20),

                // Explanation
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    result.explanation,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                ),

                // Detected threats (including AI-generated)
                if (result.detectedThreats.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Detected Threats',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: result.detectedThreats.map((threat) {
                      final isAiThreat = threat == ThreatType.aiGenerated;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isAiThreat 
                              ? AppColors.error.withValues(alpha: 0.2)
                              : AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: isAiThreat ? 0.6 : 0.3),
                            width: isAiThreat ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(threat.icon),
                            const SizedBox(width: 6),
                            Text(
                              threat.label,
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.error,
                                fontWeight: isAiThreat ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],

                // Suspicious patterns
                if (result.suspiciousPatterns.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Suspicious Patterns Found',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...result.suspiciousPatterns.take(5).map((pattern) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.arrow_right, color: AppColors.warning, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              pattern,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondaryDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (result.suspiciousPatterns.length > 5)
                    Text(
                      '+ ${result.suspiciousPatterns.length - 5} more patterns',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                ],

                // Extracted URLs
                if (result.extractedUrls.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'URLs in Message',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...result.extractedUrls.map((url) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.link, color: AppColors.warning, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              url,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.info,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget to display AI detection probability prominently
class _AIDetectionIndicator extends StatelessWidget {
  final double probability;
  final double confidence;
  final String explanation;

  const _AIDetectionIndicator({
    required this.probability,
    required this.confidence,
    required this.explanation,
  });

  @override
  Widget build(BuildContext context) {
    final isAiDetected = probability >= AppConstants.aiDetectionThreshold;
    final percentage = (probability * 100).toInt();
    final color = isAiDetected ? AppColors.error : AppColors.success;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isAiDetected ? Icons.smart_toy : Icons.person,
                color: color,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAiDetected ? 'AI-Generated Text' : 'Human-Written Text',
                      style: AppTypography.titleMedium.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'AI Probability: $percentage%',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                  ],
                ),
              ),
              // Circular percentage indicator
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.15),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: probability,
                      strokeWidth: 4,
                      valueColor: AlwaysStoppedAnimation(color),
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                    ),
                    Text(
                      '$percentage%',
                      style: AppTypography.labelSmall.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              explanation,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondaryDark,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

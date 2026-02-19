import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../providers/video_analysis_provider.dart';
import '../services/video_analyzer_service.dart';

class VideoAnalysisScreen extends StatelessWidget {
  const VideoAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Video Analysis'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => _showHistory(context),
          ),
        ],
      ),
      body: Consumer<VideoAnalysisProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Upload Section
                _buildUploadSection(context, provider),
                const SizedBox(height: 24),

                // Analysis Progress
                if (provider.isAnalyzing) ...[
                  _buildAnalysisProgress(provider),
                  const SizedBox(height: 24),
                ],

                // Error Display
                if (provider.error != null) ...[
                  _buildErrorDisplay(provider.error!),
                  const SizedBox(height: 24),
                ],

                // Results Display
                if (provider.currentResult != null) ...[
                  _buildResultsDisplay(provider.currentResult!),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUploadSection(
    BuildContext context,
    VideoAnalysisProvider provider,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.video_library, size: 60, color: AppColors.primary),
          const SizedBox(height: 16),
          const Text(
            'Analyze Video for Deepfakes',
            style: TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Upload a video to check for AI-generated content\nand manipulation patterns using Hugging Face AI',
            style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: provider.isAnalyzing
                ? null
                : () => _pickAndAnalyzeVideo(context, provider),
            icon: const Icon(Icons.upload_file),
            label: const Text('Select Video File'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisProgress(VideoAnalysisProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Analyzing with AI...',
            style: TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Extracting frames and detecting deepfake patterns',
            style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 12),
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: provider.progress,
            backgroundColor: AppColors.textSecondaryDark.withValues(alpha: 0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorDisplay(String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(color: AppColors.error, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsDisplay(VideoAnalysisResult result) {
    final isDeepfake =
        result.deepfakeProbability >= AppConstants.aiDetectionThreshold;
    final threatColor = result.isAuthentic
        ? AppColors.success
        : AppColors.error;
    final percentage = (result.deepfakeProbability * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Deepfake Detection Banner (prominent when detected)
        if (isDeepfake)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.error, width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.error,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🎭 DEEPFAKE DETECTED',
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        'AI probability: $percentage%',
                        style: TextStyle(
                          color: AppColors.error.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Main Result Card
        Container(
          decoration: BoxDecoration(
            // Red background tint when deepfake detected
            color: isDeepfake
                ? AppColors.error.withValues(alpha: 0.08)
                : AppColors.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: threatColor.withValues(alpha: 0.5),
              width: isDeepfake ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Deepfake Probability Circle
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: result.isAuthentic
                        ? [
                            AppColors.success,
                            AppColors.success.withValues(alpha: 0.7),
                          ]
                        : [AppColors.error, AppColors.warning],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${(result.deepfakeProbability * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Deepfake',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Status
              Text(
                result.isAuthentic ? 'Authentic Video' : 'Potential Deepfake',
                style: TextStyle(
                  color: threatColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Confidence
              Text(
                'Confidence: ${(result.confidence * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),

              // Explanation
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.backgroundDark,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  result.explanation,
                  style: const TextStyle(
                    color: AppColors.textPrimaryDark,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Detected Threats
        if (result.detectedThreats.isNotEmpty &&
            !result.detectedThreats.contains(VideoThreatType.safe)) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Detected Threats',
                  style: TextStyle(
                    color: AppColors.textPrimaryDark,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...result.detectedThreats
                    .where((t) => t != VideoThreatType.safe)
                    .map((threat) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Text(
                              threat.icon,
                              style: const TextStyle(fontSize: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                threat.label,
                                style: const TextStyle(
                                  color: AppColors.textPrimaryDark,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Manipulation Patterns
        if (result.manipulationPatterns.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Manipulation Patterns',
                  style: TextStyle(
                    color: AppColors.textPrimaryDark,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: result.manipulationPatterns.map((pattern) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        pattern,
                        style: const TextStyle(
                          color: AppColors.warning,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Analysis Stats
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(
                icon: Icons.photo_library,
                label: 'Frames',
                value: result.analyzedFrames.toString(),
              ),
              _StatItem(
                icon: Icons.access_time,
                label: 'Analyzed',
                value: _formatTime(result.analyzedAt),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickAndAnalyzeVideo(
    BuildContext context,
    VideoAnalysisProvider provider,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
        withData: true, // Required for web - loads bytes into memory
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        final bytes = file.bytes;
        final fileName = file.name;

        if (bytes != null && bytes.isNotEmpty) {
          // Use bytes-based analysis (works on both web and mobile)
          await provider.analyzeVideoFromBytes(bytes, fileName);
        } else if (file.path != null) {
          // Fallback to path-based analysis (mobile only)
          await provider.analyzeVideo(file.path!);
        } else {
          // No data available
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not read video file. Please try again.'),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error selecting video: $e')));
      }
    }
  }

  void _showHistory(BuildContext context) {
    final provider = context.read<VideoAnalysisProvider>();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDark,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Analysis History',
              style: TextStyle(
                color: AppColors.textPrimaryDark,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: provider.analysisHistory.isEmpty
                  ? const Center(
                      child: Text(
                        'No analysis history',
                        style: TextStyle(color: AppColors.textSecondaryDark),
                      ),
                    )
                  : ListView.builder(
                      itemCount: provider.analysisHistory.length,
                      itemBuilder: (context, index) {
                        final item = provider.analysisHistory[index];
                        return ListTile(
                          leading: Icon(
                            item.isAuthentic
                                ? Icons.check_circle
                                : Icons.warning,
                            color: item.isAuthentic
                                ? AppColors.success
                                : AppColors.error,
                          ),
                          title: Text(
                            item.isAuthentic
                                ? 'Authentic'
                                : 'Potential Deepfake',
                            style: const TextStyle(
                              color: AppColors.textPrimaryDark,
                            ),
                          ),
                          subtitle: Text(
                            _formatTime(item.analyzedAt),
                            style: TextStyle(
                              color: AppColors.textSecondaryDark,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimaryDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 12),
        ),
      ],
    );
  }
}

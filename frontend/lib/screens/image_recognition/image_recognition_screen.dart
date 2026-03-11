import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:risk_guard/core/theme/app_colors.dart';
import 'package:risk_guard/core/theme/app_text_styles.dart';
import 'package:risk_guard/core/services/api_service.dart';
import 'package:risk_guard/core/models/analysis_models.dart';
import 'package:risk_guard/core/services/scan_history_provider.dart';
import 'package:risk_guard/core/widgets/result_bottom_sheet.dart';
import 'package:risk_guard/screens/blockchain/blockchain_report_screen.dart';

/// Image Recognition/Deepfake Detection screen
class ImageRecognitionScreen extends StatefulWidget {
  const ImageRecognitionScreen({super.key});

  @override
  State<ImageRecognitionScreen> createState() => _ImageRecognitionScreenState();
}

class _ImageRecognitionScreenState extends State<ImageRecognitionScreen> {
  final ImagePicker _picker = ImagePicker();
  final ApiService _apiService = ApiService();
  XFile? _selectedFile;
  Uint8List? _lastFileBytes;
  bool _isVideo = false;
  bool _isAnalyzing = false;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedFile = image;
          _isVideo = false;
        });
        _analyzeMedia();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error selecting image: $e')));
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 30),
      );

      if (video != null) {
        setState(() {
          _selectedFile = video;
          _isVideo = true;
        });
        _analyzeMedia();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error selecting video: $e')));
      }
    }
  }

  Future<void> _analyzeMedia() async {
    if (_selectedFile == null) return;
    setState(() => _isAnalyzing = true);

    try {
      // Read file bytes
      Uint8List? fileBytes;
      if (kIsWeb) {
        fileBytes = await _selectedFile!.readAsBytes();
      } else {
        fileBytes = await io.File(_selectedFile!.path).readAsBytes();
      }

      if (fileBytes.isEmpty) {
        if (mounted) {
          setState(() => _isAnalyzing = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Could not read file')));
        }
        return;
      }

      // Store for blockchain reporting
      _lastFileBytes = fileBytes;

      if (_isVideo) {
        // Video analysis
        final result = await _apiService.analyzeVideo(
          fileBytes,
          filename: _selectedFile!.name,
        );
        setState(() => _isAnalyzing = false);
        if (mounted) {
          if (result.isSuccess && result.data != null) {
            _showVideoResult(result.data!);
          } else {
            _showErrorResult(result.error ?? 'Video analysis failed');
          }
        }
      } else {
        // Image analysis
        final result = await _apiService.analyzeImage(
          fileBytes,
          filename: _selectedFile!.name,
        );
        setState(() => _isAnalyzing = false);
        if (mounted) {
          if (result.isSuccess && result.data != null) {
            _showImageResult(result.data!);
          } else {
            _showErrorResult(result.error ?? 'Image analysis failed');
          }
        }
      }
    } catch (e) {
      setState(() => _isAnalyzing = false);
      if (mounted) {
        _showErrorResult('Analysis error: $e');
      }
    }
  }

  void _showImageResult(ImageAnalysisResult data) {
    context.read<ScanHistoryProvider>().addScan(
      ScanHistoryEntry(
        id: const Uuid().v4(),
        type: ScanType.image,
        timestamp: DateTime.now(),
        riskLevel: data.aiGeneratedProbability >= 0.7
            ? 'HIGH'
            : (data.aiGeneratedProbability >= 0.3 ? 'MEDIUM' : 'LOW'),
        riskScore: (data.aiGeneratedProbability * 100).round(),
        summary: data.isAiGenerated
            ? 'AI-Generated Detected'
            : 'Authentic Image',
        explanation: data.explanation,
      ),
    );

    final bool isSafe = !data.isAiGenerated;
    ResultBottomSheet.show(
      context: context,
      title: isSafe ? 'Authentic Image' : 'AI-Generated Detected',
      explanation: data.explanation,
      resultColor: isSafe ? AppColors.successGreen : AppColors.dangerRed,
      resultIcon: isSafe ? Icons.check_circle_rounded : Icons.warning_rounded,
      metrics: {
        'AI Probability': '${(data.aiGeneratedProbability * 100).round()}%',
        'Confidence': '${(data.confidence * 100).round()}%',
      },
      chips: data.detectedPatterns,
      onReportToBlockchain: !isSafe && _lastFileBytes != null
          ? () => _navigateToBlockchainReport(
              threatType: 'AI-Generated Image',
              aiResult: 'AI-Generated',
              confidence: data.aiGeneratedProbability,
            )
          : null,
    );
  }

  void _showVideoResult(VideoAnalysisResult data) {
    context.read<ScanHistoryProvider>().addScan(
      ScanHistoryEntry(
        id: const Uuid().v4(),
        type: ScanType.video,
        timestamp: DateTime.now(),
        riskLevel: data.deepfakeProbability >= 0.7
            ? 'HIGH'
            : (data.deepfakeProbability >= 0.3 ? 'MEDIUM' : 'LOW'),
        riskScore: (data.deepfakeProbability * 100).round(),
        summary: data.isDeepfake ? 'Deepfake Detected' : 'Authentic Video',
        explanation: data.explanation,
      ),
    );

    final bool isSafe = !data.isDeepfake;
    ResultBottomSheet.show(
      context: context,
      title: isSafe ? 'Authentic Video' : 'Deepfake Detected',
      explanation: data.explanation,
      resultColor: isSafe ? AppColors.successGreen : AppColors.dangerRed,
      resultIcon: isSafe ? Icons.check_circle_rounded : Icons.warning_rounded,
      metrics: {
        'Deepfake Prob': '${(data.deepfakeProbability * 100).round()}%',
        'Confidence': '${(data.confidence * 100).round()}%',
        'Frames': '${data.analyzedFrames}',
      },
      onReportToBlockchain: !isSafe && _lastFileBytes != null
          ? () => _navigateToBlockchainReport(
              threatType: 'Deepfake Video',
              aiResult: 'Deepfake',
              confidence: data.deepfakeProbability,
            )
          : null,
    );
  }

  void _navigateToBlockchainReport({
    required String threatType,
    required String aiResult,
    required double confidence,
  }) {
    if (_lastFileBytes == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlockchainReportScreen(
          imageBytes: _lastFileBytes!,
          threatType: threatType,
          aiResult: aiResult,
          confidence: confidence,
          filename: _selectedFile?.name,
        ),
      ),
    );
  }

  void _showErrorResult(String error) {
    ResultBottomSheet.show(
      context: context,
      title: 'Analysis Failed',
      explanation: error,
      resultColor: AppColors.dangerRed,
      resultIcon: Icons.error_outline,
      buttonText: 'OK',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Deepfake Detector',
                style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.bold),
              ).animate().fadeIn().slideX(begin: -0.1),

              const SizedBox(height: 24),

              // Scanner Area
              Container(
                height: 300,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.darkCard,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                  image: _selectedFile != null && !_isVideo && !kIsWeb
                      ? DecorationImage(
                          image: FileImage(io.File(_selectedFile!.path)),
                          fit: BoxFit.cover,
                          opacity: _isAnalyzing ? 0.5 : 1.0,
                        )
                      : null,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Empty State or Video Placeholder
                    if (_selectedFile == null)
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_rounded,
                            size: 64,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.3,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Select media to scan',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      )
                    else if (_isVideo)
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.video_file_rounded,
                            size: 64,
                            color: AppColors.primaryGold.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Video Selected',
                            style: AppTextStyles.h3.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            _selectedFile!.name,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),

                    // Scanning Animation
                    if (_isAnalyzing)
                      Container(
                            width: double.infinity,
                            height: 4,
                            color: AppColors.primaryPurple,
                          )
                          .animate(
                            onPlay: (controller) =>
                                controller.repeat(reverse: true),
                          )
                          .slideY(begin: -40, end: 40, duration: 2.seconds),

                    if (_isAnalyzing)
                      const Positioned(
                        bottom: 20,
                        child: Text(
                          'Analyzing structure...',
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                      ),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

              const SizedBox(height: 24),

              // Stats Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Media Scanned with Thumbnail
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        padding: const EdgeInsets.all(
                          2,
                        ), // Small gap for border
                        decoration: BoxDecoration(
                          color: AppColors.darkCard,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.successGreen),
                        ),
                        child: ClipOval(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Image(
                                image: AssetImage(
                                  'assets/images/placeholder_image.png',
                                ),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                              Container(color: Colors.black26), // Dim overlay
                              const Icon(
                                Icons.image,
                                color: Colors.white,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Media Scanned',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  // Scan Video Button (Replaces Threats Found)
                  GestureDetector(
                    onTap: _pickVideo,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGold.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primaryGold),
                          ),
                          child: const Icon(
                            Icons.video_camera_back_rounded,
                            color: AppColors.primaryGold,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Scan Video',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1),

              const SizedBox(height: 24),

              // Action Buttons
              Center(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isAnalyzing
                        ? null
                        : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text(
                      'Select from Gallery',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
                        if (states.contains(WidgetState.hovered)) {
                          return Colors.red; // User requested Red on hover
                        }
                        return AppColors.primaryGold;
                      }),
                      foregroundColor: WidgetStateProperty.all(
                        AppColors.darkBackground,
                      ),
                      padding: WidgetStateProperty.all(
                        const EdgeInsets.symmetric(vertical: 18),
                      ),
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms),

              const SizedBox(height: 32),

              const SizedBox(height: 32),

              // Recent Scans
              Text(
                'Recent Scans',
                style: AppTextStyles.h4,
              ).animate().fadeIn(delay: 500.ms),
              const SizedBox(height: 16),
              SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildRecentScanItem(Icons.image, AppColors.successGreen),
                    _buildRecentScanItem(Icons.video_file, AppColors.dangerRed),
                    _buildRecentScanItem(Icons.image, AppColors.successGreen),
                    _buildRecentScanItem(Icons.image, AppColors.successGreen),
                  ],
                ),
              ).animate().fadeIn(delay: 600.ms).slideX(begin: 0.1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentScanItem(IconData icon, Color statusColor) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 32),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

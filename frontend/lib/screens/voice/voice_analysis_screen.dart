import 'dart:async';
import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:risk_guard/core/theme/app_colors.dart';
import 'package:risk_guard/core/theme/app_text_styles.dart';
import 'package:risk_guard/core/constants/app_constants.dart';
import 'package:risk_guard/core/services/api_service.dart';
import 'package:risk_guard/core/models/analysis_models.dart';
import 'package:risk_guard/core/services/scan_history_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

/// Voice Analysis Lab screen with Bar Visualizer
class VoiceAnalysisScreen extends StatefulWidget {
  const VoiceAnalysisScreen({super.key});

  @override
  State<VoiceAnalysisScreen> createState() => _VoiceAnalysisScreenState();
}

class _VoiceAnalysisScreenState extends State<VoiceAnalysisScreen>
    with TickerProviderStateMixin {
  late AnimationController _visualizerController;
  Timer? _amplitudeTimer;
  double _currentAmplitude = 0.0;

  // Analysis states
  AnalysisState _currentState = AnalysisState.idle;
  int _riskScore = 0;
  String _identityStatus = "Unverified";
  String _analysisExplanation = '';
  double _confidence = 0.0;
  List<String> _detectedPatterns = [];

  // Audio recording
  final AudioRecorder _audioRecorder = AudioRecorder();
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    // Faster animation for snappier bar movement
    _visualizerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _amplitudeTimer?.cancel();
    _visualizerController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_currentState == AnalysisState.idle) {
      // Check permission (skip on web — browser handles it)
      if (!kIsWeb) {
        var status = await Permission.microphone.status;
        if (!status.isGranted) {
          status = await Permission.microphone.request();
          if (!status.isGranted) {
            if (mounted) _showPermissionDialog();
            return;
          }
        }
      }

      // Start recording
      try {
        if (await _audioRecorder.hasPermission()) {
          await _audioRecorder.start(
            const RecordConfig(
              encoder: AudioEncoder.wav,
              sampleRate: 16000,
              numChannels: 1,
            ),
            path: kIsWeb ? '' : await _getTempPath(),
          );

          setState(() {
            _currentState = AnalysisState.recording;
            _visualizerController.repeat();
            _startAmplitudeSimulation();
          });
        } else {
          if (mounted) _showPermissionDialog();
        }
      } catch (e) {
        debugPrint('Recording error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not start recording: $e'),
              backgroundColor: AppColors.dangerRed,
            ),
          );
        }
      }
    } else if (_currentState == AnalysisState.recording) {
      // Stop recording and send to backend
      await _stopAndAnalyze();
    } else if (_currentState == AnalysisState.complete) {
      // Reset
      setState(() {
        _currentState = AnalysisState.idle;
        _riskScore = 0;
        _identityStatus = "Unverified";
        _analysisExplanation = '';
        _confidence = 0.0;
        _detectedPatterns = [];
        _visualizerController.stop();
        _visualizerController.reset();
        _amplitudeTimer?.cancel();
        _currentAmplitude = 0.0;
      });
    }
  }

  Future<String> _getTempPath() async {
    // Use a simple temp path for mobile
    return '/tmp/riskguard_recording_${DateTime.now().millisecondsSinceEpoch}.wav';
  }

  Future<void> _stopAndAnalyze() async {
    setState(() {
      _currentState = AnalysisState.analyzing;
      _amplitudeTimer?.cancel();
      _currentAmplitude = 0.0;
    });

    try {
      // Stop recording and get audio data
      final path = await _audioRecorder.stop();
      Uint8List? audioBytes;

      if (kIsWeb) {
        // On web, record returns a blob URL — fetch it via http
        if (path != null) {
          try {
            final response = await http.get(Uri.parse(path));
            if (response.statusCode == 200) {
              audioBytes = response.bodyBytes;
            }
          } catch (e) {
            debugPrint('Failed to fetch web blob: $e');
          }
        }
      }

      // Read the file bytes
      if (path != null && !kIsWeb) {
        final file = await _readFileBytes(path);
        audioBytes = file;
      }

      if (audioBytes == null || audioBytes.isEmpty) {
        // Fallback: send empty analysis request to test connection
        if (mounted) {
          setState(() {
            _currentState = AnalysisState.complete;
            _riskScore = 0;
            _identityStatus = 'No Audio';
            _analysisExplanation =
                'Could not capture audio data. Please try again.';
          });
        }
        return;
      }

      // Send to backend
      final result = await _apiService.analyzeVoice(audioBytes);

      if (mounted) {
        if (result.isSuccess && result.data != null) {
          final data = result.data!;
          setState(() {
            _currentState = AnalysisState.complete;
            // Map synthetic probability (0.0-1.0) to risk score (0-10)
            _riskScore = (data.syntheticProbability * 10).round().clamp(0, 10);
            _identityStatus = data.isLikelyAI
                ? 'Synthetic Pattern'
                : 'Human Voice';
            _analysisExplanation = data.explanation;
            _confidence = data.confidence;
            _detectedPatterns = data.detectedPatterns;
          });

          // Store in scan history
          context.read<ScanHistoryProvider>().addScan(
            ScanHistoryEntry(
              id: const Uuid().v4(),
              type: ScanType.voice,
              timestamp: DateTime.now(),
              riskLevel: _riskScore >= 7
                  ? 'HIGH'
                  : (_riskScore >= 4 ? 'MEDIUM' : 'LOW'),
              riskScore: _riskScore * 10,
              summary:
                  'Voice: ${data.isLikelyAI ? "AI Detected" : "Human Verified"}',
              explanation: data.explanation,
            ),
          );
        } else {
          setState(() {
            _currentState = AnalysisState.complete;
            _riskScore = 0;
            _identityStatus = 'Error';
            _analysisExplanation = result.error ?? 'Analysis failed';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentState = AnalysisState.complete;
          _riskScore = 0;
          _identityStatus = 'Error';
          _analysisExplanation = 'Analysis error: $e';
        });
      }
    }
  }

  Future<Uint8List?> _readFileBytes(String path) async {
    try {
      final file = io.File(path);
      return await file.readAsBytes();
    } catch (e) {
      debugPrint('Failed to read file: $e');
      return null;
    }
  }

  void _startAmplitudeSimulation() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 150), (
      timer,
    ) {
      if (!mounted) return;

      // Simulate speech patterns: burst strings of high amplitude, followed by pauses
      setState(() {
        if (math.Random().nextDouble() > 0.4) {
          // Speaking: Random amplitude 0.4 - 1.0 (Distinct voice)
          _currentAmplitude = 0.4 + math.Random().nextDouble() * 0.6;
        } else {
          // Pause/Silence: Strict 0.0 so the line is perfectly straight
          _currentAmplitude = 0.0;
        }
      });
    });
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        title: Text('Microphone Needed', style: AppTextStyles.h3),
        content: Text(
          'RiskGuard needs microphone access to analyze voice patterns for deepfakes.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: Text(
              'Settings',
              style: TextStyle(color: AppColors.primaryGold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(AppConstants.spaceLarge),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Voice Analysis Lab',
                    style: AppTextStyles.h2.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.darkCard,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(
                      Icons.history_rounded,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            // Main Content Area
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      // Visualizer Card
                      Container(
                        height: 320,
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF0F0F1A,
                          ), // Deep dark for contrast
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: AppColors.border.withValues(alpha: 0.3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Bar Visualizer
                            AnimatedBuilder(
                              animation: _visualizerController,
                              builder: (context, child) {
                                return CustomPaint(
                                  size: const Size(
                                    double.infinity,
                                    120,
                                  ), // Visualizer height
                                  painter: SpectrumWavePainter(
                                    animationValue: _visualizerController.value,
                                    isActive:
                                        _currentState ==
                                            AnalysisState.recording ||
                                        _currentState ==
                                            AnalysisState.analyzing,
                                    amplitude: _currentAmplitude,
                                  ),
                                );
                              },
                            ),

                            // Artifact Detected Label
                            if (_currentState == AnalysisState.analyzing ||
                                (_currentState == AnalysisState.complete &&
                                    _riskScore > 5))
                              Positioned(
                                top: 0,
                                left: 0,
                                child: _buildAnnotationLabel(
                                  'ARTIFACT DETECTED',
                                  _detectedPatterns.isNotEmpty
                                      ? '${_detectedPatterns.first}\nConfidence: ${(_confidence * 100).toStringAsFixed(0)}%'
                                      : 'Synthetic Pattern\nConfidence: ${(_confidence * 100).toStringAsFixed(0)}%',
                                  AppColors.primaryGold,
                                ).animate().fadeIn().slideX(),
                              ),

                            // Pitch Stability Label
                            if (_currentState == AnalysisState.analyzing ||
                                (_currentState == AnalysisState.complete &&
                                    _riskScore > 5))
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: _buildAnnotationLabel(
                                  'ANALYSIS METHOD',
                                  _analysisExplanation.length > 40
                                      ? '${_analysisExplanation.substring(0, 40)}...'
                                      : (_analysisExplanation.isEmpty
                                            ? 'Processing...'
                                            : _analysisExplanation),
                                  AppColors.textSecondary,
                                  isRightAligned: true,
                                ).animate().fadeIn().slideX(begin: 0.1),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      Text(
                        'LIVE METRICS',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 2,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Metrics Grid
                      Row(
                        children: [
                          // Risk Score Card
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Risk Score',
                              icon: Icons.shield_rounded,
                              iconColor: _getRiskColor(),
                              content: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '$_riskScore',
                                          style: AppTextStyles.h1.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 42,
                                          ),
                                        ),
                                        TextSpan(
                                          text: '/10',
                                          style: AppTextStyles.h3.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getRiskColor().withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.circle,
                                          size: 8,
                                          color: _getRiskColor(),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _getRiskLabel(),
                                          style: AppTextStyles.labelSmall
                                              .copyWith(
                                                color: _getRiskColor(),
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(width: 16),

                          // Identity Card
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Identity',
                              icon: Icons.fingerprint_rounded,
                              iconColor: AppColors.textSecondary,
                              content: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  Text(
                                    _identityStatus,
                                    style: AppTextStyles.h3.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _currentState == AnalysisState.idle
                                        ? 'Waiting...'
                                        : 'No match found',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      // Action Button (Start/Reset)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _toggleRecording,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _currentState == AnalysisState.recording
                                ? AppColors.dangerRed
                                : AppColors.primaryGold,
                            foregroundColor:
                                _currentState == AnalysisState.recording
                                ? Colors.white
                                : AppColors.textOnGold,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            _getButtonText(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                      const SizedBox(height: 120), // Bottom padding for nav bar
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnotationLabel(
    String label,
    String value,
    Color color, {
    bool isRightAligned = false,
  }) {
    return Column(
      crossAxisAlignment: isRightAligned
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (!isRightAligned)
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: color, size: 14),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        if (isRightAligned)
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),

        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.darkBackground.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            value,
            textAlign: isRightAligned ? TextAlign.right : TextAlign.left,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget content,
  }) {
    return Container(
      height: 160,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Spacer(),
          content,
        ],
      ),
    );
  }

  Color _getRiskColor() {
    if (_riskScore >= 7) return AppColors.primaryGold;
    if (_riskScore >= 4) return Colors.orange;
    return AppColors.successGreen;
  }

  String _getRiskLabel() {
    if (_currentState == AnalysisState.idle) return 'READY';
    if (_riskScore >= 7) return 'HIGH RISK';
    if (_riskScore >= 4) return 'MODERATE';
    return 'SAFE';
  }

  String _getButtonText() {
    switch (_currentState) {
      case AnalysisState.idle:
        return 'Start Voice Analysis';
      case AnalysisState.recording:
        return 'Stop & Analyze';
      case AnalysisState.analyzing:
        return 'Analyzing with AI...';
      case AnalysisState.complete:
        return 'Reset Analysis';
    }
  }
}

class SpectrumWavePainter extends CustomPainter {
  final double animationValue;
  final bool isActive;
  final double amplitude;

  SpectrumWavePainter({
    required this.animationValue,
    required this.isActive,
    required this.amplitude,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Define Gradient Shader (Linear: Red/Pink -> Purple -> Cyan/Blue)
    final gradient = LinearGradient(
      colors: [
        const Color(0xFFFF5F6D), // Red/Pink
        const Color(0xFFD946EF), // Purple
        const Color(0xFF06B6D4), // Cyan/Blue
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final paint = Paint()
      ..shader = gradient
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // 2. Draw Center Line (Idle State Base)
    if (!isActive) {
      final linePath = Path();
      linePath.moveTo(0, size.height / 2);
      linePath.lineTo(size.width, size.height / 2);

      // Draw a slightly thicker, glowing line for idle
      canvas.drawPath(linePath, paint..strokeWidth = 3.0);
      return;
    }

    // 3. Draw Waves (Active State)
    final t = animationValue * 2 * math.pi;

    // Config: Draw multiple overlapping waves for the "spectrum" look
    const int waveCount = 5;

    for (int w = 0; w < waveCount; w++) {
      final path = Path();
      final double phase = w * (math.pi / 3);
      final double speed = 1.0 + (w * 0.15); // Layered speeds
      final double amplitudeScale = 1.0 - (w * 0.15); // Outer waves smaller

      path.moveTo(0, size.height / 2);

      // Higher resolution for smooth curves
      for (double i = 0; i <= size.width; i += 2) {
        double normalizedX = i / size.width;

        // Symmetrical Envelope (taper ends)
        double envelope = math.sin(normalizedX * math.pi);

        // Base sine wave
        double wave = math.sin(
          (normalizedX * 6 * math.pi) + (t * speed) + phase,
        );

        // Dynamic "breathing" amplitude modulated by time
        double breathing = math.sin(t * 0.5 + w) * 0.2 + 0.8;

        // Add some jitter for voice-like randomness
        double jitter = math.sin(i * 0.1 + t * 4) * 0.1;

        // Apply external simulated amplitude (speech vs silence)
        // If amplitude is 0 (silence), yOffset becomes 0 -> Straight Line
        double yOffset =
            (wave + jitter) *
            (size.height * 0.4) *
            envelope *
            amplitudeScale *
            breathing *
            amplitude;

        path.lineTo(i, (size.height / 2) + yOffset);
      }

      // Vary stroke width for depth (foreground thicker)
      paint.strokeWidth = w == 0 ? 2.5 : 1.5;

      // Fade out background waves slightly (optional, but shader handles most)
      paint.color = Colors.white.withValues(alpha: 1.0 - (w * 0.15));

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SpectrumWavePainter oldDelegate) {
    return animationValue != oldDelegate.animationValue ||
        isActive != oldDelegate.isActive;
  }
}

enum AnalysisState { idle, recording, analyzing, complete }

import 'dart:ui' show ImageFilter;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../providers/voice_analysis_provider.dart';
import '../services/voice_recorder_service.dart';
import '../services/voice_analyzer_service.dart';

class VoiceAnalysisScreen extends StatelessWidget {
  const VoiceAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VoiceAnalysisProvider(),
      child: const _VoiceAnalysisContent(),
    );
  }
}

class _VoiceAnalysisContent extends StatelessWidget {
  const _VoiceAnalysisContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          // Premium Background Blobs
          Positioned(
            top: -100,
            right: -100,
            child: _BackgroundBlob(
              color: AppColors.primary.withValues(alpha: 0.15),
              size: 400,
            ),
          ),
          Positioned(
            bottom: -50,
            left: -100,
            child: _BackgroundBlob(
              color: AppColors.info.withValues(alpha: 0.1),
              size: 300,
            ),
          ),

          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 120,
                floating: false,
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    'Voice Analysis',
                    style: AppTypography.headlineSmall.copyWith(
                      color: AppColors.textPrimaryDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  centerTitle: true,
                  background: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Consumer<VoiceAnalysisProvider>(
                  builder: (context, provider, _) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          const SizedBox(height: 10),

                          // Glass Info Card
                          _GlassCard(child: _buildInfoCard())
                              .animate()
                              .fadeIn(duration: 400.ms)
                              .slideY(begin: 0.1, end: 0),

                          if (provider.errorMessage != null)
                            _GlassCard(
                              margin: const EdgeInsets.only(top: 16),
                              borderColor: AppColors.error.withValues(
                                alpha: 0.5,
                              ),
                              child: _buildErrorCard(provider.errorMessage!),
                            ).animate().shake(),

                          const SizedBox(height: 40),

                          // Dynamic Waveform Visualizer
                          _WaveformVisualizer(
                            amplitude: provider.currentAmplitude,
                            isRecording:
                                provider.recordingState ==
                                RecordingState.recording,
                          ).animate().scale(
                            duration: 400.ms,
                            curve: Curves.easeOutBack,
                          ),

                          const SizedBox(height: 40),

                          // Modern Recording Controls
                          _RecordButton(
                            state: provider.recordingState,
                            isAnalyzing: provider.isAnalyzing,
                            onStart: () => provider.startRecording(),
                            onStop: () => provider.stopAndAnalyze(),
                            onCancel: () => provider.cancelRecording(),
                          ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

                          const SizedBox(height: 32),

                          // Status Text
                          _buildStatusText(provider),

                          const SizedBox(height: 40),

                          // Premium Result Section
                          if (provider.lastResult != null) ...[
                            _GlassCard(
                                  padding: EdgeInsets.zero,
                                  child: _ResultCard(
                                    result: provider.lastResult!,
                                  ),
                                )
                                .animate()
                                .fadeIn(duration: 500.ms)
                                .slideY(
                                  begin: 0.2,
                                  end: 0,
                                  curve: Curves.easeOutCubic,
                                ),
                            const SizedBox(height: 24),
                          ],

                          // Trends and Analytics
                          if (provider.history.isNotEmpty) ...[
                            _GlassCard(
                                  title: 'Analysis Trend',
                                  icon: Icons.auto_graph_rounded,
                                  iconColor: AppColors.primary,
                                  child: _TrendChart(history: provider.history),
                                )
                                .animate()
                                .fadeIn(duration: 600.ms, delay: 100.ms)
                                .slideY(begin: 0.2, end: 0),
                            const SizedBox(height: 24),
                          ],

                          // Live Graph (only when recording)
                          if (provider.recordingState ==
                              RecordingState.recording) ...[
                            _GlassCard(
                                  title: 'Live Waveform',
                                  icon: Icons.sensors_rounded,
                                  iconColor: AppColors.error,
                                  child: _LiveAmplitudeChart(
                                    amplitudeData: provider.amplitudeHistory,
                                  ),
                                )
                                .animate()
                                .fadeIn(duration: 300.ms)
                                .scale(begin: const Offset(0.9, 0.9)),
                            const SizedBox(height: 24),
                          ],

                          // Comparison Section
                          if (provider.history.length >= 2) ...[
                            _GlassCard(
                                  title: 'Recent Overviews',
                                  icon: Icons.compare_arrows_rounded,
                                  iconColor: AppColors.info,
                                  child: _ComparisonChart(
                                    recentResults: provider.history
                                        .take(5)
                                        .toList(),
                                  ),
                                )
                                .animate()
                                .fadeIn(duration: 600.ms, delay: 200.ms)
                                .slideY(begin: 0.2, end: 0),
                          ],

                          const SizedBox(height: 60),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.psychology_outlined, color: AppColors.info),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI Voice Detection',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.textPrimaryDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Detect AI synthesized or deep-faked voices in real-time.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusText(VoiceAnalysisProvider provider) {
    String text;
    Color color;

    if (provider.isAnalyzing) {
      text = 'Analyzing acoustic features...';
      color = AppColors.info;
    } else {
      switch (provider.recordingState) {
        case RecordingState.recording:
          text = 'RECORDING LIVE';
          color = AppColors.error;
        case RecordingState.paused:
          text = 'Recording on hold';
          color = AppColors.warning;
        case RecordingState.stopped:
          text = 'Analysis ready';
          color = AppColors.success;
        case RecordingState.idle:
          text = 'Ready to Analyze';
          color = AppColors.textTertiaryDark;
      }
    }

    return Text(
          text,
          style: AppTypography.labelMedium.copyWith(
            color: color,
            letterSpacing: 1.5,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        )
        .animate(
          target: provider.recordingState == RecordingState.recording ? 1 : 0,
        )
        .fade(duration: 400.ms)
        .tint(color: color);
  }

  Widget _buildErrorCard(String message) {
    return Row(
      children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: AppTypography.bodySmall.copyWith(color: AppColors.error),
          ),
        ),
      ],
    );
  }
}

/// Dynamic Background Blob
class _BackgroundBlob extends StatelessWidget {
  final Color color;
  final double size;

  const _BackgroundBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

/// Reusable Glassmorphic Card
class _GlassCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final IconData? icon;
  final Color? iconColor;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? borderColor;

  const _GlassCard({
    required this.child,
    this.title,
    this.icon,
    this.iconColor,
    this.padding,
    this.margin,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: padding ?? const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: borderColor ?? Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Row(
                    children: [
                      if (icon != null) ...[
                        Icon(
                          icon,
                          color: iconColor ?? AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        title!,
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.textPrimaryDark,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Enhanced Waveform Visualizer
class _WaveformVisualizer extends StatelessWidget {
  final double amplitude;
  final bool isRecording;

  const _WaveformVisualizer({
    required this.amplitude,
    required this.isRecording,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: CustomPaint(
        painter: _WaveformPainter(
          amplitude: amplitude,
          isRecording: isRecording,
          color: isRecording ? AppColors.error : AppColors.primary,
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double amplitude;
  final bool isRecording;
  final Color color;

  _WaveformPainter({
    required this.amplitude,
    required this.isRecording,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final centerY = size.height / 2;
    const barCount = 45;
    final spacing = size.width / barCount;

    final random = Random(42);

    for (int i = 0; i < barCount; i++) {
      final x = i * spacing + spacing / 2;

      // Calculate height based on index (center is taller)
      final distanceFromCenter = (i - barCount / 2).abs() / (barCount / 2);
      final centerWeight = 1.0 - distanceFromCenter;

      final baseHeight = (random.nextDouble() * 0.2 + 0.1) * centerWeight;
      final dynamicHeight = isRecording ? (amplitude * 0.8) : 0.05;

      final height = (size.height * 0.4) * (baseHeight + dynamicHeight);

      // Draw mirrored bars
      canvas.drawLine(
        Offset(x, centerY - height),
        Offset(x, centerY + height),
        paint,
      );

      // Secondary lighter bars for glow effect
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.2)
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

      canvas.drawLine(
        Offset(x, centerY - height),
        Offset(x, centerY + height),
        glowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.amplitude != amplitude ||
        oldDelegate.isRecording != isRecording;
  }
}

/// Refined Record Button
class _RecordButton extends StatelessWidget {
  final RecordingState state;
  final bool isAnalyzing;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onCancel;

  const _RecordButton({
    required this.state,
    required this.isAnalyzing,
    required this.onStart,
    required this.onStop,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (isAnalyzing) {
      return const _AnalyzingIndicator();
    }

    final isRecording = state == RecordingState.recording;

    return Column(
      children: [
        GestureDetector(
          onTap: isRecording ? onStop : onStart,
          child:
              Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: isRecording
                            ? [AppColors.error, const Color(0xFFB91C1C)]
                            : [AppColors.primary, AppColors.primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (isRecording
                                      ? AppColors.error
                                      : AppColors.primary)
                                  .withValues(alpha: 0.4),
                          blurRadius: 25,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                  )
                  .animate(target: isRecording ? 1 : 0)
                  .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.1, 1.1),
                    duration: 200.ms,
                  ),
        ),
        if (isRecording) ...[
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded, size: 20),
            label: const Text('Discard'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textTertiaryDark,
            ),
          ),
        ],
      ],
    );
  }
}

class _AnalyzingIndicator extends StatelessWidget {
  const _AnalyzingIndicator();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: CircularProgressIndicator(
            strokeWidth: 6,
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
            backgroundColor: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'AI Analysis in Progress',
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.textSecondaryDark,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// Premium Result Display
class _ResultCard extends StatelessWidget {
  final VoiceAnalysisResult result;

  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final color = result.isLikelyAI ? AppColors.error : AppColors.success;
    final percentage = (result.syntheticProbability * 100).toInt();

    return Column(
      children: [
        // Top Banner
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                result.isLikelyAI
                    ? Icons.warning_rounded
                    : Icons.verified_user_rounded,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                result.isLikelyAI ? 'HIGH AI PROBABILITY' : 'HUMAN VERIFIED',
                style: AppTypography.overline.copyWith(color: color),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.isLikelyAI
                              ? 'Possibly Synthetic'
                              : 'Authentic Voice',
                          style: AppTypography.headlineSmall.copyWith(
                            color: AppColors.textPrimaryDark,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Confidence Level: ${(result.confidence * 100).toInt()}%',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textTertiaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ResultCircularIndicator(
                    percentage: percentage,
                    color: color,
                  ),
                ],
              ),

              const SizedBox(height: 32),

              const Divider(color: Colors.white10),

              const SizedBox(height: 24),

              Text(
                result.explanation,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondaryDark,
                  height: 1.6,
                ),
              ),

              if (result.detectedPatterns.isNotEmpty) ...[
                const SizedBox(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 10,
                  children: result.detectedPatterns.map((pattern) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        pattern,
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ResultCircularIndicator extends StatelessWidget {
  final int percentage;
  final Color color;

  const _ResultCircularIndicator({
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      height: 70,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: percentage / 100,
            strokeWidth: 8,
            valueColor: AlwaysStoppedAnimation(color),
            backgroundColor: Colors.white.withValues(alpha: 0.05),
          ),
          Text(
            '$percentage%',
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.textPrimaryDark,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// History Trend Chart
class _TrendChart extends StatelessWidget {
  final List<VoiceAnalysisResult> history;

  const _TrendChart({required this.history});

  @override
  Widget build(BuildContext context) {
    final displayHistory = history.take(10).toList().reversed.toList();

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.white.withValues(alpha: 0.05),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 35,
                getTitlesWidget: (value, meta) => Text(
                  '${value.toInt()}%',
                  style: const TextStyle(color: Colors.white30, fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < displayHistory.length) {
                    return Text(
                      '#${displayHistory.length - index}',
                      style: const TextStyle(
                        color: Colors.white30,
                        fontSize: 10,
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: displayHistory.asMap().entries.map((entry) {
                return FlSpot(
                  entry.key.toDouble(),
                  entry.value.syntheticProbability * 100,
                );
              }).toList(),
              isCurved: true,
              color: AppColors.primary,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) =>
                    FlDotCirclePainter(
                      radius: 4,
                      color: displayHistory[index].isLikelyAI
                          ? AppColors.error
                          : AppColors.success,
                      strokeWidth: 2,
                      strokeColor: AppColors.backgroundDark,
                    ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.2),
                    AppColors.primary.withValues(alpha: 0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Real-time Amplitude Chart
class _LiveAmplitudeChart extends StatelessWidget {
  final List<double> amplitudeData;

  const _LiveAmplitudeChart({required this.amplitudeData});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          minY: 0,
          maxY: 1.1,
          lineBarsData: [
            LineChartBarData(
              spots: amplitudeData.asMap().entries.map((entry) {
                return FlSpot(entry.key.toDouble(), entry.value);
              }).toList(),
              isCurved: true,
              color: AppColors.error,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppColors.error.withValues(alpha: 0.3),
                    AppColors.error.withValues(alpha: 0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Comparison Bar Chart
class _ComparisonChart extends StatelessWidget {
  final List<VoiceAnalysisResult> recentResults;

  const _ComparisonChart({required this.recentResults});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 100,
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 35,
                getTitlesWidget: (value, meta) => Text(
                  '${value.toInt()}%',
                  style: const TextStyle(color: Colors.white30, fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < recentResults.length) {
                    return Text(
                      '#${recentResults.length - index}',
                      style: const TextStyle(
                        color: Colors.white30,
                        fontSize: 10,
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: recentResults.asMap().entries.map((entry) {
            final color = entry.value.isLikelyAI
                ? AppColors.error
                : AppColors.success;
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.syntheticProbability * 100,
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.6)],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  width: 16,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

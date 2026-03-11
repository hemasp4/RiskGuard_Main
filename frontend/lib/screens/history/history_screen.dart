import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:risk_guard/core/theme/app_colors.dart';
import 'package:risk_guard/core/theme/app_text_styles.dart';
import 'package:risk_guard/core/services/scan_history_provider.dart';
import 'package:risk_guard/core/models/analysis_models.dart';
import 'package:risk_guard/screens/history/widgets/animated_phone_signal.dart';

/// Call Monitoring Screen (formerly History)
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isMonitoring = true;

  @override
  Widget build(BuildContext context) {
    final historyProvider = context.watch<ScanHistoryProvider>();

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Call Monitoring',
                style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.bold),
              ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1),

              const SizedBox(height: 24),

              // Monitoring Pulse Card
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isMonitoring = !_isMonitoring;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: _isMonitoring
                        ? AppColors.purpleGradient
                        : const LinearGradient(
                            colors: [AppColors.darkCard, AppColors.darkCard],
                          ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: _isMonitoring
                            ? AppColors.primaryGold.withValues(alpha: 0.3)
                            : Colors.transparent,
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _isMonitoring
                              ? AppColors.primaryPurple.withValues(alpha: 0.15)
                              : Colors.black12,
                          shape: BoxShape.circle,
                        ),
                        child: AnimatedPhoneSignal(
                          color: _isMonitoring
                              ? AppColors.primaryGold
                              : AppColors.textSecondary,
                          size: 72,
                          isActive: _isMonitoring,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isMonitoring
                            ? 'Monitoring Active'
                            : 'Monitoring Paused',
                        style: AppTextStyles.h4.copyWith(
                          color: _isMonitoring
                              ? AppColors.primaryGold
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isMonitoring
                            ? 'Scanning incoming calls in real-time'
                            : 'Tap to resume call monitoring',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

              const SizedBox(height: 24),

              // Stats Row — from real scan data
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      '${historyProvider.threatsBlocked}',
                      'Threats Found',
                      Icons.block_rounded,
                      AppColors.dangerRed,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      '${historyProvider.verifiedSafe}',
                      'Verified Safe',
                      Icons.verified_rounded,
                      AppColors.successGreen,
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),

              const SizedBox(height: 32),

              // Recent Scans List
              Text(
                'Recent Scans',
                style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold),
              ).animate().fadeIn(delay: 400.ms),
              const SizedBox(height: 16),

              if (historyProvider.entries.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.darkCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'No scan history yet.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 500.ms)
              else
                Column(
                  children: historyProvider.entries.take(10).map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildCallItem(
                        entry.summary,
                        _formatTimeAgo(entry.timestamp),
                        entry.riskLevel == 'HIGH'
                            ? 'Threat'
                            : (entry.riskLevel == 'MEDIUM'
                                  ? 'Moderate'
                                  : 'Safe'),
                        _getIconForScanType(entry.type),
                        _getColorForRiskLevel(entry.riskLevel),
                        _formatTimeAgo(entry.timestamp),
                      ),
                    );
                  }).toList(),
                ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1),

              const SizedBox(height: 80), // Bottom padding
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallItem(
    String name,
    String number,
    String status,
    IconData icon,
    Color color,
    String time,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  number,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                time,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getIconForScanType(ScanType type) {
    switch (type) {
      case ScanType.voice:
        return Icons.mic_none_rounded;
      case ScanType.image:
        return Icons.image_rounded;
      case ScanType.video:
        return Icons.videocam_rounded;
      case ScanType.text:
        return Icons.message_rounded;
    }
  }

  Color _getColorForRiskLevel(String level) {
    switch (level) {
      case 'HIGH':
        return AppColors.dangerRed;
      case 'MEDIUM':
        return Colors.orange;
      default:
        return AppColors.successGreen;
    }
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

/// Protection Status Card widget
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/services/method_channel_service.dart';
import '../../call_detection/providers/call_history_provider.dart';

class ProtectionStatusCard extends StatefulWidget {
  const ProtectionStatusCard({super.key});

  @override
  State<ProtectionStatusCard> createState() => _ProtectionStatusCardState();
}

class _ProtectionStatusCardState extends State<ProtectionStatusCard> {
  final _methodChannelService = MethodChannelService();
  bool _isBatteryOptimized = false;
  int _threatsBlocked = 0;
  int _highRiskCalls = 0;
  int _totalCalls = 0;

  @override
  void initState() {
    super.initState();
    _checkBatteryOptimization();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    final stats = await _methodChannelService.getProtectionStatistics();
    if (mounted) {
      setState(() {
        _threatsBlocked = stats['threatsBlockedToday'] ?? 0;
        _highRiskCalls = stats['highRiskCallsCount'] ?? 0;
        _totalCalls = stats['totalCallsCount'] ?? 0;
      });
    }
  }

  Future<void> _checkBatteryOptimization() async {
    final isOptimized = await _methodChannelService.checkBatteryOptimization();
    if (mounted) {
      setState(() {
        _isBatteryOptimized = isOptimized;
      });
    }
  }

  Future<void> _requestBatteryExemption() async {
    await _methodChannelService.requestBatteryOptimizationExemption();
    // Recheck after a delay (user might have granted it)
    await Future.delayed(const Duration(seconds: 2));
    _checkBatteryOptimization();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CallHistoryProvider>(
      builder: (context, provider, _) {
        final isActive = provider.isMonitoring;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isActive
                  ? [AppColors.primary, AppColors.primaryDark]
                  : [AppColors.cardDark, AppColors.surfaceDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: isActive ? 0.2 : 0.1,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isActive ? Icons.shield : Icons.shield_outlined,
                      color: isActive
                          ? Colors.white
                          : AppColors.textSecondaryDark,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isActive ? 'Protection Active' : 'Protection Off',
                          style: AppTypography.headlineMedium.copyWith(
                            color: isActive
                                ? Colors.white
                                : AppColors.textPrimaryDark,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isActive
                              ? 'You\'re protected from scams'
                              : 'Enable protection to stay safe',
                          style: AppTypography.bodyMedium.copyWith(
                            color: isActive
                                ? Colors.white.withValues(alpha: 0.8)
                                : AppColors.textSecondaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (isActive) {
                      provider.stopMonitoring();
                    } else {
                      provider.startMonitoring();
                    }
                    // Refresh statistics after toggling
                    await _loadStatistics();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isActive
                        ? Colors.white
                        : AppColors.primary,
                    foregroundColor: isActive
                        ? AppColors.primary
                        : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isActive ? 'Pause Protection' : 'Enable Protection',
                    style: AppTypography.labelLarge,
                  ),
                ),
              ),
              if (isActive) ...[
                const SizedBox(height: 16),
                _buildBatteryWarning(), // Battery optimization warning
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat('Total Calls', '$_totalCalls'),
                    _buildStat('Threats Blocked', '$_threatsBlocked'),
                    _buildStat('High Risk', '$_highRiskCalls'),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildBatteryWarning() {
    if (!_isBatteryOptimized) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.battery_alert, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Battery Optimization Detected',
                  style: AppTypography.labelSmall.copyWith(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'May stop protection in background',
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _requestBatteryExemption,
            style: TextButton.styleFrom(
              foregroundColor: Colors.orange,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            child: const Text('Fix'),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.headlineSmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

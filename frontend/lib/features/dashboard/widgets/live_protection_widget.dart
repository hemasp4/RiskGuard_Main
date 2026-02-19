import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/services/method_channel_service.dart';

/// Live protection status widget for dashboard
class LiveProtectionWidget extends StatefulWidget {
  const LiveProtectionWidget({super.key});

  @override
  State<LiveProtectionWidget> createState() => _LiveProtectionWidgetState();
}

class _LiveProtectionWidgetState extends State<LiveProtectionWidget> {
  final MethodChannelService _methodChannel = MethodChannelService();
  bool _isProtectionEnabled = true;
  int _threatsBlockedToday = 0;
  int _highRiskCallsCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProtectionStatus();
    // Refresh stats every 30 seconds
    Future.delayed(const Duration(seconds: 30), _refreshStats);
  }

  Future<void> _loadProtectionStatus() async {
    setState(() => _isLoading = true);

    final isEnabled = await _methodChannel.isProtectionEnabled();
    final stats = await _methodChannel.getProtectionStatistics();

    if (mounted) {
      setState(() {
        _isProtectionEnabled = isEnabled;
        _threatsBlockedToday = stats['threatsBlockedToday'] ?? 0;
        _highRiskCallsCount = stats['highRiskCallsCount'] ?? 0;
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshStats() async {
    if (!mounted) return;

    final stats = await _methodChannel.getProtectionStatistics();

    if (mounted) {
      setState(() {
        _threatsBlockedToday = stats['threatsBlockedToday'] ?? 0;
        _highRiskCallsCount = stats['highRiskCallsCount'] ?? 0;
      });

      // Schedule next refresh
      Future.delayed(const Duration(seconds: 30), _refreshStats);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isProtectionEnabled
              ? [AppColors.success, AppColors.success.withValues(alpha: 0.8)]
              : [
                  AppColors.textSecondaryLight,
                  AppColors.textSecondaryLight.withValues(alpha: 0.7),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:
                (_isProtectionEnabled
                        ? AppColors.success
                        : AppColors.textSecondaryLight)
                    .withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status and toggle
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isProtectionEnabled ? 'Protection Active' : 'Protection Off',
                  style: AppTypography.titleLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Switch(
                value: _isProtectionEnabled,
                onChanged: _toggleProtection,
                activeThumbColor: Colors.white,
                activeTrackColor: Colors.white.withValues(alpha: 0.3),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Statistics
          _isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                )
              : Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.block,
                        label: 'Blocked Today',
                        value: '$_threatsBlockedToday',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.warning_amber,
                        label: 'High Risk Calls',
                        value: '$_highRiskCallsCount',
                      ),
                    ),
                  ],
                ),

          if (!_isProtectionEnabled) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your device is not protected from scam calls',
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTypography.statNumber.copyWith(
              color: Colors.white,
              fontSize: 24,
            ),
          ),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleProtection(bool value) async {
    setState(() {
      _isProtectionEnabled = value;
    });

    if (value) {
      await _methodChannel.startCallMonitoringService();
    } else {
      await _methodChannel.stopCallMonitoringService();
    }

    // Refresh stats after toggling
    await _loadProtectionStatus();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Protection enabled' : 'Protection disabled'),
          backgroundColor: value ? AppColors.success : AppColors.error,
        ),
      );
    }
  }
}

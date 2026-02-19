/// Call History Screen - Displays past call risk analyses
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/risk_levels.dart';
import '../providers/call_history_provider.dart';
import '../services/call_risk_service.dart';

class CallHistoryScreen extends StatelessWidget {
  const CallHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call History'),
        actions: [
          Consumer<CallHistoryProvider>(
            builder: (context, provider, _) => IconButton(
              icon: Icon(
                provider.isMonitoring ? Icons.shield : Icons.shield_outlined,
                color: provider.isMonitoring
                    ? AppColors.success
                    : AppColors.textSecondaryDark,
              ),
              onPressed: () {
                if (provider.isMonitoring) {
                  provider.stopMonitoring();
                } else {
                  provider.startMonitoring();
                }
              },
              tooltip: provider.isMonitoring
                  ? 'Protection Active'
                  : 'Protection Off',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              context.read<CallHistoryProvider>().clearHistory();
            },
            tooltip: 'Clear History',
          ),
        ],
      ),
      body: Consumer<CallHistoryProvider>(
        builder: (context, provider, _) {
          if (provider.callHistory.isEmpty) {
            return _buildEmptyState();
          }
          return _buildCallList(provider.callHistory);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.phone_missed,
            size: 80,
            color: AppColors.textSecondaryDark.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No Call History',
            style: TextStyle(fontSize: 18, color: AppColors.textSecondaryDark),
          ),
          const SizedBox(height: 8),
          Text(
            'Analyzed calls will appear here',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondaryDark.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallList(List<CallRiskResult> calls) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: calls.length,
      itemBuilder: (context, index) {
        final call = calls[index];
        return _CallHistoryCard(call: call);
      },
    );
  }
}

class _CallHistoryCard extends StatelessWidget {
  final CallRiskResult call;

  const _CallHistoryCard({required this.call});

  @override
  Widget build(BuildContext context) {
    final riskColor = AppColors.getRiskColor(call.riskScore);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: riskColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Risk Score Circle
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.getRiskGradient(call.riskScore),
              ),
              child: Center(
                child: Text(
                  call.riskScore.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Call Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatPhoneNumber(call.phoneNumber),
                    style: const TextStyle(
                      color: AppColors.textPrimaryDark,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    RiskLevels.getLabel(call.riskLevel),
                    style: TextStyle(
                      color: riskColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    call.explanation,
                    style: TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Time
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatTime(call.analyzedAt),
                  style: TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Icon(
                  call.category == RiskCategory.scamCall
                      ? Icons.warning_amber_rounded
                      : Icons.info_outline,
                  color: riskColor,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatPhoneNumber(String number) {
    if (number.length >= 10) {
      return number.replaceAllMapped(
        RegExp(r'(\d{5})(\d+)'),
        (match) => '${match[1]} ${match[2]}',
      );
    }
    return number;
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

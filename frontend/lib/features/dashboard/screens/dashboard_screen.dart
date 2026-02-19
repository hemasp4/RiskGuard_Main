import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/constants/risk_levels.dart';
import '../../../core/services/permission_service.dart';
import '../../call_detection/screens/call_history_screen.dart';
import '../widgets/feature_card.dart';
import '../widgets/protection_status_card.dart';
import '../widgets/quick_action_button.dart';
import '../../risk_scoring/widgets/analysis_dashboard_view.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final hasAll = await PermissionService.hasAllPermissions();
    if (!hasAll) {
      _showPermissionDialog();
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text(
          'RiskGuard needs certain permissions to protect you from scam calls and messages. '
          'Please grant the required permissions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await PermissionService.requestAllPermissions();
              await PermissionService.requestOverlayPermission();
            },
            child: const Text('Grant Permissions'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _buildBody()),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomePage();
      case 1:
        return const CallHistoryScreen();
      case 2:
        return _buildAnalyzePage();
      case 3:
        return _buildSettingsPage();
      default:
        return _buildHomePage();
    }
  }

  Widget _buildHomePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader()
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: -0.2, end: 0),

          const SizedBox(height: 24),

          // Protection Status Card
          const ProtectionStatusCard()
              .animate()
              .fadeIn(duration: 400.ms, delay: 100.ms)
              .scale(begin: const Offset(0.95, 0.95)),

          const SizedBox(height: 24),

          // Quick Actions
          Text(
            'Quick Actions',
            style: AppTypography.headlineSmall.copyWith(
              color: AppColors.textPrimaryDark,
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

          const SizedBox(height: 16),

          _buildQuickActions().animate().fadeIn(
            duration: 400.ms,
            delay: 300.ms,
          ),

          const SizedBox(height: 24),

          // Feature Cards
          Text(
            'Protection Features',
            style: AppTypography.headlineSmall.copyWith(
              color: AppColors.textPrimaryDark,
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 400.ms),

          const SizedBox(height: 16),

          _buildFeatureCards().animate().fadeIn(
            duration: 400.ms,
            delay: 500.ms,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RiskGuard',
              style: AppTypography.displaySmall.copyWith(
                color: AppColors.textPrimaryDark,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'AI-Powered Digital Protection',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondaryDark,
              ),
            ),
          ],
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.notifications_outlined),
            color: AppColors.primary,
            onPressed: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: QuickActionButton(
                icon: Icons.analytics,
                label: 'Overall\nAnalysis',
                color: AppColors.primary,
                onTap: () => _navigateToOverallAnalysis(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: QuickActionButton(
                icon: Icons.message_outlined,
                label: 'Analyze\nMessage',
                color: AppColors.info,
                onTap: () => _navigateToMessageAnalysis(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: QuickActionButton(
                icon: Icons.mic_outlined,
                label: 'Voice\nAnalysis',
                color: AppColors.warning,
                onTap: () => _navigateToVoiceAnalysis(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: QuickActionButton(
                icon: Icons.videocam_outlined,
                label: 'Video\nCheck',
                color: AppColors.error,
                onTap: () => _navigateToVideoAnalysis(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureCards() {
    return Column(
      children: [
        FeatureCard(
          icon: Icons.phone_callback,
          title: 'Call Protection',
          description:
              'Real-time risk detection for incoming and outgoing calls',
          riskLevel: RiskLevel.low,
          isActive: true,
          onTap: () => setState(() => _selectedIndex = 1),
        ),
        const SizedBox(height: 12),
        FeatureCard(
          icon: Icons.sms_outlined,
          title: 'Message Scanner',
          description: 'Detect phishing and scam messages',
          riskLevel: RiskLevel.medium,
          isActive: true,
          onTap: () => _navigateToMessageAnalysis(),
        ),
        const SizedBox(height: 12),
        FeatureCard(
          icon: Icons.record_voice_over,
          title: 'Voice Authenticity',
          description: 'Detect AI-generated or synthetic voices',
          riskLevel: RiskLevel.unknown,
          isActive: false,
          onTap: () => _navigateToVoiceAnalysis(),
        ),
      ],
    );
  }

  Widget _buildAnalyzePage() {
    return const AnalysisDashboardView();
  }

  Widget _buildSettingsPage() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Settings',
          style: AppTypography.displaySmall.copyWith(
            color: AppColors.textPrimaryDark,
          ),
        ),
        const SizedBox(height: 24),

        // Contact Management Section
        Text(
          'Contacts & History',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.textPrimaryDark,
          ),
        ),
        const SizedBox(height: 12),
        _buildSettingsTile(
          icon: Icons.contacts,
          title: 'Contacts Management',
          subtitle: 'View and manage all saved contacts',
          onTap: () => Navigator.pushNamed(context, '/contacts-management'),
        ),
        _buildSettingsTile(
          icon: Icons.history,
          title: 'Call History',
          subtitle: 'View detailed call history and analytics',
          onTap: () => Navigator.pushNamed(context, '/call-history'),
        ),
        _buildSettingsTile(
          icon: Icons.verified_user,
          title: 'Whitelist',
          subtitle: 'Manage trusted contacts',
          onTap: () => Navigator.pushNamed(context, '/whitelist'),
        ),

        const SizedBox(height: 24),
        Text(
          'App Settings',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.textPrimaryDark,
          ),
        ),
        const SizedBox(height: 12),
        _buildSettingsTile(
          icon: Icons.shield_outlined,
          title: 'Protection Settings',
          subtitle: 'Configure call and message protection',
        ),
        _buildSettingsTile(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          subtitle: 'Manage alert preferences',
        ),
        _buildSettingsTile(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy',
          subtitle: 'Data handling and permissions',
        ),
        _buildSettingsTile(
          icon: Icons.info_outline,
          title: 'About',
          subtitle: 'Version 1.0.0',
        ),
      ],
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(
          title,
          style: const TextStyle(color: AppColors.textPrimaryDark),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: AppColors.textSecondaryDark),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppColors.textSecondaryDark,
        ),
        onTap: onTap ?? () {},
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondaryDark,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.call_outlined),
            activeIcon: Icon(Icons.call),
            label: 'Calls',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            activeIcon: Icon(Icons.analytics),
            label: 'Analyze',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  void _navigateToMessageAnalysis() {
    Navigator.pushNamed(context, '/message-analysis');
  }

  void _navigateToVoiceAnalysis() {
    Navigator.pushNamed(context, '/voice-analysis');
  }

  void _navigateToVideoAnalysis() {
    Navigator.pushNamed(context, '/video-analysis');
  }

  void _navigateToOverallAnalysis() {
    Navigator.pushNamed(context, '/overall-analysis');
  }
}

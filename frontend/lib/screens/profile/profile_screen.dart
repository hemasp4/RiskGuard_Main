import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:risk_guard/core/theme/app_colors.dart';
import 'package:risk_guard/core/theme/app_text_styles.dart';
import 'package:risk_guard/core/services/user_settings_provider.dart';
import 'package:risk_guard/core/services/scan_history_provider.dart';
import 'package:risk_guard/core/services/realtime_protection_provider.dart';
import 'package:risk_guard/core/services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<UserSettingsProvider>();

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Profile Header
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primaryGold,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryGold.withValues(
                                  alpha: 0.2,
                                ),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: AppColors.darkCard,
                            backgroundImage: const NetworkImage(
                              'https://i.pravatar.cc/150?img=11',
                            ),
                            onBackgroundImageError: (_, stack) {},
                            child: const Icon(
                              Icons.person,
                              size: 50,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () =>
                                _showEditProfileDialog(context, settings),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryPurple,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.darkBackground,
                                  width: 3,
                                ),
                              ),
                              child: const Icon(
                                Icons.edit,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      settings.displayName,
                      style: AppTextStyles.h3.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      settings.email,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppColors.goldGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'PRO MEMBER',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textOnGold,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn().slideY(begin: 0.1),

              const SizedBox(height: 40),

              // General Settings
              _buildSectionHeader('General'),
              const SizedBox(height: 16),
              _buildSettingsTile(
                icon: Icons.person_outline_rounded,
                title: 'Personal Info',
                subtitle: settings.displayName,
                onTap: () => _showEditProfileDialog(context, settings),
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 12),
              _buildSettingsTile(
                icon: Icons.shield_outlined,
                title: 'Security',
                subtitle: settings.biometricsEnabled
                    ? 'Biometrics On'
                    : 'Biometrics Off',
                onTap: () => _showSecuritySettingsDialog(context, settings),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 12),
              _buildSettingsTile(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: settings.notificationsEnabled
                    ? 'Enabled'
                    : 'Disabled',
                onTap: () {},
                trailing: Switch(
                  value: settings.notificationsEnabled,
                  onChanged: (v) => settings.setNotificationsEnabled(v),
                  activeThumbColor: AppColors.primaryGold,
                  activeTrackColor: AppColors.primaryGold.withValues(
                    alpha: 0.3,
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms),

              const SizedBox(height: 32),

              // Data & Storage
              _buildSectionHeader('Data & Storage'),
              const SizedBox(height: 16),
              _buildSettingsTile(
                icon: Icons.delete_sweep_outlined,
                title: 'Clear Scan History',
                subtitle:
                    '${context.watch<ScanHistoryProvider>().totalScans} scans stored',
                onTap: () => _showClearHistoryDialog(context),
              ).animate().fadeIn(delay: 350.ms),

              const SizedBox(height: 32),

              // Support
              _buildSectionHeader('Support'),
              const SizedBox(height: 16),
              _buildSettingsTile(
                icon: Icons.help_outline_rounded,
                title: 'Help Center',
                subtitle: 'FAQs and Support',
                onTap: () => _showHelpDialog(context),
              ).animate().fadeIn(delay: 400.ms),
              const SizedBox(height: 12),
              _buildSettingsTile(
                icon: Icons.info_outline_rounded,
                title: 'About RiskGuard',
                subtitle: 'v3.0.0 (Pro Edition)',
                onTap: () => _showAboutDialog(context),
              ).animate().fadeIn(delay: 500.ms),

              const SizedBox(height: 40),

              // Logout
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showLogoutDialog(context, settings),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Log Out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.dangerRed,
                    side: const BorderSide(color: AppColors.dangerRed),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 600.ms),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  // ── Dialogs ─────────────────────────────────────────────────────────────

  void _showEditProfileDialog(
    BuildContext context,
    UserSettingsProvider settings,
  ) {
    final nameController = TextEditingController(text: settings.displayName);
    final emailController = TextEditingController(text: settings.email);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Edit Profile',
                style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildTextField('Display Name', nameController, Icons.person),
              const SizedBox(height: 16),
              _buildTextField('Email', emailController, Icons.email),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    settings.setDisplayName(nameController.text.trim());
                    settings.setEmail(emailController.text.trim());
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Profile updated'),
                        backgroundColor: AppColors.successGreen,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGold,
                    foregroundColor: AppColors.darkBackground,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIcon: Icon(icon, color: AppColors.primaryGold, size: 20),
        filled: true,
        fillColor: AppColors.darkBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primaryGold),
        ),
      ),
    );
  }

  void _showSecuritySettingsDialog(
    BuildContext context,
    UserSettingsProvider settings,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Security Settings',
              style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _buildSwitchRow(
              'Biometric Authentication',
              Icons.fingerprint,
              settings.biometricsEnabled,
              (v) {
                settings.setBiometricsEnabled(v);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      v ? 'Biometrics enabled' : 'Biometrics disabled',
                    ),
                    backgroundColor: v
                        ? AppColors.successGreen
                        : AppColors.textSecondary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              },
            ),
            const Divider(color: AppColors.border, height: 32),
            _buildSwitchRow(
              'Real-time Protection',
              Icons.shield_rounded,
              context.read<RealtimeProtectionProvider>().isActive,
              (v) {
                context.read<RealtimeProtectionProvider>().toggleProtection();
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow(
    String label,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryGold, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.primaryGold,
          activeTrackColor: AppColors.primaryGold.withValues(alpha: 0.3),
        ),
      ],
    );
  }

  void _showClearHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Clear History?',
          style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'All scan history will be permanently deleted. This cannot be undone.',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              context.read<ScanHistoryProvider>().clearHistory();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Scan history cleared'),
                  backgroundColor: AppColors.primaryGold,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            child: const Text(
              'Clear',
              style: TextStyle(
                color: AppColors.dangerRed,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Help Center',
              style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildHelpItem(
              Icons.mic_rounded,
              'Voice Analysis',
              'Record audio to detect AI-generated voices',
            ),
            _buildHelpItem(
              Icons.image_rounded,
              'Image Detection',
              'Upload images to check for AI manipulation',
            ),
            _buildHelpItem(
              Icons.message_rounded,
              'Text Analysis',
              'Verify messages for scam patterns',
            ),
            _buildHelpItem(
              Icons.shield_rounded,
              'Real-time Protection',
              'Enable the master toggle for live monitoring',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.darkBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.email_rounded,
                    color: AppColors.primaryGold,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'support@riskguard.io',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primaryGold, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  desc,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.shield_rounded,
                color: Colors.black,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'RiskGuard',
              style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              'v3.0.0 Pro Edition',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.darkBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildAboutRow('Backend', 'FastAPI v3.0.0'),
                  _buildAboutRow('AI Models', 'HuggingFace Transformers'),
                  _buildAboutRow('Storage', 'Hive (local)'),
                  _buildAboutRow('Platform', 'Android + Web'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FutureBuilder<bool>(
              future: _checkBackendHealth(),
              builder: (context, snapshot) {
                final isHealthy = snapshot.data ?? false;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (isHealthy
                                ? AppColors.successGreen
                                : AppColors.dangerRed)
                            .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          (isHealthy
                                  ? AppColors.successGreen
                                  : AppColors.dangerRed)
                              .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isHealthy
                              ? AppColors.successGreen
                              : AppColors.dangerRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isHealthy
                            ? 'Backend Connected'
                            : 'Backend Not Available',
                        style: TextStyle(
                          color: isHealthy
                              ? AppColors.successGreen
                              : AppColors.dangerRed,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _checkBackendHealth() async {
    try {
      return await ApiService().isBackendHealthy();
    } catch (_) {
      return false;
    }
  }

  void _showLogoutDialog(BuildContext context, UserSettingsProvider settings) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Log Out?',
          style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Your local settings and scan history will be cleared.',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              await settings.clearAll();
              if (context.mounted) {
                context.read<ScanHistoryProvider>().clearHistory();
                context.read<RealtimeProtectionProvider>().toggleProtection();
              }
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Logged out. Settings cleared.'),
                    backgroundColor: AppColors.primaryGold,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }
            },
            child: const Text(
              'Log Out',
              style: TextStyle(
                color: AppColors.dangerRed,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Reusable Widgets ──────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textSecondary,
          letterSpacing: 1.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: AppColors.darkBackground,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primaryGold, size: 24),
        ),
        title: Text(
          title,
          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          subtitle,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        trailing:
            trailing ??
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
            ),
      ),
    );
  }
}

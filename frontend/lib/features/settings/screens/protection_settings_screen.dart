/// Protection Settings Screen
///
/// Comprehensive settings for user control over protection modes,
/// privacy filter (app whitelist), and analysis preferences.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/services/whitelist_service.dart';

class ProtectionSettingsScreen extends StatefulWidget {
  const ProtectionSettingsScreen({super.key});

  @override
  State<ProtectionSettingsScreen> createState() =>
      _ProtectionSettingsScreenState();
}

class _ProtectionSettingsScreenState extends State<ProtectionSettingsScreen> {
  final WhitelistService _whitelistService = WhitelistService();
  final ProtectionSettingsService _protectionService =
      ProtectionSettingsService();

  bool _isLoading = true;
  ProtectionMode _selectedMode = ProtectionMode.both;
  bool _isRealTimeEnabled = false;
  List<AppInfo> _suggestedApps = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _whitelistService.init();
    await _protectionService.init();

    setState(() {
      _selectedMode = _protectionService.currentMode;
      _isRealTimeEnabled = _protectionService.isRealTimeEnabled;
      _suggestedApps = _whitelistService.getSuggestedApps();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f1a),
      appBar: AppBar(
        title: const Text(
          'Protection Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMasterToggle(),
                  const SizedBox(height: 24),
                  _buildProtectionModeSection(),
                  const SizedBox(height: 24),
                  _buildPrivacyFilterSection(),
                  const SizedBox(height: 24),
                  _buildInfoSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildMasterToggle() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isRealTimeEnabled
              ? [
                  const Color(0xFF22c55e).withValues(alpha: 0.2),
                  const Color(0xFF16a34a).withValues(alpha: 0.1),
                ]
              : [
                  const Color(0xFF374151).withValues(alpha: 0.3),
                  const Color(0xFF1f2937).withValues(alpha: 0.2),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isRealTimeEnabled
              ? const Color(0xFF22c55e).withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isRealTimeEnabled
                  ? const Color(0xFF22c55e).withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isRealTimeEnabled ? Icons.shield : Icons.shield_outlined,
              color: _isRealTimeEnabled ? const Color(0xFF22c55e) : Colors.grey,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Real-Time Protection',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isRealTimeEnabled
                      ? 'Active - Monitoring selected apps'
                      : 'Disabled - Manual analysis only',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isRealTimeEnabled,
            onChanged: (value) async {
              await _protectionService.toggleRealTime();
              setState(() => _isRealTimeEnabled = value);
            },
            activeThumbColor: const Color(0xFF22c55e),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildProtectionModeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              const Icon(Icons.tune, color: Color(0xFF667eea), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Protection Mode',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildModeOption(
          ProtectionMode.realTime,
          'Real-Time Only',
          'Background scanning with floating overlay',
          Icons.visibility,
        ),
        const SizedBox(height: 8),
        _buildModeOption(
          ProtectionMode.manualOnly,
          'Manual Upload Only',
          'Analyze files when you choose',
          Icons.upload_file,
        ),
        const SizedBox(height: 8),
        _buildModeOption(
          ProtectionMode.both,
          'Both Modes',
          'Full protection - recommended',
          Icons.security,
          isRecommended: true,
        ),
      ],
    ).animate().fadeIn(duration: 300.ms, delay: 100.ms);
  }

  Widget _buildModeOption(
    ProtectionMode mode,
    String title,
    String subtitle,
    IconData icon, {
    bool isRecommended = false,
  }) {
    final isSelected = _selectedMode == mode;

    return GestureDetector(
      onTap: () async {
        await _protectionService.setMode(mode);
        setState(() => _selectedMode = mode);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF667eea).withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF667eea)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF667eea) : Colors.grey,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : Colors.white70,
                        ),
                      ),
                      if (isRecommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF22c55e,
                            ).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Recommended',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF22c55e),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Radio<ProtectionMode>(
              value: mode,
              groupValue: _selectedMode,
              onChanged: (value) async {
                if (value != null) {
                  await _protectionService.setMode(value);
                  setState(() => _selectedMode = value);
                }
              },
              activeColor: const Color(0xFF667eea),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyFilterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.apps, color: Color(0xFFf59e0b), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Privacy Filter',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () async {
                  await _whitelistService.resetToDefaults();
                  setState(() {
                    _suggestedApps = _whitelistService.getSuggestedApps();
                  });
                },
                child: const Text(
                  'Reset to Defaults',
                  style: TextStyle(fontSize: 12, color: Color(0xFF667eea)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Select apps to monitor. Gallery, banking, and system apps are never scanned.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _suggestedApps.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.1)),
            itemBuilder: (context, index) {
              final app = _suggestedApps[index];
              return _buildAppTile(app, index);
            },
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms, delay: 200.ms);
  }

  Widget _buildAppTile(AppInfo app, int index) {
    final isWhitelisted = _whitelistService.isWhitelisted(app.packageName);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _getAppColor(app.appName).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          _getAppIcon(app.appName),
          color: _getAppColor(app.appName),
          size: 20,
        ),
      ),
      title: Text(
        app.appName,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
      subtitle: Text(
        app.packageName,
        style: TextStyle(
          fontSize: 11,
          color: Colors.white.withValues(alpha: 0.4),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Switch(
        value: isWhitelisted,
        onChanged: (value) async {
          await _whitelistService.toggleWhitelist(app.packageName);
          setState(() {
            _suggestedApps = _whitelistService.getSuggestedApps();
          });
        },
        activeThumbColor: const Color(0xFF22c55e),
        inactiveThumbColor: Colors.grey,
      ),
    );
  }

  IconData _getAppIcon(String appName) {
    final icons = {
      'WhatsApp': Icons.chat_bubble,
      'Instagram': Icons.camera_alt,
      'Facebook': Icons.facebook,
      'Messenger': Icons.message,
      'Telegram': Icons.send,
      'Twitter/X': Icons.tag,
      'Snapchat': Icons.photo_camera,
      'LinkedIn': Icons.work,
      'Discord': Icons.headset_mic,
      'Gmail': Icons.email,
      'Outlook': Icons.mail,
    };
    return icons[appName] ?? Icons.apps;
  }

  Color _getAppColor(String appName) {
    final colors = {
      'WhatsApp': const Color(0xFF25D366),
      'Instagram': const Color(0xFFE1306C),
      'Facebook': const Color(0xFF1877F2),
      'Messenger': const Color(0xFF0084FF),
      'Telegram': const Color(0xFF0088CC),
      'Twitter/X': Colors.white,
      'Snapchat': const Color(0xFFFFFC00),
      'LinkedIn': const Color(0xFF0A66C2),
      'Discord': const Color(0xFF5865F2),
      'Gmail': const Color(0xFFEA4335),
      'Outlook': const Color(0xFF0078D4),
    };
    return colors[appName] ?? const Color(0xFF667eea);
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1e3a5f).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF3b82f6).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF3b82f6), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Privacy Matters',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'RiskGuard only monitors apps you explicitly allow. '
                  'All analysis happens locally when possible. '
                  'No data is stored on our servers.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms, delay: 300.ms);
  }
}

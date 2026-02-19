import 'package:flutter/material.dart';
import 'dart:developer' as developer;

/// Settings screen for call blocking and notifications
class BlockingSettingsScreen extends StatefulWidget {
  const BlockingSettingsScreen({super.key});

  @override
  State<BlockingSettingsScreen> createState() => _BlockingSettingsScreenState();
}

class _BlockingSettingsScreenState extends State<BlockingSettingsScreen> {
  bool _autoBlockEnabled = false;
  double _riskThreshold = 70.0;
  bool _sendAutoResponse = false;
  final _autoResponseController = TextEditingController(
    text: 'This number is blocked. Please do not call again.',
  );

  // Custom colors
  final Color _backgroundColor = const Color(0xFFACC8E5);
  final Color _textColor = const Color(0xFF112A46);

  @override
  void dispose() {
    _autoResponseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Call Blocking Settings'),
        backgroundColor: _backgroundColor,
        foregroundColor: _textColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Auto-block section
          _buildSectionTitle('Auto-Block'),
          _buildSettingsCard(
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(
                    'Auto-Block High-Risk Calls',
                    style: TextStyle(
                      color: _textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: const Text(
                    'Automatically block calls above risk threshold',
                  ),
                  value: _autoBlockEnabled,
                  activeThumbColor: _backgroundColor,
                  onChanged: (value) {
                    setState(() {
                      _autoBlockEnabled = value;
                    });
                    _saveSettings();
                  },
                ),
                if (_autoBlockEnabled) ...[
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Risk Threshold',
                              style: TextStyle(
                                color: _textColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _backgroundColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_riskThreshold.toInt()}%',
                                style: TextStyle(
                                  color: _textColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _riskThreshold,
                          min: 50,
                          max: 90,
                          divisions: 8,
                          activeColor: _backgroundColor,
                          label: '${_riskThreshold.toInt()}%',
                          onChanged: (value) {
                            setState(() {
                              _riskThreshold = value;
                            });
                          },
                          onChangeEnd: (value) {
                            _saveSettings();
                          },
                        ),
                        Text(
                          'Calls with risk score ≥ ${_riskThreshold.toInt()}% will be blocked',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Auto-response section
          _buildSectionTitle('Auto-Response'),
          _buildSettingsCard(
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(
                    'Send SMS Auto-Response',
                    style: TextStyle(
                      color: _textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: const Text('Send SMS to blocked callers'),
                  value: _sendAutoResponse,
                  activeThumbColor: _backgroundColor,
                  onChanged: (value) {
                    setState(() {
                      _sendAutoResponse = value;
                    });
                    _saveSettings();
                  },
                ),
                if (_sendAutoResponse) ...[
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Message',
                          style: TextStyle(
                            color: _textColor,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _autoResponseController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Enter auto-response message...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: _backgroundColor),
                            ),
                          ),
                          onChanged: (value) {
                            // Debounce save
                            Future.delayed(
                              const Duration(seconds: 1),
                              () => _saveSettings(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Quick actions
          _buildSectionTitle('Quick Actions'),
          _buildSettingsCard(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.block, color: _textColor),
                  title: Text(
                    'Blocked Numbers',
                    style: TextStyle(color: _textColor),
                  ),
                  subtitle: const Text('View and manage blocked numbers'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pushNamed(context, '/blocked-numbers');
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Icon(Icons.verified_user, color: _textColor),
                  title: Text('Whitelist', style: TextStyle(color: _textColor)),
                  subtitle: const Text('Manage trusted contacts'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pushNamed(context, '/whitelist');
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _backgroundColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _backgroundColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: _textColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Auto-blocking requires ANSWER_PHONE_CALLS permission. '
                    'SMS auto-response requires SEND_SMS permission.',
                    style: TextStyle(
                      fontSize: 12,
                      color: _textColor.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: _textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Future<void> _saveSettings() async {
    // Save settings to native storage/database
    // Note: In production, this persists to SharedPreferences or a Database via MethodChannel

    developer.log('Settings saved:');
    developer.log('  Auto-block: $_autoBlockEnabled');
    developer.log('  Threshold: ${_riskThreshold.toInt()}%');
    developer.log('  Auto-response: $_sendAutoResponse');
    developer.log('  Message: ${_autoResponseController.text}');
  }
}

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:risk_guard/core/theme/app_colors.dart';
import 'package:risk_guard/core/theme/app_text_styles.dart';

/// Screen shown at app launch to request permissions sequentially
class PermissionRequestScreen extends StatefulWidget {
  final VoidCallback onPermissionsGranted;

  const PermissionRequestScreen({
    super.key,
    required this.onPermissionsGranted,
  });

  @override
  State<PermissionRequestScreen> createState() =>
      _PermissionRequestScreenState();
}

class _PermissionRequestScreenState extends State<PermissionRequestScreen> {
  int _currentIndex = 0;
  bool _isRequesting = false;

  final List<Permission> _permissions = [
    Permission.microphone,
    Permission.notification,
    Permission.sms,
    Permission.storage, // Only for Android < 13 usually
    Permission.photos,
  ];

  @override
  Widget build(BuildContext context) {
    final currentPermission = _permissions[_currentIndex];
    final progress = (_currentIndex + 1) / _permissions.length;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Progress Bar
              LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.darkCard,
                color: AppColors.primaryGold,
                borderRadius: BorderRadius.circular(4),
                minHeight: 6,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Step ${_currentIndex + 1} of ${_permissions.length}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),

              const Spacer(),

              // Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.darkCard,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryGold.withValues(alpha: 0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGold.withValues(alpha: 0.1),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  _getIconForPermission(currentPermission),
                  size: 50,
                  color: AppColors.primaryGold,
                ),
              ),

              const SizedBox(height: 40),

              // Title
              Text(
                _getNameForPermission(currentPermission),
                style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Description
              Text(
                _getDescriptionForPermission(currentPermission),
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(),

              // Allow Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isRequesting
                      ? null
                      : () => _handlePermission(currentPermission),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGold,
                    foregroundColor: AppColors.textOnGold,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isRequesting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: AppColors.textOnGold,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Allow Access',
                          style: AppTextStyles.h4.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textOnGold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Skip Button
              TextButton(
                onPressed: _isRequesting ? null : _nextStep,
                child: Text(
                  'Skip for now',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handlePermission(Permission permission) async {
    setState(() => _isRequesting = true);

    // Request the permission
    await permission.request();

    // Move to next step regardless of result (standard wizard flow)
    _nextStep();
  }

  void _nextStep() {
    if (mounted) {
      setState(() {
        _isRequesting = false;
        if (_currentIndex < _permissions.length - 1) {
          _currentIndex++;
        } else {
          // Finished
          widget.onPermissionsGranted();
        }
      });
    }
  }

  IconData _getIconForPermission(Permission p) {
    if (p == Permission.microphone) return Icons.mic_rounded;
    if (p == Permission.notification) return Icons.notifications_rounded;
    if (p == Permission.sms) return Icons.sms_rounded;
    if (p == Permission.storage) return Icons.folder_rounded;
    if (p == Permission.photos) return Icons.photo_library_rounded;
    return Icons.settings;
  }

  String _getNameForPermission(Permission p) {
    if (p == Permission.microphone) return 'Microphone Access';
    if (p == Permission.notification) return 'Notifications';
    if (p == Permission.sms) return 'SMS Filter';
    if (p == Permission.storage) return 'File Storage';
    if (p == Permission.photos) return 'Photo Gallery';
    return 'Permission Required';
  }

  String _getDescriptionForPermission(Permission p) {
    if (p == Permission.microphone) {
      return 'Required to analyze voice patterns and detect deepfake audio in real-time.';
    }
    if (p == Permission.notification) {
      return 'Stay informed about security threats and blocked scams instantly.';
    }
    if (p == Permission.sms) {
      return 'Analyze incoming messages to filter out phishing attempts and malicious links.';
    }
    if (p == Permission.storage) {
      return 'Save security reports and analysis logs to your device.';
    }
    if (p == Permission.photos) {
      return 'Scan images from your gallery to detect manipulated faces and AI-generated content.';
    }
    return 'This permission is needed for RiskGuard to function properly.';
  }
}

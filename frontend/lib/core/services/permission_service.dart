import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Check if all required permissions are granted
  static Future<bool> hasAllPermissions() async {
    final phoneStatus = await Permission.phone.status;
    final callLogStatus = await Permission.phone.status;

    return phoneStatus.isGranted && callLogStatus.isGranted;
  }

  /// Request phone-related permissions
  static Future<bool> requestPhonePermissions() async {
    final statuses = await [Permission.phone].request();

    return statuses[Permission.phone]?.isGranted ?? false;
  }

  /// Request call log permission
  static Future<bool> requestCallLogPermission() async {
    final status = await Permission.phone.request();
    return status.isGranted;
  }

  /// Request microphone permission for voice analysis
  static Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Request storage permission for video analysis
  static Future<bool> requestStoragePermission() async {
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  /// Request notification permission (Android 13+)
  static Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Check if overlay permission is granted
  static Future<bool> hasOverlayPermission() async {
    return await Permission.systemAlertWindow.isGranted;
  }

  /// Request overlay permission (opens settings)
  static Future<bool> requestOverlayPermission() async {
    final status = await Permission.systemAlertWindow.request();
    return status.isGranted;
  }

  /// Open app settings for manual permission granting
  static Future<bool> openSettings() async {
    return await openAppSettings();
  }

  /// Get list of all required permissions with their status
  static Future<Map<Permission, PermissionStatus>>
  getAllPermissionStatuses() async {
    return {
      Permission.phone: await Permission.phone.status,
      Permission.microphone: await Permission.microphone.status,
      Permission.notification: await Permission.notification.status,
      Permission.systemAlertWindow: await Permission.systemAlertWindow.status,
    };
  }

  /// Request all required permissions
  static Future<Map<Permission, PermissionStatus>>
  requestAllPermissions() async {
    return await [
      Permission.phone,
      Permission.microphone,
      Permission.notification,
    ].request();
  }

  /// Show permission rationale dialog
  static Future<bool> showPermissionRationale(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onAccept,
  }) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not Now'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, true);
                  onAccept();
                },
                child: const Text('Allow'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

/// Permission descriptions for UI - using String keys to avoid const map issues
class PermissionDescriptions {
  static String getTitle(Permission permission) {
    if (permission == Permission.phone) return 'Phone Access';
    if (permission == Permission.microphone) return 'Microphone Access';
    if (permission == Permission.notification) return 'Notifications';
    if (permission == Permission.systemAlertWindow) return 'Display Over Apps';
    return 'Permission';
  }

  static String getDescription(Permission permission) {
    if (permission == Permission.phone) {
      return 'Required to detect incoming calls and show risk alerts';
    }
    if (permission == Permission.microphone) {
      return 'Required for voice analysis to detect AI-generated voices';
    }
    if (permission == Permission.notification) {
      return 'Required to show protection status notifications';
    }
    if (permission == Permission.systemAlertWindow) {
      return 'Required to display risk alerts during calls';
    }
    return 'Required for app functionality';
  }

  static IconData getIcon(Permission permission) {
    if (permission == Permission.phone) return Icons.phone;
    if (permission == Permission.microphone) return Icons.mic;
    if (permission == Permission.notification) return Icons.notifications;
    if (permission == Permission.systemAlertWindow) return Icons.layers;
    return Icons.security;
  }
}

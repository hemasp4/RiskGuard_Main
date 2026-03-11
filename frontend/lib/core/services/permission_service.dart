import 'package:permission_handler/permission_handler.dart';

/// Service to handle all app permissions
class PermissionService {
  /// Request all necessary permissions at app launch
  static Future<Map<Permission, PermissionStatus>>
  requestAllPermissions() async {
    final Map<Permission, PermissionStatus> statuses = {};

    // Define all permissions needed by the app
    final List<Permission> permissions = [
      Permission.microphone, // For voice scan feature
      Permission.notification, // For security alerts
      Permission.sms, // For SMS checking feature
      Permission.storage, // For image recognition
      Permission.photos, // For deepfake analysis
    ];

    // Request all permissions
    for (final permission in permissions) {
      final status = await permission.request();
      statuses[permission] = status;
    }

    return statuses;
  }

  /// Check if a specific permission is granted
  static Future<bool> isPermissionGranted(Permission permission) async {
    return await permission.isGranted;
  }

  /// Check if all critical permissions are granted
  static Future<bool> areAllCriticalPermissionsGranted() async {
    final microphone = await Permission.microphone.isGranted;
    final notification = await Permission.notification.isGranted;
    final sms = await Permission.sms.isGranted;

    return microphone && notification && sms;
  }

  /// Open app settings if permission is permanently denied
  static Future<bool> openAppSettings() async {
    return await openAppSettings();
  }

  /// Request individual permission with explanation
  static Future<PermissionStatus> requestPermission(
    Permission permission,
  ) async {
    final status = await permission.status;

    if (status.isDenied) {
      return await permission.request();
    }

    return status;
  }

  /// Get user-friendly permission name
  static String getPermissionName(Permission permission) {
    if (permission == Permission.microphone) return 'Microphone';
    if (permission == Permission.notification) return 'Notifications';
    if (permission == Permission.sms) return 'SMS';
    if (permission == Permission.storage) return 'Storage';
    if (permission == Permission.photos) return 'Photos';
    return 'Unknown';
  }

  /// Get permission description
  static String getPermissionDescription(Permission permission) {
    if (permission == Permission.microphone) {
      return 'Required for voice scan and scam detection';
    }
    if (permission == Permission.notification) {
      return 'Get alerts about security threats';
    }
    if (permission == Permission.sms) {
      return 'Scan messages for phishing attempts';
    }
    if (permission == Permission.storage) {
      return 'Access images for deepfake detection';
    }
    if (permission == Permission.photos) {
      return 'Analyze images for manipulation';
    }
    return 'Required for app functionality';
  }

  /// Get icon for permission
  static String getPermissionIcon(Permission permission) {
    if (permission == Permission.microphone) return '🎤';
    if (permission == Permission.notification) return '🔔';
    if (permission == Permission.sms) return '💬';
    if (permission == Permission.storage) return '📁';
    if (permission == Permission.photos) return '📷';
    return '🔒';
  }
}

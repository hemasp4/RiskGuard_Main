import 'dart:developer' as developer;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import '../constants/app_constants.dart';

/// Callback types for native events
typedef CallStateCallback = void Function(String phoneNumber, bool isIncoming);
typedef CallEndedCallback = void Function();
typedef RecordingStartedCallback = void Function(String filePath);
typedef RecordingStoppedCallback = void Function(String filePath);
typedef ContactSavedCallback =
    void Function(
      String phoneNumber,
      String name,
      String? email,
      String? category,
    );
typedef ContactUpdatedCallback =
    void Function(
      String phoneNumber,
      String name,
      String? email,
      String? category,
    );

class MethodChannelService {
  static const MethodChannel _channel = MethodChannel(
    AppConstants.methodChannelName,
  );

  // Singleton instance
  static final MethodChannelService _instance =
      MethodChannelService._internal();
  factory MethodChannelService() => _instance;
  MethodChannelService._internal();

  // Callbacks
  CallStateCallback? _onCallStateChanged;
  CallEndedCallback? _onCallEnded;
  RecordingStartedCallback? _onRecordingStarted;
  RecordingStoppedCallback? _onRecordingStopped;
  ContactSavedCallback? _onContactSaved;
  ContactUpdatedCallback? _onContactUpdated;

  /// Whether the platform supports method channels (not web)
  bool get _isSupported => !kIsWeb;

  /// Initialize method channel and set up listeners
  void initialize({
    required CallStateCallback onCallStateChanged,
    required CallEndedCallback onCallEnded,
    RecordingStartedCallback? onRecordingStarted,
    RecordingStoppedCallback? onRecordingStopped,
    ContactSavedCallback? onContactSaved,
    ContactUpdatedCallback? onContactUpdated,
  }) {
    _onCallStateChanged = onCallStateChanged;
    _onCallEnded = onCallEnded;
    _onRecordingStarted = onRecordingStarted;
    _onRecordingStopped = onRecordingStopped;
    _onContactSaved = onContactSaved;
    _onContactUpdated = onContactUpdated;

    if (_isSupported) {
      _channel.setMethodCallHandler(_handleMethodCall);
    } else {
      _log('Method channels not supported on web platform');
    }
  }

  /// Handle incoming method calls from native
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onCallStateChanged':
        final args = call.arguments as Map<dynamic, dynamic>;
        final phoneNumber = args['phoneNumber'] as String? ?? '';
        final isIncoming = args['isIncoming'] as bool? ?? true;
        _onCallStateChanged?.call(phoneNumber, isIncoming);
        break;
      case 'onCallEnded':
        _onCallEnded?.call();
        break;
      case 'onRecordingStarted':
        final args = call.arguments as Map<dynamic, dynamic>;
        final filePath = args['filePath'] as String? ?? '';
        _onRecordingStarted?.call(filePath);
        break;
      case 'onRecordingStopped':
        final args = call.arguments as Map<dynamic, dynamic>;
        final filePath = args['filePath'] as String? ?? '';
        _onRecordingStopped?.call(filePath);
        break;
      case 'onContactSaved':
        final args = call.arguments as Map<dynamic, dynamic>;
        final phoneNumber = args['phoneNumber'] as String? ?? '';
        final name = args['name'] as String? ?? '';
        final email = args['email'] as String?;
        final category = args['category'] as String?;
        _onContactSaved?.call(phoneNumber, name, email, category);
        break;
      case 'onContactUpdated':
        final args = call.arguments as Map<dynamic, dynamic>;
        final phoneNumber = args['phoneNumber'] as String? ?? '';
        final name = args['name'] as String? ?? '';
        final email = args['email'] as String?;
        final category = args['category'] as String?;
        _onContactUpdated?.call(phoneNumber, name, email, category);
        break;
      default:
        throw MissingPluginException('Method ${call.method} not implemented');
    }
  }

  /// Helper to safely invoke method channel methods
  /// Returns null/false on web or when plugin is missing
  Future<T?> _safeInvoke<T>(String method, [Map<String, dynamic>? args]) async {
    if (!_isSupported) {
      _log('$method not available on web platform');
      return null;
    }
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      _log('$method not implemented on this platform');
      return null;
    } on PlatformException catch (e) {
      _log('$method failed: ${e.message}');
      return null;
    }
  }

  /// Start the call monitoring service
  Future<bool> startCallMonitoringService() async {
    final result = await _safeInvoke<bool>('startCallMonitoring');
    return result ?? false;
  }

  /// Stop the call monitoring service
  Future<bool> stopCallMonitoringService() async {
    final result = await _safeInvoke<bool>('stopCallMonitoring');
    return result ?? false;
  }

  /// Show risk overlay during call
  Future<bool> showRiskOverlay({
    required int riskScore,
    required String riskLevel,
    required String explanation,
    required String phoneNumber,
  }) async {
    final result = await _safeInvoke<bool>('showRiskOverlay', {
      'riskScore': riskScore,
      'riskLevel': riskLevel,
      'explanation': explanation,
      'phoneNumber': phoneNumber,
    });
    return result ?? false;
  }

  /// Update AI analysis result in overlay
  Future<bool> updateAIResult({
    required double probability,
    required bool isSynthetic,
  }) async {
    final result = await _safeInvoke<bool>('updateAIResult', {
      'probability': probability,
      'isSynthetic': isSynthetic,
    });
    return result ?? false;
  }

  /// Hide risk overlay
  Future<bool> hideRiskOverlay() async {
    final result = await _safeInvoke<bool>('hideRiskOverlay');
    return result ?? false;
  }

  /// Get current recording path
  Future<String?> getCurrentRecordingPath() async {
    return await _safeInvoke<String>('getCurrentRecordingPath');
  }

  /// Check if overlay permission is granted
  Future<bool> checkOverlayPermission() async {
    final result = await _safeInvoke<bool>('checkOverlayPermission');
    return result ?? false;
  }

  /// Request overlay permission
  Future<void> requestOverlayPermission() async {
    await _safeInvoke('requestOverlayPermission');
  }

  /// Get call history from native
  Future<List<Map<String, dynamic>>> getRecentCalls({int limit = 20}) async {
    if (!_isSupported) return [];
    try {
      final result = await _channel.invokeMethod<List>('getRecentCalls', {
        'limit': limit,
      });
      return result?.cast<Map<String, dynamic>>() ?? [];
    } on MissingPluginException {
      _log('getRecentCalls not available on this platform');
      return [];
    } on PlatformException catch (e) {
      _log('Failed to get recent calls: ${e.message}');
      return [];
    }
  }

  /// Analyze phone number for risk
  Future<Map<String, dynamic>> analyzePhoneNumber(String phoneNumber) async {
    if (!_isSupported) return {};
    try {
      final result = await _channel.invokeMethod<Map>('analyzePhoneNumber', {
        'phoneNumber': phoneNumber,
      });
      return Map<String, dynamic>.from(result ?? {});
    } on MissingPluginException {
      _log('analyzePhoneNumber not available on this platform');
      return {};
    } on PlatformException catch (e) {
      _log('Failed to analyze phone number: ${e.message}');
      return {};
    }
  }

  /// Check if protection is enabled (from saved state)
  Future<bool> isProtectionEnabled() async {
    final result = await _safeInvoke<bool>('isProtectionEnabled');
    return result ?? false;
  }

  /// Check if battery optimization is enabled
  Future<bool> checkBatteryOptimization() async {
    final result = await _safeInvoke<bool>('checkBatteryOptimization');
    return result ?? false;
  }

  /// Request battery optimization exemption
  Future<void> requestBatteryOptimizationExemption() async {
    await _safeInvoke('requestBatteryOptimizationExemption');
  }

  /// Get saved contacts from native database
  Future<List<Map<String, dynamic>>> getSavedContacts() async {
    if (!_isSupported) return [];
    try {
      final List<dynamic>? contacts = await _channel.invokeMethod(
        'getSavedContacts',
      );
      if (contacts == null) return [];
      return contacts.map((c) => Map<String, dynamic>.from(c as Map)).toList();
    } on MissingPluginException {
      _log('getSavedContacts not available on this platform');
      return [];
    } catch (e) {
      _log('Error getting saved contacts: $e');
      return [];
    }
  }

  /// Get protection statistics for dashboard
  Future<Map<String, int>> getProtectionStatistics() async {
    final defaultStats = {
      'threatsBlockedToday': 0,
      'threatsBlockedThisWeek': 0,
      'highRiskCallsCount': 0,
      'totalCallsCount': 0,
    };
    if (!_isSupported) return defaultStats;
    try {
      final Map<dynamic, dynamic>? stats = await _channel.invokeMethod(
        'getProtectionStats',
      );
      if (stats == null) return defaultStats;
      return {
        'threatsBlockedToday': stats['threatsBlockedToday'] as int? ?? 0,
        'threatsBlockedThisWeek': stats['threatsBlockedThisWeek'] as int? ?? 0,
        'highRiskCallsCount': stats['highRiskCallsCount'] as int? ?? 0,
        'totalCallsCount': stats['totalCallsCount'] as int? ?? 0,
      };
    } on MissingPluginException {
      _log('getProtectionStats not available on this platform');
      return defaultStats;
    } catch (e) {
      _log('Error getting protection statistics: $e');
      return defaultStats;
    }
  }

  /// Clear all recent calls from native history
  Future<bool> clearRecentCalls() async {
    final result = await _safeInvoke<bool>('clearRecentCalls');
    return result ?? false;
  }

  void _log(String message) {
    developer.log('[MethodChannelService] $message');
  }
}

/// Whitelist Service - Privacy Filter for App Whitelisting
///
/// Manages which apps are allowed for real-time scanning.
/// Users control exactly which apps RiskGuard monitors.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Information about an installed app
class AppInfo {
  final String packageName;
  final String appName;
  final bool isSystemApp;
  final bool isWhitelisted;

  const AppInfo({
    required this.packageName,
    required this.appName,
    this.isSystemApp = false,
    this.isWhitelisted = false,
  });

  AppInfo copyWith({bool? isWhitelisted}) {
    return AppInfo(
      packageName: packageName,
      appName: appName,
      isSystemApp: isSystemApp,
      isWhitelisted: isWhitelisted ?? this.isWhitelisted,
    );
  }

  Map<String, dynamic> toJson() => {
    'packageName': packageName,
    'appName': appName,
    'isSystemApp': isSystemApp,
    'isWhitelisted': isWhitelisted,
  };

  factory AppInfo.fromJson(Map<String, dynamic> json) {
    return AppInfo(
      packageName: json['packageName'] as String,
      appName: json['appName'] as String,
      isSystemApp: json['isSystemApp'] as bool? ?? false,
      isWhitelisted: json['isWhitelisted'] as bool? ?? false,
    );
  }
}

/// Service for managing app whitelist (Privacy Filter)
class WhitelistService {
  static const String _whitelistKey = 'riskguard_app_whitelist';
  // Protection mode key for future use
  // static const String _protectionModeKey = 'riskguard_protection_mode';

  // Singleton
  static final WhitelistService _instance = WhitelistService._internal();
  factory WhitelistService() => _instance;
  WhitelistService._internal();

  SharedPreferences? _prefs;
  Set<String> _whitelistedApps = {};

  // Default high-risk apps (social media, messaging)
  static const List<String> defaultHighRiskApps = [
    'com.whatsapp',
    'com.instagram.android',
    'com.facebook.katana',
    'com.facebook.orca', // Messenger
    'org.telegram.messenger',
    'com.twitter.android',
    'com.snapchat.android',
    'com.linkedin.android',
    'com.tencent.mm', // WeChat
    'jp.naver.line.android', // LINE
    'com.viber.voip',
    'com.discord',
    'com.skype.raider',
    'com.google.android.gm', // Gmail
    'com.microsoft.office.outlook',
    'com.yahoo.mobile.client.android.mail',
  ];

  // Apps that should NEVER be scanned (privacy sensitive)
  static const List<String> neverScanApps = [
    'com.google.android.apps.photos', // Gallery
    'com.android.gallery3d',
    'com.samsung.android.gallery',
    'com.google.android.apps.nbu.files', // Files
    'com.android.documentsui',
    'com.google.android.gms', // Google Play Services
    'com.android.settings', // Settings
    'com.android.systemui',
  ];

  /// Initialize the service
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadWhitelist();
    debugPrint(
      '[WhitelistService] Initialized with ${_whitelistedApps.length} apps',
    );
  }

  Future<void> _loadWhitelist() async {
    final jsonString = _prefs?.getString(_whitelistKey);
    if (jsonString != null) {
      final List<dynamic> list = json.decode(jsonString);
      _whitelistedApps = list.map((e) => e.toString()).toSet();
    } else {
      // First time: use default high-risk apps
      _whitelistedApps = defaultHighRiskApps.toSet();
      await _saveWhitelist();
    }
  }

  Future<void> _saveWhitelist() async {
    await _prefs?.setString(
      _whitelistKey,
      json.encode(_whitelistedApps.toList()),
    );
  }

  /// Get all whitelisted package names
  Set<String> getWhitelistedApps() => Set.from(_whitelistedApps);

  /// Check if an app is whitelisted for scanning
  bool isWhitelisted(String packageName) {
    // Never scan privacy-sensitive apps
    if (neverScanApps.contains(packageName)) return false;

    return _whitelistedApps.contains(packageName);
  }

  /// Add an app to the whitelist
  Future<void> addToWhitelist(String packageName) async {
    if (neverScanApps.contains(packageName)) {
      debugPrint(
        '[WhitelistService] Cannot whitelist protected app: $packageName',
      );
      return;
    }

    _whitelistedApps.add(packageName);
    await _saveWhitelist();
    debugPrint('[WhitelistService] Added to whitelist: $packageName');
  }

  /// Remove an app from the whitelist
  Future<void> removeFromWhitelist(String packageName) async {
    _whitelistedApps.remove(packageName);
    await _saveWhitelist();
    debugPrint('[WhitelistService] Removed from whitelist: $packageName');
  }

  /// Toggle whitelist status for an app
  Future<bool> toggleWhitelist(String packageName) async {
    if (isWhitelisted(packageName)) {
      await removeFromWhitelist(packageName);
      return false;
    } else {
      await addToWhitelist(packageName);
      return true;
    }
  }

  /// Clear all whitelisted apps
  Future<void> clearWhitelist() async {
    _whitelistedApps.clear();
    await _saveWhitelist();
    debugPrint('[WhitelistService] Whitelist cleared');
  }

  /// Reset to default whitelist
  Future<void> resetToDefaults() async {
    _whitelistedApps = defaultHighRiskApps.toSet();
    await _saveWhitelist();
    debugPrint('[WhitelistService] Reset to defaults');
  }

  /// Get suggested apps for whitelisting (common social/messaging apps)
  List<AppInfo> getSuggestedApps() {
    return defaultHighRiskApps
        .map(
          (pkg) => AppInfo(
            packageName: pkg,
            appName: _getAppNameFromPackage(pkg),
            isWhitelisted: _whitelistedApps.contains(pkg),
          ),
        )
        .toList();
  }

  String _getAppNameFromPackage(String packageName) {
    final names = {
      'com.whatsapp': 'WhatsApp',
      'com.instagram.android': 'Instagram',
      'com.facebook.katana': 'Facebook',
      'com.facebook.orca': 'Messenger',
      'org.telegram.messenger': 'Telegram',
      'com.twitter.android': 'Twitter/X',
      'com.snapchat.android': 'Snapchat',
      'com.linkedin.android': 'LinkedIn',
      'com.tencent.mm': 'WeChat',
      'jp.naver.line.android': 'LINE',
      'com.viber.voip': 'Viber',
      'com.discord': 'Discord',
      'com.skype.raider': 'Skype',
      'com.google.android.gm': 'Gmail',
      'com.microsoft.office.outlook': 'Outlook',
      'com.yahoo.mobile.client.android.mail': 'Yahoo Mail',
    };
    return names[packageName] ?? packageName.split('.').last;
  }
}

/// Protection mode options
enum ProtectionMode {
  realTime, // Background scanning with overlay
  manualOnly, // Only manual file uploads
  both, // Both modes enabled
}

/// Service for managing protection settings
class ProtectionSettingsService {
  static const String _modeKey = 'riskguard_protection_mode';
  static const String _realTimeEnabledKey = 'riskguard_realtime_enabled';

  static final ProtectionSettingsService _instance =
      ProtectionSettingsService._internal();
  factory ProtectionSettingsService() => _instance;
  ProtectionSettingsService._internal();

  SharedPreferences? _prefs;
  ProtectionMode _currentMode = ProtectionMode.both;
  bool _realTimeEnabled = false;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    final modeIndex = _prefs?.getInt(_modeKey) ?? 2; // Default: both
    _currentMode = ProtectionMode.values[modeIndex.clamp(0, 2)];

    _realTimeEnabled = _prefs?.getBool(_realTimeEnabledKey) ?? false;

    debugPrint(
      '[ProtectionSettings] Mode: $_currentMode, RealTime: $_realTimeEnabled',
    );
  }

  ProtectionMode get currentMode => _currentMode;
  bool get isRealTimeEnabled => _realTimeEnabled;

  /// Set protection mode
  Future<void> setMode(ProtectionMode mode) async {
    _currentMode = mode;
    await _prefs?.setInt(_modeKey, mode.index);
    debugPrint('[ProtectionSettings] Mode set to: $mode');
  }

  /// Toggle real-time protection on/off
  Future<bool> toggleRealTime() async {
    _realTimeEnabled = !_realTimeEnabled;
    await _prefs?.setBool(_realTimeEnabledKey, _realTimeEnabled);
    debugPrint('[ProtectionSettings] Real-time: $_realTimeEnabled');
    return _realTimeEnabled;
  }

  /// Enable real-time protection
  Future<void> enableRealTime() async {
    _realTimeEnabled = true;
    await _prefs?.setBool(_realTimeEnabledKey, true);
  }

  /// Disable real-time protection
  Future<void> disableRealTime() async {
    _realTimeEnabled = false;
    await _prefs?.setBool(_realTimeEnabledKey, false);
  }

  /// Check if real-time mode is available in current mode
  bool get canUseRealTime =>
      _currentMode == ProtectionMode.realTime ||
      _currentMode == ProtectionMode.both;

  /// Check if manual upload is available in current mode
  bool get canUseManual =>
      _currentMode == ProtectionMode.manualOnly ||
      _currentMode == ProtectionMode.both;
}

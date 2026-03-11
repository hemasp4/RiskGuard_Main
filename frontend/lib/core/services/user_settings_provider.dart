/// User settings provider — stores profile and preferences in Hive.
/// Ready for future database migration.
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class UserSettingsProvider extends ChangeNotifier {
  static const String _boxName = 'user_settings';

  Box? _box;

  // Settings fields with defaults
  String _displayName = 'Alex Morgan';
  String _email = 'alex@riskguard.io';
  bool _notificationsEnabled = true;
  bool _biometricsEnabled = false;
  bool _darkModeEnabled = true;

  // Getters
  String get displayName => _displayName;
  String get email => _email;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get biometricsEnabled => _biometricsEnabled;
  bool get darkModeEnabled => _darkModeEnabled;

  /// Initialize from Hive on startup
  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    _displayName =
        _box?.get('displayName', defaultValue: 'Alex Morgan') ?? 'Alex Morgan';
    _email =
        _box?.get('email', defaultValue: 'alex@riskguard.io') ??
        'alex@riskguard.io';
    _notificationsEnabled =
        _box?.get('notificationsEnabled', defaultValue: true) ?? true;
    _biometricsEnabled =
        _box?.get('biometricsEnabled', defaultValue: false) ?? false;
    _darkModeEnabled = _box?.get('darkModeEnabled', defaultValue: true) ?? true;
    notifyListeners();
  }

  Future<void> setDisplayName(String name) async {
    _displayName = name;
    await _box?.put('displayName', name);
    notifyListeners();
  }

  Future<void> setEmail(String email) async {
    _email = email;
    await _box?.put('email', email);
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    await _box?.put('notificationsEnabled', value);
    notifyListeners();
  }

  Future<void> setBiometricsEnabled(bool value) async {
    _biometricsEnabled = value;
    await _box?.put('biometricsEnabled', value);
    notifyListeners();
  }

  Future<void> setDarkModeEnabled(bool value) async {
    _darkModeEnabled = value;
    await _box?.put('darkModeEnabled', value);
    notifyListeners();
  }

  /// Clear all settings (for logout)
  Future<void> clearAll() async {
    await _box?.clear();
    _displayName = 'Alex Morgan';
    _email = 'alex@riskguard.io';
    _notificationsEnabled = true;
    _biometricsEnabled = false;
    _darkModeEnabled = true;
    notifyListeners();
  }
}

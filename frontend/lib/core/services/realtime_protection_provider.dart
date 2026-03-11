/// Real-time protection provider — manages the Master Toggle.
/// Uses Hive for state persistence (web + mobile compatible).
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'api_service.dart';

class RealtimeProtectionProvider extends ChangeNotifier {
  static const String _boxName = 'user_settings';
  static const String _activeKey = 'realtime_protection_enabled';

  bool _isActive = false;
  bool _isBackendConnected = false;
  bool _loaded = false;

  bool get isActive => _isActive;
  bool get isBackendConnected => _isBackendConnected;

  /// Load state from Hive
  Future<void> loadState() async {
    if (_loaded) return;
    try {
      final box = await Hive.openBox(_boxName);
      _isActive = box.get(_activeKey, defaultValue: false);
      _loaded = true;
      await checkBackendHealth();
      notifyListeners();
    } catch (e) {
      debugPrint('RealtimeProtectionProvider: Failed to load: $e');
      _loaded = true;
    }
  }

  /// Toggle real-time protection ON/OFF
  Future<void> toggleProtection() async {
    _isActive = !_isActive;
    notifyListeners();
    try {
      final box = await Hive.openBox(_boxName);
      await box.put(_activeKey, _isActive);
    } catch (e) {
      debugPrint('RealtimeProtectionProvider: Failed to persist: $e');
    }
  }

  /// Set protection explicitly
  Future<void> setProtection(bool value) async {
    if (_isActive == value) return;
    _isActive = value;
    notifyListeners();
    try {
      final box = await Hive.openBox(_boxName);
      await box.put(_activeKey, _isActive);
    } catch (e) {
      debugPrint('RealtimeProtectionProvider: Failed to persist: $e');
    }
  }

  /// Check if backend is reachable
  Future<void> checkBackendHealth() async {
    final healthy = await ApiService().isBackendHealthy();
    if (_isBackendConnected != healthy) {
      _isBackendConnected = healthy;
      notifyListeners();
    }
  }
}

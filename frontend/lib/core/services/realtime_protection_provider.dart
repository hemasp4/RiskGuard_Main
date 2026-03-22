import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import 'api_service.dart';
import 'native_bridge.dart';

/// Real-time protection provider for the Android background protection stack.
class RealtimeProtectionProvider extends ChangeNotifier {
  static const String _boxName = 'user_settings';
  static const String _activeKey = 'realtime_protection_enabled';
  static const MethodChannel _overlayChannel =
      MethodChannel('x-slayer/overlay_channel');

  bool _isActive = false;
  bool _isBackendConnected = false;
  bool _loaded = false;
  bool _showAccessibilityGuidance = false;
  bool _isTransitioning = false;

  final Set<String> _processedUrls = <String>{};

  bool get isActive => _isActive;
  bool get isBackendConnected => _isBackendConnected;
  bool get showAccessibilityGuidance => _showAccessibilityGuidance;
  bool get isTransitioning => _isTransitioning;

  Future<void> loadState() async {
    if (_loaded) return;

    try {
      final box = await Hive.openBox(_boxName);
      _isActive = box.get(_activeKey, defaultValue: false);
      _loaded = true;

      NativeBridge.init(onUrlDetected: _handleUrlDetected);
      NativeBridge.setCallListener(_handleCallDetected);

      await checkBackendHealth();
      await syncToNative();

      if (_isActive && Platform.isAndroid) {
        await setProtection(true, allowPrompts: false, force: true);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('RealtimeProtectionProvider: Failed to load: $e');
      _loaded = true;
    }
  }

  Future<bool> toggleProtection() async {
    return setProtection(!_isActive);
  }

  Future<bool> setProtection(
    bool value, {
    bool allowPrompts = true,
    bool force = false,
  }) async {
    if (_isTransitioning) return _isActive;
    if (!force && _isActive == value && (!Platform.isAndroid || !value)) {
      return _isActive;
    }

    _isTransitioning = true;
    notifyListeners();

    try {
      if (value && Platform.isAndroid) {
        final ready = await _ensureAndroidPrerequisites(
          allowPrompts: allowPrompts,
        );
        if (!ready) {
          _isActive = false;
          _processedUrls.clear();
          await _persistState();
          await syncToNative();
          notifyListeners();
          return false;
        }

        final monitoringStarted = await _startNativeMonitoring();
        final overlayVisible = await _ensureOverlayVisible();
        final activated = monitoringStarted && overlayVisible;

        if (!activated) {
          await _stopNativeMonitoring();
          _processedUrls.clear();
        }

        _isActive = activated;
        await _persistState();
        await syncToNative();
        notifyListeners();
        return activated;
      }

      if (Platform.isAndroid) {
        await _stopNativeMonitoring();
      }

      _isActive = value;
      if (!value) {
        _processedUrls.clear();
        _showAccessibilityGuidance = false;
      }

      await _persistState();
      await syncToNative();
      notifyListeners();
      return _isActive;
    } finally {
      _isTransitioning = false;
      notifyListeners();
    }
  }

  Future<void> syncToNative() async {
    try {
      final box = await Hive.openBox('whitelist_settings');
      final enabledPkgs = <String>[];
      final keys = box.keys.where((key) => key.toString().startsWith('wl_'));

      for (final key in keys) {
        if (box.get(key) == true) {
          enabledPkgs.add(key.toString().replaceFirst('wl_', ''));
        }
      }

      await NativeBridge.syncSecuritySettings(
        isProtectionActive: _isActive,
        whitelistedPackages: enabledPkgs,
      );
    } catch (e) {
      debugPrint('RealtimeProtectionProvider: Sync failed: $e');
    }
  }

  Future<void> checkBackendHealth() async {
    final healthy = await ApiService().isBackendHealthy();
    if (_isBackendConnected != healthy) {
      _isBackendConnected = healthy;
      notifyListeners();
    }
  }

  void dismissAccessibilityGuidance() {
    if (!_showAccessibilityGuidance) return;
    _showAccessibilityGuidance = false;
    notifyListeners();
  }

  Future<bool> _ensureAndroidPrerequisites({
    required bool allowPrompts,
  }) async {
    final overlayGranted = await _isOverlayPermissionGranted();
    if (!overlayGranted) {
      if (allowPrompts) {
        await NativeBridge.requestOverlayPermission();
      }
      return false;
    }

    final accessibilityGranted =
        await NativeBridge.isAccessibilityPermissionGranted();
    if (!accessibilityGranted) {
      _showAccessibilityGuidance = true;
      notifyListeners();
      if (allowPrompts) {
        await NativeBridge.requestAccessibilityPermission();
      }
      return false;
    }

    final phoneStatus = await Permission.phone.status;
    if (!phoneStatus.isGranted) {
      if (!allowPrompts) return false;

      final requestedStatus = await Permission.phone.request();
      if (!requestedStatus.isGranted) {
        return false;
      }
    }

    if (_showAccessibilityGuidance) {
      _showAccessibilityGuidance = false;
      notifyListeners();
    }
    return true;
  }

  Future<bool> _startNativeMonitoring() async {
    try {
      await NativeBridge.startForegroundService();
      return true;
    } catch (e) {
      debugPrint('RealtimeProtectionProvider: Failed to start service: $e');
      return false;
    }
  }

  Future<void> _stopNativeMonitoring() async {
    try {
      await NativeBridge.stopForegroundService();
    } catch (e) {
      debugPrint('RealtimeProtectionProvider: Failed to stop service: $e');
    }

    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (e) {
      debugPrint('RealtimeProtectionProvider: Failed to close overlay: $e');
    }
  }

  Future<bool> _ensureOverlayVisible() async {
    if (await _isOverlayActive()) {
      return true;
    }

    try {
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        flag: OverlayFlag.defaultFlag,
        alignment: OverlayAlignment.centerRight,
        visibility: NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.right,
        height: 80,
        width: 80,
        overlayTitle: 'RiskGuard Active',
        overlayContent: 'Realtime protection is monitoring links and calls.',
      );
    } catch (e) {
      debugPrint('RealtimeProtectionProvider: Failed to show overlay: $e');
      return false;
    }

    await Future<void>.delayed(const Duration(milliseconds: 500));
    final isActive = await _isOverlayActive();
    if (!isActive) {
      debugPrint(
        'RealtimeProtectionProvider: Overlay service did not become active after showOverlay().',
      );
    }
    return isActive;
  }

  Future<void> _handleUrlDetected(String url, String? packageName) async {
    if (!_isActive) return;
    if (_processedUrls.contains(url)) return;
    _processedUrls.add(url);

    final overlayVisible = await _ensureOverlayVisible();
    if (!overlayVisible) return;
    debugPrint(
      'RealtimeProtectionProvider: Overlay restored for URL $url from ${packageName ?? 'unknown'}',
    );
  }

  Future<void> _handleCallDetected(String? state, String? phoneNumber) async {
    if (!_isActive || state == null) return;

    final overlayVisible = await _ensureOverlayVisible();
    if (!overlayVisible) return;

    if (state == 'RINGING' || state == 'OFFHOOK') {
      try {
        await FlutterOverlayWindow.resizeOverlay(-1, -1, false);
      } catch (e) {
        debugPrint('RealtimeProtectionProvider: Call overlay expand failed: $e');
      }

      await NativeBridge.sendMessageToOverlay({
        'status': 'CALL SCANNER',
        'isCallActive': true,
        'phoneNumber': phoneNumber ?? 'Hidden Number',
        'message': 'Analyzing Voice Patterns...',
      });
      return;
    }

    if (state == 'IDLE') {
      try {
        await FlutterOverlayWindow.resizeOverlay(80, 80, true);
      } catch (e) {
        debugPrint('RealtimeProtectionProvider: Call overlay collapse failed: $e');
      }

      await NativeBridge.sendMessageToOverlay({
        'status': 'CALL ENDED',
        'isCallActive': false,
      });
    }
  }

  Future<bool> _isOverlayPermissionGranted() async {
    try {
      final granted =
          await _overlayChannel.invokeMethod<bool>('checkPermission');
      if (granted != null) {
        return granted;
      }
    } catch (e) {
      debugPrint(
        'RealtimeProtectionProvider: Plugin overlay permission check failed: $e',
      );
    }

    return NativeBridge.isOverlayPermissionGranted();
  }

  Future<bool> _isOverlayActive() async {
    try {
      return await _overlayChannel.invokeMethod<bool>('isOverlayActive') ??
          false;
    } catch (e) {
      debugPrint('RealtimeProtectionProvider: Overlay active check failed: $e');
      return false;
    }
  }

  Future<void> _persistState() async {
    try {
      final box = await Hive.openBox(_boxName);
      await box.put(_activeKey, _isActive);
    } catch (e) {
      debugPrint('RealtimeProtectionProvider: Failed to persist: $e');
    }
  }
}

/// Call history provider for state management
library;

import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
import '../services/call_risk_service.dart';
import '../../../core/services/method_channel_service.dart';

class CallHistoryProvider extends ChangeNotifier {
  final CallRiskService _callRiskService = CallRiskService();

  List<CallRiskResult> _callHistory = [];
  List<CallRiskResult> get callHistory => _callHistory;

  CallRiskResult? _currentCall;
  CallRiskResult? get currentCall => _currentCall;

  bool _isMonitoring = false;
  bool get isMonitoring => _isMonitoring;

  CallHistoryProvider() {
    _initialize();
  }

  void _initialize() {
    _callRiskService.initialize();

    // Listen to call state changes
    _callRiskService.callStateStream.listen((result) {
      _currentCall = result;
      _addToHistory(result);
      notifyListeners();
    });

    // Restore saved protection state
    _restoreProtectionState();
  }

  /// Restore protection state from native storage
  Future<void> _restoreProtectionState() async {
    try {
      final methodChannelService = MethodChannelService();
      final wasEnabled = await methodChannelService.isProtectionEnabled();

      if (wasEnabled) {
        developer.log(
          '[CallHistoryProvider] Protection was previously enabled, restoring...',
        );
        // Start monitoring automatically
        _isMonitoring = await _callRiskService.startMonitoring();
        notifyListeners();
        developer.log(
          '[CallHistoryProvider] Protection restored: $_isMonitoring',
        );
      } else {
        developer.log(
          '[CallHistoryProvider] Protection was not enabled previously',
        );
      }
    } catch (e) {
      developer.log(
        '[CallHistoryProvider] Failed to restore protection state: $e',
      );
    }
  }

  void _addToHistory(CallRiskResult result) {
    _callHistory.insert(0, result);
    // Keep only last 50 calls
    if (_callHistory.length > 50) {
      _callHistory = _callHistory.sublist(0, 50);
    }
  }

  Future<void> startMonitoring() async {
    _isMonitoring = await _callRiskService.startMonitoring();
    notifyListeners();
  }

  Future<void> stopMonitoring() async {
    await _callRiskService.stopMonitoring();
    _isMonitoring = false;
    notifyListeners();
  }

  void clearHistory() {
    _callHistory.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _callRiskService.dispose();
    super.dispose();
  }
}

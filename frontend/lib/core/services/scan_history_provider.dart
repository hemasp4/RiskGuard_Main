/// Scan history provider — stores scan results in Hive for persistence.
/// Hive boxes map cleanly to DB tables for future migration.
library;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/analysis_models.dart';

class ScanHistoryProvider extends ChangeNotifier {
  static const String _boxName = 'scan_history';
  static const int _maxEntries = 50;

  List<ScanHistoryEntry> _entries = [];
  bool _loaded = false;

  List<ScanHistoryEntry> get entries => List.unmodifiable(_entries);
  List<ScanHistoryEntry> get recentEntries => _entries.take(10).toList();

  int get totalScans => _entries.length;
  int get threatsBlocked => _entries.where((e) => e.riskLevel == 'HIGH').length;
  int get verifiedSafe => _entries.where((e) => e.riskLevel == 'LOW').length;
  int get moderateThreats =>
      _entries.where((e) => e.riskLevel == 'MEDIUM').length;

  /// Load history from Hive
  Future<void> loadHistory() async {
    if (_loaded) return;
    try {
      final box = await Hive.openBox(_boxName);
      final raw = box.get('entries');
      if (raw != null) {
        final list = (raw as List).map((e) {
          if (e is Map) {
            return ScanHistoryEntry.fromJson(Map<String, dynamic>.from(e));
          }
          return ScanHistoryEntry.fromJson(
            Map<String, dynamic>.from(jsonDecode(e.toString())),
          );
        }).toList();
        _entries = list;
        _entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      }
      _loaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('ScanHistoryProvider: Failed to load: $e');
      _loaded = true;
    }
  }

  /// Add a new scan result
  Future<void> addScan(ScanHistoryEntry entry) async {
    _entries.insert(0, entry);
    if (_entries.length > _maxEntries) {
      _entries = _entries.sublist(0, _maxEntries);
    }
    notifyListeners();
    await _persist();
  }

  /// Persist to Hive
  Future<void> _persist() async {
    try {
      final box = await Hive.openBox(_boxName);
      await box.put('entries', _entries.map((e) => e.toJson()).toList());
    } catch (e) {
      debugPrint('ScanHistoryProvider: Failed to persist: $e');
    }
  }

  /// Clear all history
  Future<void> clearHistory() async {
    _entries.clear();
    notifyListeners();
    try {
      final box = await Hive.openBox(_boxName);
      await box.clear();
    } catch (e) {
      debugPrint('ScanHistoryProvider: Failed to clear: $e');
    }
  }
}

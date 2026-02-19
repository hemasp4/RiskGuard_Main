/// Provider for overall analysis state management
library;

import 'package:flutter/foundation.dart';
import '../services/overall_analysis_service.dart';
import '../../call_detection/services/call_risk_service.dart';
import '../../message_analysis/services/message_analyzer_service.dart';

class OverallAnalysisProvider extends ChangeNotifier {
  final OverallAnalysisService _service = OverallAnalysisService();

  OverallStatistics? _currentStatistics;
  List<AnalysisTrend>? _trends;
  bool _isLoading = false;
  String? _error;

  // Getters
  OverallStatistics? get statistics => _currentStatistics;
  List<AnalysisTrend>? get trends => _trends;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Date range filters
  DateTime? _startDate;
  DateTime? _endDate;

  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;

  OverallAnalysisProvider() {
    _initialize();
  }

  void _initialize() {
    _service.initialize();

    // Listen to real-time updates
    _service.statisticsStream.listen((stats) {
      _currentStatistics = stats;
      notifyListeners();
    });

    // Load initial data
    refresh();
  }

  /// Refresh all data
  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentStatistics = _service.getStatistics(
        startDate: _startDate,
        endDate: _endDate,
      );
      _trends = _service.getTrends(days: 7);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Set date range filter
  void setDateRange(DateTime? start, DateTime? end) {
    _startDate = start;
    _endDate = end;
    refresh();
  }

  /// Clear date range filter
  void clearDateRange() {
    _startDate = null;
    _endDate = null;
    refresh();
  }

  /// Get call history
  List<CallRiskResult> getCallHistory() {
    return _service.getCallHistory(startDate: _startDate, endDate: _endDate);
  }

  /// Get message history
  List<MessageAnalysisResult> getMessageHistory() {
    return _service.getMessageHistory(startDate: _startDate, endDate: _endDate);
  }

  /// Analyze message
  Future<MessageAnalysisResult> analyzeMessage(String message) async {
    return await _service.analyzeMessage(message);
  }

  /// Clear all history
  void clearHistory() {
    _service.clearHistory();
    refresh();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}

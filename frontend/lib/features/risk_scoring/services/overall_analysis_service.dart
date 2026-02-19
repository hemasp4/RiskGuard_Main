library;

import 'dart:async';
import '../../../core/constants/risk_levels.dart';
import '../../call_detection/services/call_risk_service.dart';
import '../../voice_analysis/services/voice_analyzer_service.dart';
import '../../message_analysis/services/message_analyzer_service.dart';

/// Overall statistics for all analysis types
class OverallStatistics {
  final int totalCalls;
  final int highRiskCalls;
  final int aiVoiceDetected;
  final int totalMessages;
  final int phishingDetected;
  final int totalThreats;
  final double averageRiskScore;
  final DateTime lastUpdated;

  OverallStatistics({
    required this.totalCalls,
    required this.highRiskCalls,
    required this.aiVoiceDetected,
    required this.totalMessages,
    required this.phishingDetected,
    required this.totalThreats,
    required this.averageRiskScore,
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson() => {
    'totalCalls': totalCalls,
    'highRiskCalls': highRiskCalls,
    'aiVoiceDetected': aiVoiceDetected,
    'totalMessages': totalMessages,
    'phishingDetected': phishingDetected,
    'totalThreats': totalThreats,
    'averageRiskScore': averageRiskScore,
    'lastUpdated': lastUpdated.toIso8601String(),
  };
}

/// Analysis trend data for time series charts
class AnalysisTrend {
  final DateTime date;
  final int callCount;
  final int messageCount;
  final double avgRiskScore;

  AnalysisTrend({
    required this.date,
    required this.callCount,
    required this.messageCount,
    required this.avgRiskScore,
  });
}

class OverallAnalysisService {
  final CallRiskService _callRiskService = CallRiskService();
  final VoiceAnalyzerService _voiceAnalyzer = VoiceAnalyzerService();
  final MessageAnalyzerService _messageAnalyzer = MessageAnalyzerService();

  // Singleton
  static final OverallAnalysisService _instance =
      OverallAnalysisService._internal();
  factory OverallAnalysisService() => _instance;
  OverallAnalysisService._internal();

  // Data storage
  final List<CallRiskResult> _callHistory = [];
  final List<MessageAnalysisResult> _messageHistory = [];

  // Stream controller for real-time updates
  final _statisticsController = StreamController<OverallStatistics>.broadcast();
  Stream<OverallStatistics> get statisticsStream =>
      _statisticsController.stream;

  /// Initialize the service
  void initialize() {
    _callRiskService.initialize();

    // Listen to call events
    _callRiskService.callStateStream.listen((callResult) {
      _callHistory.add(callResult);
      _updateStatistics();
    });
  }

  /// Analyze a message and add to history
  Future<MessageAnalysisResult> analyzeMessage(String message) async {
    final result = await _messageAnalyzer.analyzeMessage(message);
    _messageHistory.add(result);
    _updateStatistics();
    return result;
  }

  /// Analyze voice (used for standalone voice analysis)
  Future<VoiceAnalysisResult> analyzeVoice(String audioPath) async {
    return await _voiceAnalyzer.analyzeAudio(audioPath);
  }

  /// Get overall statistics
  OverallStatistics getStatistics({DateTime? startDate, DateTime? endDate}) {
    // Filter by date range if provided
    var callsInRange = _callHistory;
    var messagesInRange = _messageHistory;

    if (startDate != null) {
      callsInRange = callsInRange
          .where((call) => call.analyzedAt.isAfter(startDate))
          .toList();
      messagesInRange = messagesInRange
          .where((msg) => msg.analyzedAt.isAfter(startDate))
          .toList();
    }

    if (endDate != null) {
      callsInRange = callsInRange
          .where((call) => call.analyzedAt.isBefore(endDate))
          .toList();
      messagesInRange = messagesInRange
          .where((msg) => msg.analyzedAt.isBefore(endDate))
          .toList();
    }

    // Calculate statistics
    final totalCalls = callsInRange.length;
    final highRiskCalls = callsInRange
        .where((call) => call.riskLevel == RiskLevel.high)
        .length;
    final aiVoiceDetected = callsInRange
        .where((call) => call.isAIVoice == true)
        .length;

    final totalMessages = messagesInRange.length;
    final phishingDetected = messagesInRange.where((msg) => !msg.isSafe).length;

    final totalThreats = highRiskCalls + phishingDetected;

    // Calculate average risk score
    double averageRiskScore = 0.0;
    if (callsInRange.isNotEmpty || messagesInRange.isNotEmpty) {
      final callScores = callsInRange.map((c) => c.riskScore);
      final msgScores = messagesInRange.map((m) => m.riskScore);
      final allScores = [...callScores, ...msgScores];
      averageRiskScore = allScores.reduce((a, b) => a + b) / allScores.length;
    }

    return OverallStatistics(
      totalCalls: totalCalls,
      highRiskCalls: highRiskCalls,
      aiVoiceDetected: aiVoiceDetected,
      totalMessages: totalMessages,
      phishingDetected: phishingDetected,
      totalThreats: totalThreats,
      averageRiskScore: averageRiskScore,
      lastUpdated: DateTime.now(),
    );
  }

  /// Get trend data for charts (last N days)
  List<AnalysisTrend> getTrends({int days = 7}) {
    final trends = <AnalysisTrend>[];
    final now = DateTime.now();

    for (int i = days - 1; i >= 0; i--) {
      final date = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: i));
      final nextDate = date.add(const Duration(days: 1));

      // Get calls and messages for this day
      final dayCalls = _callHistory.where((call) {
        return call.analyzedAt.isAfter(date) &&
            call.analyzedAt.isBefore(nextDate);
      }).toList();

      final dayMessages = _messageHistory.where((msg) {
        return msg.analyzedAt.isAfter(date) &&
            msg.analyzedAt.isBefore(nextDate);
      }).toList();

      // Calculate average risk score for the day
      double avgRisk = 0.0;
      if (dayCalls.isNotEmpty || dayMessages.isNotEmpty) {
        final allScores = [
          ...dayCalls.map((c) => c.riskScore),
          ...dayMessages.map((m) => m.riskScore),
        ];
        avgRisk = allScores.reduce((a, b) => a + b) / allScores.length;
      }

      trends.add(
        AnalysisTrend(
          date: date,
          callCount: dayCalls.length,
          messageCount: dayMessages.length,
          avgRiskScore: avgRisk,
        ),
      );
    }

    return trends;
  }

  /// Get call history
  List<CallRiskResult> getCallHistory({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    var history = _callHistory;

    if (startDate != null) {
      history = history
          .where((call) => call.analyzedAt.isAfter(startDate))
          .toList();
    }

    if (endDate != null) {
      history = history
          .where((call) => call.analyzedAt.isBefore(endDate))
          .toList();
    }

    return history;
  }

  /// Get message history
  List<MessageAnalysisResult> getMessageHistory({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    var history = _messageHistory;

    if (startDate != null) {
      history = history
          .where((msg) => msg.analyzedAt.isAfter(startDate))
          .toList();
    }

    if (endDate != null) {
      history = history
          .where((msg) => msg.analyzedAt.isBefore(endDate))
          .toList();
    }

    return history;
  }

  /// Refresh all statistics
  void refresh() {
    _updateStatistics();
  }

  /// Clear all history
  void clearHistory() {
    _callHistory.clear();
    _messageHistory.clear();
    _updateStatistics();
  }

  /// Update statistics and emit event
  void _updateStatistics() {
    final stats = getStatistics();
    _statisticsController.add(stats);
  }

  /// Dispose resources
  void dispose() {
    _statisticsController.close();
  }
}

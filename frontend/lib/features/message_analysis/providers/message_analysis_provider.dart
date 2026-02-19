/// Message Analysis Provider for state management
library;

import 'package:flutter/foundation.dart';
import '../services/message_analyzer_service.dart';

class MessageAnalysisProvider extends ChangeNotifier {
  final MessageAnalyzerService _analyzer = MessageAnalyzerService();

  bool _isAnalyzing = false;
  bool get isAnalyzing => _isAnalyzing;

  MessageAnalysisResult? _lastResult;
  MessageAnalysisResult? get lastResult => _lastResult;

  List<MessageAnalysisResult> _history = [];
  List<MessageAnalysisResult> get history => _history;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String _currentMessage = '';
  String get currentMessage => _currentMessage;

  /// Set the message to analyze
  void setMessage(String message) {
    _currentMessage = message;
    notifyListeners();
  }

  /// Analyze the current message
  Future<MessageAnalysisResult?> analyzeMessage([String? message]) async {
    final textToAnalyze = message ?? _currentMessage;

    if (textToAnalyze.trim().isEmpty) {
      _errorMessage = 'Please enter or paste a message to analyze.';
      notifyListeners();
      return null;
    }

    _isAnalyzing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _analyzer.analyzeMessage(textToAnalyze);
      _lastResult = result;
      _history.insert(0, result);

      // Keep only last 30 analyses
      if (_history.length > 30) {
        _history = _history.sublist(0, 30);
      }

      return result;
    } catch (e) {
      _errorMessage = 'Analysis failed: $e';
      return null;
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  /// Handle shared content from other apps
  void handleSharedContent(String sharedText) {
    _currentMessage = sharedText;
    analyzeMessage(sharedText);
  }

  /// Clear current result
  void clearResult() {
    _lastResult = null;
    _currentMessage = '';
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear history
  void clearHistory() {
    _history.clear();
    notifyListeners();
  }
}

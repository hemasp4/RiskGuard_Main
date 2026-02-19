/// Provider for video analysis state management
library;

import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../services/video_analyzer_service.dart';

/// Provider for video analysis state management
class VideoAnalysisProvider extends ChangeNotifier {
  final VideoAnalyzerService _service = VideoAnalyzerService();

  VideoAnalysisResult? _currentResult;
  bool _isAnalyzing = false;
  String? _error;
  double _progress = 0.0;

  final List<VideoAnalysisResult> _analysisHistory = [];

  // Getters
  VideoAnalysisResult? get currentResult => _currentResult;
  bool get isAnalyzing => _isAnalyzing;
  String? get error => _error;
  double get progress => _progress;
  List<VideoAnalysisResult> get analysisHistory =>
      List.unmodifiable(_analysisHistory);

  /// Analyze video from bytes (works on Web + Mobile)
  Future<void> analyzeVideoFromBytes(Uint8List bytes, String fileName) async {
    _isAnalyzing = true;
    _error = null;
    _progress = 0.0;
    _currentResult = null;
    notifyListeners();

    try {
      _updateProgress(0.1);

      final result = await _service.analyzeVideoBytes(bytes, fileName);

      _updateProgress(1.0);
      _currentResult = result;
      _analysisHistory.insert(0, result);
      _isAnalyzing = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isAnalyzing = false;
      _progress = 0.0;
      notifyListeners();
    }
  }

  /// Analyze a video file by path (mobile only)
  Future<void> analyzeVideo(String videoPath) async {
    _isAnalyzing = true;
    _error = null;
    _progress = 0.0;
    _currentResult = null;
    notifyListeners();

    try {
      _updateProgress(0.1);

      final result = await _service.analyzeVideo(videoPath);

      _updateProgress(1.0);
      _currentResult = result;
      _analysisHistory.insert(0, result);
      _isAnalyzing = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isAnalyzing = false;
      _progress = 0.0;
      notifyListeners();
    }
  }

  /// Update progress
  void _updateProgress(double value) {
    _progress = value;
    notifyListeners();
  }

  /// Clear current result
  void clearResult() {
    _currentResult = null;
    _error = null;
    _progress = 0.0;
    notifyListeners();
  }

  /// Clear analysis history
  void clearHistory() {
    _analysisHistory.clear();
    notifyListeners();
  }
}

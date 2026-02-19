/// Voice Analysis Provider for state management
library;

import 'package:flutter/foundation.dart';
import '../services/voice_recorder_service.dart';
import '../services/voice_analyzer_service.dart';

class VoiceAnalysisProvider extends ChangeNotifier {
  final VoiceRecorderService _recorder = VoiceRecorderService();
  final VoiceAnalyzerService _analyzer = VoiceAnalyzerService();

  RecordingState _recordingState = RecordingState.idle;
  RecordingState get recordingState => _recordingState;

  bool _isAnalyzing = false;
  bool get isAnalyzing => _isAnalyzing;

  VoiceAnalysisResult? _lastResult;
  VoiceAnalysisResult? get lastResult => _lastResult;

  List<VoiceAnalysisResult> _history = [];
  List<VoiceAnalysisResult> get history => _history;

  double _currentAmplitude = 0.0;
  double get currentAmplitude => _currentAmplitude;

  final List<double> _amplitudeHistory = [];
  List<double> get amplitudeHistory => _amplitudeHistory;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  VoiceAnalysisProvider() {
    _initialize();
  }

  void _initialize() {
    // Listen to recording state changes
    _recorder.stateStream.listen((state) {
      _recordingState = state;
      notifyListeners();
    });

    // Listen to amplitude updates
    _recorder.amplitudeStream.listen((amplitude) {
      _currentAmplitude = amplitude;

      // Track amplitude history for real-time graph (last 50 samples)
      _amplitudeHistory.add(amplitude);
      if (_amplitudeHistory.length > 50) {
        _amplitudeHistory.removeAt(0);
      }

      notifyListeners();
    });
  }

  /// Check if microphone permission is granted
  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  /// Start voice recording
  Future<bool> startRecording() async {
    _errorMessage = null;
    _amplitudeHistory.clear(); // Clear previous amplitude data
    final success = await _recorder.startRecording();
    if (!success) {
      _errorMessage =
          'Failed to start recording. Please check microphone permission.';
    }
    notifyListeners();
    return success;
  }

  /// Stop recording and analyze the voice
  Future<VoiceAnalysisResult?> stopAndAnalyze() async {
    _errorMessage = null;

    final filePath = await _recorder.stopRecording();
    if (filePath == null) {
      _errorMessage = 'Recording failed. Please try again.';
      notifyListeners();
      return null;
    }

    _isAnalyzing = true;
    notifyListeners();

    try {
      final result = await _analyzer.analyzeAudio(filePath);
      _lastResult = result;
      _history.insert(0, result);

      // Keep only last 20 analyses
      if (_history.length > 20) {
        _history = _history.sublist(0, 20);
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

  /// Cancel current recording
  Future<void> cancelRecording() async {
    await _recorder.cancelRecording();
    notifyListeners();
  }

  /// Clear last result
  void clearResult() {
    _lastResult = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear history
  void clearHistory() {
    _history.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }
}

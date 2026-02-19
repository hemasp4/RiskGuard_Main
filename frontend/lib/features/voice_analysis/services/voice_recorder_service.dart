import 'dart:async';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

enum RecordingState { idle, recording, paused, stopped }

class VoiceRecorderService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();

  RecordingState _state = RecordingState.idle;
  RecordingState get state => _state;

  String? _currentRecordingPath;
  String? get currentRecordingPath => _currentRecordingPath;

  DateTime? _recordingStartTime;
  Duration get recordingDuration {
    if (_recordingStartTime == null) return Duration.zero;
    return DateTime.now().difference(_recordingStartTime!);
  }

  bool _isInitialized = false;

  // State change stream
  final _stateController = StreamController<RecordingState>.broadcast();
  Stream<RecordingState> get stateStream => _stateController.stream;

  // Amplitude stream (simulated for flutter_sound)
  final _amplitudeController = StreamController<double>.broadcast();
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  /// Initialize the recorder
  Future<void> _initialize() async {
    if (!_isInitialized) {
      await _recorder.openRecorder();
      _isInitialized = true;
    }
  }

  /// Check if recording permission is granted
  Future<bool> hasPermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Start recording audio
  Future<bool> startRecording() async {
    try {
      if (!await hasPermission()) {
        final status = await Permission.microphone.request();
        if (!status.isGranted) return false;
      }

      await _initialize();

      // Get temp directory for recording
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${directory.path}/voice_analysis_$timestamp.aac';

      await _recorder.startRecorder(
        toFile: _currentRecordingPath,
        codec: Codec.aacADTS,
      );

      _state = RecordingState.recording;
      _recordingStartTime = DateTime.now();
      _stateController.add(_state);

      // Start amplitude monitoring
      _startAmplitudeMonitoring();

      return true;
    } catch (e) {
      debugPrint('Error starting recording: $e');
      return false;
    }
  }

  /// Stop recording and return the file path
  Future<String?> stopRecording() async {
    try {
      final path = await _recorder.stopRecorder();

      _state = RecordingState.stopped;
      _stateController.add(_state);
      _stopAmplitudeMonitoring();

      return path ?? _currentRecordingPath;
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      return null;
    }
  }

  /// Pause recording
  Future<void> pauseRecording() async {
    try {
      await _recorder.pauseRecorder();
      _state = RecordingState.paused;
      _stateController.add(_state);
    } catch (e) {
      debugPrint('Error pausing recording: $e');
    }
  }

  /// Resume recording
  Future<void> resumeRecording() async {
    try {
      await _recorder.resumeRecorder();
      _state = RecordingState.recording;
      _stateController.add(_state);
    } catch (e) {
      debugPrint('Error resuming recording: $e');
    }
  }

  /// Cancel recording and delete the file
  Future<void> cancelRecording() async {
    try {
      await _recorder.stopRecorder();

      _state = RecordingState.idle;
      _currentRecordingPath = null;
      _recordingStartTime = null;
      _stateController.add(_state);
      _stopAmplitudeMonitoring();
    } catch (e) {
      debugPrint('Error canceling recording: $e');
    }
  }

  StreamSubscription? _recorderSubscription;

  void _startAmplitudeMonitoring() {
    _recorder.setSubscriptionDuration(const Duration(milliseconds: 100));
    _recorderSubscription = _recorder.onProgress!.listen((e) {
      if (_state == RecordingState.recording) {
        // Map decibels to 0.0 - 1.0 range
        // decibels usually range from -60 (quiet) to 0 (loud) or similar
        double level = e.decibels ?? 0.0;

        // Normalize: assuming -60 is floor and 0 is ceiling
        // We'll use a more dynamic normalization
        double normalized = (level + 60) / 60;
        if (normalized < 0.1) normalized = 0.1; // Base floor for UI
        if (normalized > 1.0) normalized = 1.0;

        _amplitudeController.add(normalized);
      }
    });
  }

  void _stopAmplitudeMonitoring() {
    _recorderSubscription?.cancel();
    _recorderSubscription = null;
  }

  /// Check if currently recording
  bool get isRecording => _state == RecordingState.recording;

  /// Clean up resources
  void dispose() {
    _stopAmplitudeMonitoring();
    _recorder.closeRecorder();
    _amplitudeController.close();
    _stateController.close();
  }
}

void debugPrint(String message) {
  // ignore: avoid_print
  print(message);
}

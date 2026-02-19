/// Debouncer Utility
///
/// Used for scroll debouncing and battery optimization.
/// Only triggers actions after user stops for a specified duration.
library;

import 'dart:async';

/// Debouncer class for event-driven optimization
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 1500)});

  /// Run the action after the delay
  /// If called again before delay, timer resets
  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Cancel any pending action
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Check if timer is active
  bool get isActive => _timer?.isActive ?? false;

  /// Dispose the debouncer
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Throttler class - ensures action runs at most once per duration
class Throttler {
  final Duration duration;
  DateTime? _lastRun;

  Throttler({this.duration = const Duration(seconds: 1)});

  /// Run action if enough time has passed since last run
  void run(void Function() action) {
    final now = DateTime.now();
    if (_lastRun == null || now.difference(_lastRun!) >= duration) {
      _lastRun = now;
      action();
    }
  }

  /// Force reset, allowing next action to run immediately
  void reset() {
    _lastRun = null;
  }
}

/// Scroll detector for battery optimization
/// Only triggers scan when user stops scrolling
class ScrollActivityDetector {
  final Duration idleThreshold;
  final void Function() onIdle;
  final void Function()? onScrolling;

  Timer? _idleTimer;
  bool _isScrolling = false;

  ScrollActivityDetector({
    this.idleThreshold = const Duration(milliseconds: 1500),
    required this.onIdle,
    this.onScrolling,
  });

  /// Call this when scroll position changes
  void onScrollUpdate() {
    if (!_isScrolling) {
      _isScrolling = true;
      onScrolling?.call();
    }

    _idleTimer?.cancel();
    _idleTimer = Timer(idleThreshold, _onScrollIdle);
  }

  void _onScrollIdle() {
    _isScrolling = false;
    onIdle();
  }

  bool get isScrolling => _isScrolling;

  void dispose() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }
}

/// VAD (Voice Activity Detection) helper
/// Used to only record when speech is detected
class VoiceActivityTracker {
  final double silenceThreshold;
  final Duration minSpeechDuration;
  final Duration maxSilenceDuration;

  DateTime? _speechStartTime;
  DateTime? _lastVoiceTime;
  bool _isSpeaking = false;

  VoiceActivityTracker({
    this.silenceThreshold = 0.02, // RMS threshold
    this.minSpeechDuration = const Duration(milliseconds: 300),
    this.maxSilenceDuration = const Duration(milliseconds: 500),
  });

  /// Update with audio level (RMS 0.0 to 1.0)
  /// Returns true if we should be recording
  bool update(double audioLevel) {
    final now = DateTime.now();
    final isVoice = audioLevel > silenceThreshold;

    if (isVoice) {
      _lastVoiceTime = now;

      if (!_isSpeaking) {
        _speechStartTime = now;
        _isSpeaking = true;
      }
    } else {
      // Check if silence has been too long
      if (_isSpeaking && _lastVoiceTime != null) {
        if (now.difference(_lastVoiceTime!) > maxSilenceDuration) {
          _isSpeaking = false;
          _speechStartTime = null;
        }
      }
    }

    // Only return true if speech has been going on long enough
    if (_isSpeaking && _speechStartTime != null) {
      return now.difference(_speechStartTime!) >= minSpeechDuration;
    }

    return false;
  }

  bool get isSpeaking => _isSpeaking;

  void reset() {
    _isSpeaking = false;
    _speechStartTime = null;
    _lastVoiceTime = null;
  }
}

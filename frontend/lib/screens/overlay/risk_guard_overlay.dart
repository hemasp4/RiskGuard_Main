import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:risk_guard/core/models/analysis_models.dart';
import 'package:risk_guard/core/services/api_service.dart';
import 'package:risk_guard/core/services/native_bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _OverlaySurface { hidden, bubble, card, call }
enum _SessionKind { none, url, media, call }
enum _SessionState { dismissed, captured, verifying, ready, degraded }

class _CachedUrlVerdict {
  const _CachedUrlVerdict(this.verdict, this.cachedAt);
  final UrlVerificationResult verdict;
  final DateTime cachedAt;
  bool get isFresh =>
      DateTime.now().difference(cachedAt) < const Duration(minutes: 2);
}

class _Session {
  const _Session({
    required this.id,
    required this.kind,
    required this.state,
    required this.sourcePackage,
    required this.targetType,
    required this.target,
    required this.status,
    required this.summary,
    required this.recommendation,
    required this.intelSource,
    required this.threatType,
    required this.phoneNumber,
    required this.riskScore,
    required this.isThreat,
    required this.previewPath,
  });

  const _Session.idle()
      : id = '',
        kind = _SessionKind.none,
        state = _SessionState.dismissed,
        sourcePackage = '',
        targetType = 'URL',
        target = 'Awaiting live capture',
        status = 'MONITORING ACTIVE',
        summary = 'RiskGuard is ready to monitor whitelisted apps.',
        recommendation = 'RiskGuard will surface live verdicts here.',
        intelSource = 'LOCAL SHIELD',
        threatType = 'Shield Ready',
        phoneNumber = 'Hidden Number',
        riskScore = 0,
        isThreat = false,
        previewPath = null;

  final String id;
  final _SessionKind kind;
  final _SessionState state;
  final String sourcePackage;
  final String targetType;
  final String target;
  final String status;
  final String summary;
  final String recommendation;
  final String intelSource;
  final String threatType;
  final String phoneNumber;
  final double riskScore;
  final bool isThreat;
  final String? previewPath;

  _Session copyWith({
    String? id,
    _SessionKind? kind,
    _SessionState? state,
    String? sourcePackage,
    String? targetType,
    String? target,
    String? status,
    String? summary,
    String? recommendation,
    String? intelSource,
    String? threatType,
    String? phoneNumber,
    double? riskScore,
    bool? isThreat,
    String? previewPath,
  }) => _Session(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    state: state ?? this.state,
    sourcePackage: sourcePackage ?? this.sourcePackage,
    targetType: targetType ?? this.targetType,
    target: target ?? this.target,
    status: status ?? this.status,
    summary: summary ?? this.summary,
    recommendation: recommendation ?? this.recommendation,
    intelSource: intelSource ?? this.intelSource,
    threatType: threatType ?? this.threatType,
    phoneNumber: phoneNumber ?? this.phoneNumber,
    riskScore: riskScore ?? this.riskScore,
    isThreat: isThreat ?? this.isThreat,
    previewPath: previewPath ?? this.previewPath,
  );
}

class RiskGuardOverlay extends StatefulWidget {
  const RiskGuardOverlay({super.key});
  @override
  State<RiskGuardOverlay> createState() => _RiskGuardOverlayState();
}

class _RiskGuardOverlayState extends State<RiskGuardOverlay> {
  static const MethodChannel _channel = MethodChannel('com.example.risk_guard/overlay');
  static const double _bubbleSize = 84;
  static const double _cardWidth = 368;
  static const double _cardHeight = 328;
  static const double _callBottomSheetHeight = 432;
  final Map<String, _CachedUrlVerdict> _urlVerdicts = <String, _CachedUrlVerdict>{};
  final Set<String> _processedEventIds = <String>{};
  SharedPreferences? _prefs;
  Timer? _pollTimer;
  Timer? _dismissTimer;
  Timer? _visibilityHideTimer;
  _OverlaySurface _surface = _OverlaySurface.hidden;
  _Session _session = const _Session.idle();
  String? _foregroundPackage;
  bool _foregroundWhitelisted = false;
  String? _collapsedSessionId;
  OverlayPosition? _bubblePosition;
  OverlayPosition? _dragPosition;
  Size _viewportSize = const Size(392, 820);
  DateTime _surfacePinnedUntil = DateTime.fromMillisecondsSinceEpoch(0);

  bool get _isAnalyzing => _session.state == _SessionState.captured || _session.state == _SessionState.verifying;
  bool get _bubbleAllowed => _session.kind == _SessionKind.call || _foregroundWhitelisted;
  bool get _cardEligible =>
      (_session.kind == _SessionKind.url || _session.kind == _SessionKind.media) &&
      _foregroundWhitelisted &&
      _session.sourcePackage == _foregroundPackage &&
      _session.id.isNotEmpty;
  bool get _cardAllowed => _cardEligible && _session.id != _collapsedSessionId;
  bool get _canExpandFromBubble =>
      _session.kind == _SessionKind.call || _cardEligible || (_session.kind == _SessionKind.none && _foregroundWhitelisted);
  bool get _isSurfacePinned => DateTime.now().isBefore(_surfacePinnedUntil);

  @override
  void initState() {
    super.initState();
    _boot();
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onMessageReceived' && call.arguments is Map) {
        _applyPayload(Map<String, dynamic>.from(call.arguments as Map));
      }
    });
  }

  Future<void> _boot() async {
    _prefs = await SharedPreferences.getInstance();
    await _setSurface(_OverlaySurface.hidden);
    _schedulePoll();
  }

  void _schedulePoll() {
    _pollTimer?.cancel();
    final delay = _surface == _OverlaySurface.hidden && !_isAnalyzing && _session.kind != _SessionKind.call
        ? const Duration(milliseconds: 1300)
        : const Duration(milliseconds: 180);
    _pollTimer = Timer(delay, () async {
      await _pollQueue();
      if (mounted) _schedulePoll();
    });
  }

  Future<void> _pollQueue() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.reload();
    final raw = prefs.getString('protection_event_queue');
    if (raw == null || raw.isEmpty) return;
    final decoded = jsonDecode(raw);
    if (decoded is! List) return;
    final events = decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      ..sort((a, b) => _readInt(a['createdAtMs']).compareTo(_readInt(b['createdAtMs'])));
    for (final event in events) {
      final id = event['id']?.toString();
      if (id == null || _processedEventIds.contains(id)) continue;
      if (_readInt(event['expiresAtMs']) > 0 &&
          DateTime.now().millisecondsSinceEpoch > _readInt(event['expiresAtMs'])) {
        _remember(id);
        continue;
      }
      switch (event['kind']) {
        case 'url_capture':
          await _handleUrlEvent(event);
          break;
        case 'media_result':
          await _handleMediaEvent(event);
          break;
        case 'call_state':
          await _handleCallEvent(event);
          break;
        case 'overlay_status':
          _handleOverlayStatus(event);
          break;
      }
      _remember(id);
    }
  }

  int _readInt(Object? value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  void _remember(String id) {
    _processedEventIds.add(id);
    if (_processedEventIds.length > 120) _processedEventIds.remove(_processedEventIds.first);
  }

  void _pinSurface([Duration duration = const Duration(milliseconds: 850)]) {
    _surfacePinnedUntil = DateTime.now().add(duration);
  }

  void _cleanupPreview(String? path) {
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (!file.existsSync()) return;
    unawaited(file.delete());
  }

  String _appName(String? packageName) {
    const known = <String, String>{
      'com.android.chrome': 'Chrome',
      'com.whatsapp': 'WhatsApp',
      'org.telegram.messenger': 'Telegram',
      'com.instagram.android': 'Instagram',
      'com.facebook.katana': 'Facebook',
      'phone_service': 'Phone Service',
    };
    if (packageName == null || packageName.isEmpty) return 'Protected App';
    return known[packageName] ?? packageName.split('.').last.replaceAll('_', ' ');
  }

  Future<void> _handleUrlEvent(Map<String, dynamic> event) async {
    final id = event['id']?.toString();
    final target = event['normalizedTarget']?.toString();
    final pkg = event['sourcePackage']?.toString() ?? '';
    if (id == null || target == null || target.isEmpty) return;
    _dismissTimer?.cancel();
    _collapsedSessionId = null;
    _setSession(_Session(
      id: id,
      kind: _SessionKind.url,
      state: _SessionState.captured,
      sourcePackage: pkg,
      targetType: 'URL',
      target: target,
      status: 'CAPTURED LINK',
      summary: 'Target captured from the active monitored app. Starting verification.',
      recommendation: 'Preparing normalization and offline precheck.',
      intelSource: 'LOCAL PRECHECK',
      threatType: 'URL',
      phoneNumber: _session.phoneNumber,
      riskScore: 0.08,
      isThreat: false,
      previewPath: null,
    ));
    await _syncSurface();
    final cached = _urlVerdicts[target];
    if (cached != null && cached.isFresh) {
      if (_session.id == id) _applyVerdict(cached.verdict, pkg, true);
      return;
    }
    _setSession(_session.copyWith(
      state: _SessionState.verifying,
      status: 'CLOUD VERIFYING',
      summary: 'Comparing the target against live threat intelligence and local checks.',
      recommendation: 'Waiting for a final verdict.',
      intelSource: 'THREAT INTEL',
      riskScore: 0.16,
    ));
    await _syncSurface();
    try {
      final result = await ApiService().verifyUrl(target);
      if (!mounted || _session.id != id) return;
      if (!result.isSuccess || result.data == null) {
        _setSession(_session.copyWith(
          state: _SessionState.degraded,
          status: 'DEGRADED OFFLINE',
          summary: 'Live capture succeeded, but the backend verdict was unavailable.',
          recommendation: 'Treat this target with caution until connectivity is restored.',
          intelSource: 'OFFLINE FALLBACK',
          threatType: 'Pending',
          riskScore: 0.2,
        ));
        await _syncSurface();
        _scheduleDismiss(id);
        return;
      }
      _urlVerdicts[target] = _CachedUrlVerdict(result.data!, DateTime.now());
      _applyVerdict(result.data!, pkg, false);
    } catch (_) {
      if (!mounted || _session.id != id) return;
      _setSession(_session.copyWith(
        state: _SessionState.degraded,
        status: 'SCAN ERROR',
        summary: 'Realtime verification failed before a final verdict.',
        recommendation: 'Keep the target unopened until verification recovers.',
        intelSource: 'ERROR',
        threatType: 'Retry Needed',
        riskScore: 0.18,
      ));
      await _syncSurface();
      _scheduleDismiss(id);
    }
  }

  void _applyVerdict(UrlVerificationResult verdict, String pkg, bool fromCache) {
    final danger = verdict.status.toUpperCase().contains('DANGER') || verdict.status.toUpperCase().contains('MALICIOUS');
    final next = _session.copyWith(
      state: _SessionState.ready,
      status: 'VERDICT READY',
      sourcePackage: pkg,
      target: verdict.url.isNotEmpty ? verdict.url : _session.target,
      summary: danger ? 'Threat indicators were found for this destination.' : 'No known malicious indicators were found for this destination.',
      recommendation: verdict.recommendation,
      intelSource: verdict.intelligenceSource.isNotEmpty ? verdict.intelligenceSource.toUpperCase() : (fromCache ? 'LOCAL CACHE' : 'THREAT INTEL'),
      threatType: verdict.threatType.isNotEmpty ? verdict.threatType : 'URL',
      riskScore: (verdict.riskScore / 100).clamp(0.0, 1.0).toDouble(),
      isThreat: danger,
    );
    _setSession(next);
    unawaited(_syncSurface());
    _scheduleDismiss(next.id);
  }

  Future<void> _handleMediaEvent(Map<String, dynamic> event) async {
    if (_session.kind == _SessionKind.call) return;
    final payload = event['payload'];
    if (payload is Map) {
      final mediaPayload = Map<String, dynamic>.from(payload);
      if (mediaPayload['localFramePath'] != null) {
        await _handleCapturedFramePayload(
          mediaPayload,
          fallbackSessionId: event['sessionId']?.toString() ?? event['id']?.toString(),
        );
        return;
      }
      _applyPayload(mediaPayload);
    }
  }

  Future<void> _handleCapturedFramePayload(
    Map<String, dynamic> payload, {
    String? fallbackSessionId,
  }) async {
    final String framePath = payload['localFramePath']?.toString() ?? '';
    final String sessionId =
        payload['sessionId']?.toString() ??
        payload['requestId']?.toString() ??
        fallbackSessionId ??
        'media-${DateTime.now().millisecondsSinceEpoch}';
    final String sourcePackage =
        payload['sourcePackage']?.toString() ??
        payload['source']?.toString() ??
        _foregroundPackage ??
        _session.sourcePackage;

    if (_session.kind == _SessionKind.url &&
        _session.sourcePackage == sourcePackage &&
        _session.id.isNotEmpty) {
      return;
    }

    if (_session.kind == _SessionKind.media &&
        _isAnalyzing &&
        _session.sourcePackage == sourcePackage) {
      return;
    }

    if (sourcePackage.isNotEmpty &&
        _foregroundPackage != null &&
        sourcePackage != _foregroundPackage) {
      return;
    }

    final File frameFile = File(framePath);
    if (framePath.isEmpty) {
      return;
    }
    _dismissTimer?.cancel();
    _collapsedSessionId = null;
    _pinSurface(const Duration(milliseconds: 1200));
    _setSession(
      _Session(
        id: sessionId,
        kind: _SessionKind.media,
        state: _SessionState.captured,
        sourcePackage: sourcePackage,
        targetType: 'SCREEN FRAME',
        target: payload['targetLabel']?.toString() ?? 'Live screen media',
        status: 'CAPTURED FRAME',
        summary:
            'Captured the current visible screen from the monitored app. Starting deepfake verification.',
        recommendation:
            'Keep the current screen visible while RiskGuard completes the first-pass media verdict.',
        intelSource: 'SCREEN CAPTURE',
        threatType: 'Screen Media',
        phoneNumber: _session.phoneNumber,
        riskScore: 0.12,
        isThreat: false,
        previewPath: framePath,
      ),
    );
    await _syncSurface();

    if (!await frameFile.exists()) {
      _setSession(
        _session.copyWith(
          state: _SessionState.degraded,
          status: 'CAPTURE ERROR',
          summary: 'The captured frame was no longer available for analysis.',
          recommendation:
              'Keep the source visible and wait for the next capture cycle.',
          intelSource: 'SCREEN CAPTURE',
          riskScore: 0.15,
        ),
      );
      await _syncSurface();
      _scheduleDismiss(sessionId);
      return;
    }

    try {
      final bytes = await frameFile.readAsBytes();
      if (!mounted || _session.id != sessionId) return;

      _setSession(
        _session.copyWith(
          state: _SessionState.verifying,
          status: 'ANALYZING FRAME',
          summary:
              'Running image-based deepfake analysis on the current screen frame.',
          recommendation: 'Waiting for a final screen-media verdict.',
          intelSource: 'LIVE MEDIA',
          riskScore: 0.18,
        ),
      );
      await _syncSurface();

      final result = await ApiService().analyzeImage(
        bytes,
        filename: frameFile.uri.pathSegments.isNotEmpty
            ? frameFile.uri.pathSegments.last
            : 'screen_frame.jpg',
      );
      if (!mounted || _session.id != sessionId) return;

      if (!result.isSuccess || result.data == null) {
        _setSession(
          _session.copyWith(
            state: _SessionState.degraded,
            status: 'MEDIA BACKEND UNAVAILABLE',
            summary:
                'Screen capture succeeded, but the backend did not return a media verdict.',
            recommendation:
                'RiskGuard will continue capturing new frames while connectivity recovers.',
            intelSource: 'OFFLINE / DEGRADED',
            threatType: 'Screen Media',
            riskScore: 0.2,
          ),
        );
        await _syncSurface();
        _scheduleDismiss(sessionId);
        return;
      }

      final analysis = result.data!;
      final probability = analysis.aiGeneratedProbability > 1
          ? analysis.aiGeneratedProbability / 100
          : analysis.aiGeneratedProbability;
      final isThreat = analysis.isAiGenerated || probability >= 0.65;

      _setSession(
        _session.copyWith(
          state: _SessionState.ready,
          status: 'FRAME VERDICT READY',
          summary: analysis.explanation.isNotEmpty
              ? analysis.explanation
              : (isThreat
                    ? 'Potential deepfake indicators were found in the visible media.'
                    : 'No strong deepfake indicators were found in the visible media.'),
          recommendation: isThreat
              ? 'Treat this media as untrusted until you verify the source.'
              : 'No immediate deepfake risk was detected from this captured frame.',
          intelSource: analysis.analysisMethod.toUpperCase(),
          threatType: analysis.modelUsed.isNotEmpty
              ? analysis.modelUsed
              : 'Screen Media',
          riskScore: probability.clamp(0.0, 1.0),
          isThreat: isThreat,
        ),
      );
      await _syncSurface();
      _scheduleDismiss(sessionId);
    } catch (_) {
      if (!mounted || _session.id != sessionId) return;
      _setSession(
        _session.copyWith(
          state: _SessionState.degraded,
          status: 'FRAME ANALYSIS ERROR',
          summary: 'Captured media could not be analyzed successfully.',
          recommendation:
              'RiskGuard will wait for the next valid frame capture from this app.',
          intelSource: 'ERROR',
          riskScore: 0.18,
        ),
      );
      await _syncSurface();
      _scheduleDismiss(sessionId);
    }
  }

  Future<void> _handleCallEvent(Map<String, dynamic> event) async {
    final state = (event['callState']?.toString() ?? event['normalizedTarget']?.toString() ?? '').toUpperCase();
    if (state.isEmpty) return;
    if (state == 'IDLE') {
      await _clearSession();
      return;
    }
    final number = event['phoneNumber']?.toString();
    _dismissTimer?.cancel();
    _collapsedSessionId = null;
    _setSession(_Session(
      id: event['id']?.toString() ?? 'call-${DateTime.now().millisecondsSinceEpoch}',
      kind: _SessionKind.call,
      state: _SessionState.verifying,
      sourcePackage: 'phone_service',
      targetType: 'VOICE',
      target: number?.isNotEmpty == true ? number! : _session.target,
      status: state == 'RINGING' ? 'INCOMING CALL ANALYSIS' : 'VOICE STREAM',
      summary: state == 'RINGING' ? 'Preparing the live caller profile before the call is answered.' : 'Monitoring the live voice stream while the call continues.',
      recommendation: 'Use the native call controls for keypad, hold, merge, and conference actions.',
      intelSource: 'VOICE STREAM',
      threatType: 'VOICE',
      phoneNumber: number?.isNotEmpty == true ? number! : _session.phoneNumber,
      riskScore: 0,
      isThreat: false,
      previewPath: null,
    ));
    await _syncSurface();
  }

  void _handleOverlayStatus(Map<String, dynamic> event) {
    final payload = event['payload'];
    if (event['targetType'] == 'visibility' && payload is Map) {
      final visibility = Map<String, dynamic>.from(payload);
      final packageName = visibility['packageName']?.toString();
      final visible = visibility['visible'] == true;
      _visibilityHideTimer?.cancel();
      if (visible) {
        _foregroundPackage = packageName;
        _foregroundWhitelisted = true;
        unawaited(_syncSurface());
      } else {
        _visibilityHideTimer = Timer(const Duration(milliseconds: 520), () async {
          _foregroundPackage = packageName;
          _foregroundWhitelisted = false;
          await _syncSurface();
        });
      }
      return;
    }
    if (payload is Map) _applyPayload(Map<String, dynamic>.from(payload));
  }

  void _applyPayload(Map<String, dynamic> payload) {
    final rawKind = (payload['sessionKind']?.toString() ?? payload['kind']?.toString() ?? '').toLowerCase();
    final targetType = (payload['targetType']?.toString() ?? '').toLowerCase();
    final sourcePackage =
        payload['sourcePackage']?.toString() ??
        payload['source']?.toString() ??
        _session.sourcePackage;
    final isCall =
        payload['isCallActive'] == true ||
        rawKind == 'call' ||
        sourcePackage == 'phone_service' ||
        payload.containsKey('callState');
    if (isCall && ((payload['status']?.toString().toUpperCase() == 'CALL ENDED') || payload['isCallActive'] == false)) {
      unawaited(_clearSession());
      return;
    }
    final kind = isCall
        ? _SessionKind.call
        : (rawKind == 'media' ||
                  targetType == 'image' ||
                  targetType == 'video' ||
                  targetType == 'text' ||
                  targetType == 'voice')
            ? _SessionKind.media
            : _SessionKind.url;
    final status = (payload['status']?.toString() ?? _session.status).toUpperCase();
    final rawScore = payload['riskScore'] ?? payload['score'];
    final score = rawScore is num
        ? ((rawScore.toDouble() > 1) ? rawScore.toDouble() / 100 : rawScore.toDouble()).clamp(0.0, 1.0)
        : _session.riskScore;
    if (!isCall &&
        sourcePackage.isNotEmpty &&
        _foregroundPackage != null &&
        _foregroundPackage != sourcePackage &&
        sourcePackage != 'com.example.risk_guard') {
      return;
    }
    final next = _Session(
      id: payload['sessionId']?.toString() ?? payload['requestId']?.toString() ?? '${kind.name}-${DateTime.now().millisecondsSinceEpoch}',
      kind: kind,
      state: status.contains('VERIFY') || status.contains('ANALYZ') ? _SessionState.verifying : (status.contains('ERROR') || status.contains('DEGRADE') ? _SessionState.degraded : _SessionState.ready),
      sourcePackage: sourcePackage,
      targetType: (payload['targetType']?.toString() ?? _session.targetType).toUpperCase(),
      target: payload['targetLabel']?.toString() ?? payload['url']?.toString() ?? payload['target']?.toString() ?? _session.target,
      status: status,
      summary: payload['threatText']?.toString() ?? payload['summary']?.toString() ?? _session.summary,
      recommendation: payload['recommendation']?.toString() ?? _session.recommendation,
      intelSource: (payload['analysisSource']?.toString() ?? payload['intelSource']?.toString() ?? _session.intelSource).toUpperCase(),
      threatType: payload['threatType']?.toString() ?? _session.threatType,
      phoneNumber: payload['phoneNumber']?.toString() ?? _session.phoneNumber,
      riskScore: score,
      isThreat: payload['isThreat'] == true || status.contains('DANGER') || status.contains('MALICIOUS'),
      previewPath: payload['previewPath']?.toString() ?? payload['localFramePath']?.toString() ?? _session.previewPath,
    );
    _setSession(next);
    unawaited(_syncSurface());
    if (next.kind != _SessionKind.call && !_isAnalyzing) _scheduleDismiss(next.id);
  }

  void _scheduleDismiss(String sessionId) {
    _dismissTimer?.cancel();
    _dismissTimer = Timer(const Duration(seconds: 4), () async {
      if (!mounted || _session.id != sessionId || _isAnalyzing || _session.kind == _SessionKind.call) return;
      await _clearSession();
    });
  }

  Future<void> _clearSession() async {
    _dismissTimer?.cancel();
    _collapsedSessionId = null;
    _setSession(const _Session.idle());
    await _syncSurface();
  }

  void _setSession(_Session next) {
    if (_collapsedSessionId != null && _collapsedSessionId != next.id) {
      _collapsedSessionId = null;
    }
    final previousPreview = _session.previewPath;
    final nextPreview = next.previewPath;
    if (mounted) {
      setState(() => _session = next);
    } else {
      _session = next;
    }
    if (previousPreview != null &&
        previousPreview.isNotEmpty &&
        previousPreview != nextPreview) {
      _cleanupPreview(previousPreview);
    }
  }

  Future<void> _syncSurface() async {
    final desired = _session.kind == _SessionKind.call
        ? _OverlaySurface.call
        : (_cardAllowed ? _OverlaySurface.card : (_bubbleAllowed ? _OverlaySurface.bubble : _OverlaySurface.hidden));

    if (_isSurfacePinned &&
        _surface == _OverlaySurface.card &&
        desired != _OverlaySurface.call) {
      return;
    }
    return _setSurface(desired);
  }

  Future<void> _rememberBubblePosition() async {
    try {
      _bubblePosition = await FlutterOverlayWindow.getOverlayPosition();
    } catch (_) {}
  }

  OverlayPosition _defaultBubblePosition() {
    final double maxX = math.max(12.0, _viewportSize.width - _bubbleSize - 12).toDouble();
    final double maxY = math.max(120.0, _viewportSize.height - _bubbleSize - 24).toDouble();
    final double x = maxX;
    final y = (_viewportSize.height * 0.34).clamp(120.0, maxY).toDouble();
    return OverlayPosition(x, y);
  }

  OverlayPosition _centeredPosition(double width, double height, {double topBias = 0}) {
    final double maxX = math.max(12.0, _viewportSize.width - width - 12).toDouble();
    final double maxY = math.max(24.0, _viewportSize.height - height - 24).toDouble();
    final x = (((_viewportSize.width - width) / 2) + 0).clamp(12.0, maxX).toDouble();
    final y = (((_viewportSize.height - height) / 2) + topBias).clamp(24.0, maxY).toDouble();
    return OverlayPosition(x, y);
  }

  Future<void> _restoreBubblePosition() async {
    try {
      await FlutterOverlayWindow.moveOverlay(_bubblePosition ?? _defaultBubblePosition());
    } catch (_) {}
  }

  OverlayPosition _clampBubblePosition(OverlayPosition position) {
    final double maxX =
        math.max(12.0, _viewportSize.width - _bubbleSize - 12).toDouble();
    final double maxY =
        math.max(120.0, _viewportSize.height - _bubbleSize - 24).toDouble();
    return OverlayPosition(
      position.x.clamp(12.0, maxX).toDouble(),
      position.y.clamp(120.0, maxY).toDouble(),
    );
  }

  Future<void> _beginBubbleDrag() async {
    try {
      final current = await FlutterOverlayWindow.getOverlayPosition();
      _dragPosition = _clampBubblePosition(current);
    } catch (_) {
      _dragPosition = _bubblePosition ?? _defaultBubblePosition();
    }
  }

  Future<void> _updateBubbleDrag(DragUpdateDetails details) async {
    final current = _dragPosition ?? _bubblePosition ?? _defaultBubblePosition();
    final next = _clampBubblePosition(
      OverlayPosition(
        current.x + details.delta.dx,
        current.y + details.delta.dy,
      ),
    );
    _dragPosition = next;
    _bubblePosition = next;
    try {
      await FlutterOverlayWindow.moveOverlay(next);
    } catch (_) {}
  }

  void _endBubbleDrag() {
    final position = _dragPosition ?? _bubblePosition;
    if (position != null) {
      final double rightX =
          math.max(12.0, _viewportSize.width - _bubbleSize - 12).toDouble();
      final double snappedX =
          position.x < (_viewportSize.width / 2) ? 12.0 : rightX;
      final snapped = _clampBubblePosition(
        OverlayPosition(snappedX, position.y),
      );
      _bubblePosition = snapped;
      unawaited(FlutterOverlayWindow.moveOverlay(snapped));
    }
    _dragPosition = null;
  }

  Future<void> _moveCardToCenter() async {
    final double width = math.max(
      280.0,
      _viewportSize.width < 420 ? _viewportSize.width - 24 : _cardWidth,
    ).toDouble();
    try {
      await FlutterOverlayWindow.moveOverlay(_centeredPosition(width, _cardHeight));
    } catch (_) {}
  }

  Future<void> _moveCallToAnchor() async {
    final double callWidth = math.min(_viewportSize.width - 24, 364).toDouble();
    final double callHeight = math.min(_viewportSize.height - 80, 388).toDouble();
    try {
      await FlutterOverlayWindow.moveOverlay(
        _centeredPosition(callWidth, callHeight, topBias: -28),
      );
    } catch (_) {}
  }

  Future<void> _expandFromBubble() async {
    await _rememberBubblePosition();
    _collapsedSessionId = null;
    _pinSurface(const Duration(seconds: 2));
    if (_session.kind == _SessionKind.none && _foregroundWhitelisted) {
      _setSession(
        _session.copyWith(
          sourcePackage: _foregroundPackage ?? '',
          targetType: 'LIVE',
          target: _appName(_foregroundPackage),
          status: 'MONITORING CURRENT APP',
          summary:
              'RiskGuard is armed for the current whitelisted app and will surface the next supported realtime verdict here.',
          recommendation:
              'Open a visible link or supported analysis source to trigger a fresh result.',
          intelSource: 'LIVE MONITOR',
          threatType: 'Realtime Watch',
        ),
      );
      if (_foregroundPackage != null && _foregroundPackage!.isNotEmpty) {
        unawaited(
          NativeBridge.requestRealtimeMediaCapture(
            sourcePackage: _foregroundPackage,
            reason: 'bubble_expand',
          ),
        );
      }
    }
    await _setSurface(_session.kind == _SessionKind.call ? _OverlaySurface.call : _OverlaySurface.card);
  }

  Future<void> _setSurface(_OverlaySurface next) async {
    final sameSurface = _surface == next;
    if (mounted) {
      setState(() => _surface = next);
    } else {
      _surface = next;
    }

    if (sameSurface) {
      if (next == _OverlaySurface.card) {
        await _moveCardToCenter();
      } else if (next == _OverlaySurface.call) {
        await _moveCallToAnchor();
      }
      return;
    }

    switch (next) {
      case _OverlaySurface.hidden: {
        await FlutterOverlayWindow.updateFlag(OverlayFlag.defaultFlag);
        await FlutterOverlayWindow.resizeOverlay(1, 1, false);
        break;
      }
      case _OverlaySurface.bubble: {
        await FlutterOverlayWindow.updateFlag(OverlayFlag.defaultFlag);
        await FlutterOverlayWindow.resizeOverlay(_bubbleSize.toInt(), _bubbleSize.toInt(), true);
        await Future<void>.delayed(const Duration(milliseconds: 40));
        await _restoreBubblePosition();
        break;
      }
      case _OverlaySurface.card: {
        final double cardWidth = math.max(
          280.0,
          _viewportSize.width < 420 ? _viewportSize.width - 24 : _cardWidth,
        ).toDouble();
        await FlutterOverlayWindow.updateFlag(OverlayFlag.focusPointer);
        await FlutterOverlayWindow.resizeOverlay(
          cardWidth.toInt(),
          _cardHeight.toInt(),
          false,
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));
        await _moveCardToCenter();
        break;
      }
      case _OverlaySurface.call: {
        final double callWidth = math.min(_viewportSize.width - 24, 364).toDouble();
        final double callHeight = math.min(_viewportSize.height - 80, 388).toDouble();
        await FlutterOverlayWindow.updateFlag(OverlayFlag.focusPointer);
        await FlutterOverlayWindow.resizeOverlay(
          callWidth.toInt(),
          callHeight.toInt(),
          false,
        );
        await Future<void>.delayed(const Duration(milliseconds: 40));
        await _moveCallToAnchor();
        break;
      }
    }
    _schedulePoll();
  }

  Future<void> _minimize() async {
    if (_session.kind == _SessionKind.url || _session.kind == _SessionKind.media) {
      _collapsedSessionId = _session.id;
    }
    await _rememberBubblePosition();
    await _setSurface(_bubbleAllowed ? _OverlaySurface.bubble : _OverlaySurface.hidden);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _dismissTimer?.cancel();
    _visibilityHideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final view = View.of(context);
    _viewportSize = Size(
      view.display.size.width / view.display.devicePixelRatio,
      view.display.size.height / view.display.devicePixelRatio,
    );
    if (_surface == _OverlaySurface.hidden) {
      return const Material(color: Colors.transparent, child: SizedBox.shrink());
    }
    return Material(
      color: Colors.transparent,
      child: _surface == _OverlaySurface.call ? _buildCall() : (_surface == _OverlaySurface.bubble ? _buildBubble() : _buildCard()),
    );
  }

  Widget _buildBubble() {
    final accent = _session.isThreat ? Colors.redAccent : Colors.cyanAccent;
    final canExpand = _canExpandFromBubble;
    final previewPath = _session.previewPath;
    final hasPreview =
        _session.kind == _SessionKind.media &&
        previewPath != null &&
        previewPath.isNotEmpty &&
        File(previewPath).existsSync();
    return GestureDetector(
      onTap: canExpand ? _expandFromBubble : null,
      onPanStart: (_) => unawaited(_beginBubbleDrag()),
      onPanUpdate: (details) => unawaited(_updateBubbleDrag(details)),
      onPanEnd: (_) => _endBubbleDrag(),
      onPanCancel: _endBubbleDrag,
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF071120).withOpacity(0.96),
          shape: BoxShape.circle,
          border: Border.all(color: accent.withOpacity(0.75), width: 2),
          boxShadow: [BoxShadow(color: accent.withOpacity(0.22), blurRadius: 18)],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (hasPreview)
              ClipOval(
                child: SizedBox.expand(
                  child: Image.file(
                    File(previewPath),
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.low,
                  ),
                ),
              )
            else
              Icon(_session.isThreat ? Icons.warning_rounded : Icons.shield_rounded, color: accent, size: 28),
            if (hasPreview)
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.32),
                ),
              ),
            if (hasPreview)
              Icon(
                _session.isThreat ? Icons.warning_rounded : Icons.photo_camera_back_rounded,
                color: Colors.white,
                size: 20,
              ),
            Positioned(bottom: 16, child: Container(width: 10, height: 10, decoration: BoxDecoration(color: _isAnalyzing ? Colors.orangeAccent : accent, shape: BoxShape.circle))),
          ],
        ),
      ),
    );
  }

  Widget _buildCard() {
    final accent = _session.isThreat ? Colors.redAccent : Colors.cyanAccent;
    return SafeArea(
      child: Center(
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(colors: [const Color(0xFF08111D).withOpacity(0.97), const Color(0xFF0F172A).withOpacity(0.97)]),
            border: Border.all(color: accent.withOpacity(0.34), width: 1.5),
            boxShadow: [BoxShadow(color: accent.withOpacity(0.18), blurRadius: 28)],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(radius: 22, backgroundColor: accent.withOpacity(0.14), child: Icon(_session.isThreat ? Icons.gpp_bad_rounded : Icons.gpp_good_rounded, color: accent)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('RISKGUARD PROACTIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.8)),
                Text(_appName(_session.sourcePackage), style: TextStyle(color: Colors.white.withOpacity(0.58), fontSize: 12)),
              ])),
              IconButton(onPressed: _minimize, icon: const Icon(Icons.remove_rounded, color: Colors.white70)),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [_pill(_isAnalyzing ? 'VERIFYING' : (_session.isThreat ? 'DANGER' : 'SAFE'), accent), _pill(_session.targetType, Colors.white70), _pill(_session.intelSource, Colors.orangeAccent)]),
            const SizedBox(height: 14),
            if (_session.kind == _SessionKind.media && _session.previewPath != null) ...[
              _buildMediaPreview(_session.previewPath!, accent),
              const SizedBox(height: 12),
            ],
            _info('Captured target', _session.target),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: _isAnalyzing ? null : (_session.riskScore > 0 ? _session.riskScore : 0.04), backgroundColor: Colors.white12, color: accent, minHeight: 8, borderRadius: BorderRadius.circular(999)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: Text(_session.status, style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 13))),
              Text('${(_session.riskScore * 100).round()}% score', style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 12),
            _info(_session.threatType, _session.summary, footer: _session.recommendation),
          ]),
        ),
      ),
    );
  }

  Widget _buildCall() {
    final accent = _session.riskScore >= 0.65 ? Colors.redAccent : Colors.cyanAccent;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xF20A1320), Color(0xF20E1A28)],
        ),
        border: Border.all(color: accent.withOpacity(0.28), width: 1.4),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.32), blurRadius: 24),
          BoxShadow(color: accent.withOpacity(0.12), blurRadius: 18),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _pill('HYBRID CALL COMPANION', accent),
              const Spacer(),
              IconButton(
                onPressed: _minimize,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: accent.withOpacity(0.14),
                child: Icon(
                  Icons.person_rounded,
                  size: 30,
                  color: Colors.white.withOpacity(0.86),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Active Caller',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _session.phoneNumber,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _session.status,
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _info(
                  'Deepfake probability',
                  '${(_session.riskScore * 100).round()}%',
                  accent: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _info(
                  'Control path',
                  'Use the native call UI for answer, keypad, hold, merge, and conference controls.',
                  accent: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _info(
            'Realtime Voice Verdict',
            _session.summary,
            footer: _session.recommendation,
            accent: accent,
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: _isAnalyzing ? null : (_session.riskScore > 0 ? _session.riskScore : 0.04),
            backgroundColor: Colors.white10,
            color: accent,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _minimize,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(0.18)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.minimize_rounded),
              label: const Text('Minimize Call Companion'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPreview(String previewPath, Color accent) {
    final file = File(previewPath);
    return Container(
      height: 108,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withOpacity(0.22)),
        color: Colors.white.withOpacity(0.05),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (file.existsSync())
              Image.file(
                file,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low,
              )
            else
              Container(color: const Color(0xFF0B1624)),
            Positioned(
              left: 10,
              top: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.48),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'LIVE FRAME',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withOpacity(0.24))),
    child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
  );

  Widget _info(String title, String body, {String? footer, Color? accent, bool expand = false}) {
    final child = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: (accent ?? Colors.white).withOpacity(0.08), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(0.08))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, children: [
        Text(title, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Text(body, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, height: 1.35)),
        if (footer != null) ...[
          const SizedBox(height: 8),
          Text(footer, style: TextStyle(color: Colors.white.withOpacity(0.68), fontSize: 12, height: 1.35)),
        ],
      ]),
    );
    return expand ? Expanded(child: child) : child;
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:risk_guard/core/models/analysis_models.dart';
import 'package:risk_guard/core/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _OverlaySurface {
  bubble,
  card,
  call,
}

class _CachedUrlVerdict {
  const _CachedUrlVerdict({
    required this.verdict,
    required this.cachedAt,
  });

  final UrlVerificationResult verdict;
  final DateTime cachedAt;

  bool get isFresh =>
      DateTime.now().difference(cachedAt) < const Duration(minutes: 2);
}

class RiskGuardOverlay extends StatefulWidget {
  const RiskGuardOverlay({super.key});

  @override
  State<RiskGuardOverlay> createState() => _RiskGuardOverlayState();
}

class _RiskGuardOverlayState extends State<RiskGuardOverlay> {
  static const _channel = MethodChannel('com.example.risk_guard/overlay');
  static const Duration _pollingInterval = Duration(milliseconds: 900);
  static const int _bubbleSize = 84;
  static const int _cardWidth = 360;
  static const int _cardHeight = 300;

  Timer? _pollingTimer;
  SharedPreferences? _prefs;
  final Map<String, _CachedUrlVerdict> _urlVerdicts =
      <String, _CachedUrlVerdict>{};

  int _lastProcessedUrlTime = 0;
  int _lastProcessedCallTime = 0;
  int _lastProcessedPayloadTime = 0;

  String _status = 'MONITORING ACTIVE';
  String _threatText = 'RiskGuard is ready to monitor live content.';
  String _lastThreatType = 'Shield Ready';
  String _phoneNumber = 'Hidden Number';
  String _callMessage = 'Listening for suspicious voice patterns.';
  String _sourceApp = 'Protected Apps';
  String _scannedUrl = 'Awaiting live capture';
  String _recommendation =
      'Open a link or start a call to begin realtime analysis.';
  String _intelSource = 'LOCAL SHIELD';
  double _riskScore = 0.0;
  bool _isThreat = false;
  bool _isCallActive = false;
  bool _isMinimized = true;
  bool _isAnalyzing = false;
  _OverlaySurface _surface = _OverlaySurface.bubble;

  @override
  void initState() {
    super.initState();
    _initializeOverlay();
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onMessageReceived') {
        _applyOverlayPayload(Map<String, dynamic>.from(call.arguments));
      }
    });
  }

  Future<void> _initializeOverlay() async {
    _prefs = await SharedPreferences.getInstance();
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(_pollingInterval, (_) async {
      try {
        final prefs = _prefs;
        if (prefs == null) return;

        await prefs.reload();

        if (prefs.getString('trigger_overlay') == 'true') {
          await prefs.setString('trigger_overlay', 'false');
        }

        final urlTime = _readNativeTimestamp(prefs.get('latest_proactive_time'));
        if (urlTime > _lastProcessedUrlTime) {
          _lastProcessedUrlTime = urlTime;
          final url = _normalizeUrl(prefs.getString('latest_proactive_url'));
          if (url != null) {
            await _handleProactiveUrl(
              url,
              prefs.getString('latest_proactive_pkg'),
            );
          }
        }

        final callTime = _readNativeTimestamp(prefs.get('latest_call_time'));
        if (callTime > _lastProcessedCallTime) {
          _lastProcessedCallTime = callTime;
          final state = prefs.getString('latest_call_state');
          if (state != null) {
            await _handleCallState(state, prefs.getString('latest_call_number'));
          }
        }

        final payloadTime = _readNativeTimestamp(
          prefs.get('latest_overlay_payload_time'),
        );
        if (payloadTime > _lastProcessedPayloadTime) {
          _lastProcessedPayloadTime = payloadTime;
          final rawPayload = prefs.getString('latest_overlay_payload');
          if (rawPayload != null && rawPayload.isNotEmpty) {
            final decoded = jsonDecode(rawPayload);
            if (decoded is Map<String, dynamic>) {
              _applyOverlayPayload(decoded);
            } else if (decoded is Map) {
              _applyOverlayPayload(Map<String, dynamic>.from(decoded));
            }
          }
        }
      } catch (e) {
        debugPrint('Overlay polling error: $e');
      }
    });
  }

  int _readNativeTimestamp(Object? rawValue) {
    if (rawValue is int) return rawValue;
    if (rawValue is double) return rawValue.toInt();
    return 0;
  }

  double _readRiskScore(Object? rawValue) {
    if (rawValue is num) {
      final normalized = rawValue > 1
          ? rawValue.toDouble() / 100
          : rawValue.toDouble();
      return normalized.clamp(0.0, 1.0).toDouble();
    }
    return _riskScore;
  }

  String? _normalizeUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    final trimmed =
        rawUrl.trim().replaceAll(RegExp(r'[\]\)\}\>,;:.]+$'), '');
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return 'https://$trimmed';
  }

  String _prettyPackageName(String? packageName) {
    if (packageName == null || packageName.isEmpty) {
      return 'Protected App';
    }

    const knownNames = <String, String>{
      'com.android.chrome': 'Chrome',
      'com.whatsapp': 'WhatsApp',
      'org.telegram.messenger': 'Telegram',
      'com.instagram.android': 'Instagram',
      'com.facebook.katana': 'Facebook',
      'com.google.android.dialer': 'Phone',
    };

    if (knownNames.containsKey(packageName)) {
      return knownNames[packageName]!;
    }

    final leaf = packageName.split('.').last.replaceAll('_', ' ');
    if (leaf.isEmpty) return packageName;
    return leaf[0].toUpperCase() + leaf.substring(1);
  }

  String _formatUrl(String url) {
    if (url.length <= 54) return url;
    return '${url.substring(0, 28)}...${url.substring(url.length - 20)}';
  }

  bool _isDangerStatus(String status) {
    final normalized = status.toUpperCase();
    return normalized.contains('DANGER') ||
        normalized.contains('MALICIOUS') ||
        normalized.contains('RISK') ||
        normalized.contains('BLOCK');
  }

  void _cleanupVerdictCache() {
    _urlVerdicts.removeWhere((_, cached) => !cached.isFresh);
  }

  Future<void> _handleProactiveUrl(String url, String? packageName) async {
    _cleanupVerdictCache();

    if (mounted) {
      setState(() {
        _sourceApp = _prettyPackageName(packageName);
        _scannedUrl = url;
        _status = 'CAPTURED LINK';
        _threatText =
            'Preparing a live verdict for the captured destination.';
        _recommendation = 'Normalizing the link before threat verification.';
        _intelSource = 'LOCAL SHIELD';
        _lastThreatType = 'Link Scan';
        _riskScore = 0.08;
        _isThreat = false;
        _isCallActive = false;
        _isMinimized = false;
        _isAnalyzing = true;
      });
    }
    await _setSurface(_OverlaySurface.card);

    final cached = _urlVerdicts[url];
    if (cached != null && cached.isFresh) {
      _applyUrlVerdict(
        cached.verdict,
        packageName: packageName,
        fromCache: true,
      );
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;

    setState(() {
      _status = 'VERIFYING URL';
      _threatText =
          'Checking live phishing, malware, and reputation signals.';
      _recommendation =
          'Hold while the backend returns the final classification.';
      _intelSource = 'BACKEND PENDING';
      _riskScore = 0.16;
    });

    try {
      final result = await ApiService().verifyUrl(url);
      if (!mounted) return;

      if (!result.isSuccess || result.data == null) {
        setState(() {
          _status = 'BACKEND UNAVAILABLE';
          _threatText =
              'Live capture succeeded, but the verdict service did not respond.';
          _recommendation =
              'Check backend connectivity. The link was captured, but no final verdict is available yet.';
          _intelSource = 'OFFLINE FALLBACK';
          _lastThreatType = 'Pending';
          _riskScore = 0.0;
          _isThreat = false;
          _isAnalyzing = false;
        });
        return;
      }

      _urlVerdicts[url] = _CachedUrlVerdict(
        verdict: result.data!,
        cachedAt: DateTime.now(),
      );
      _applyUrlVerdict(result.data!, packageName: packageName);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'SCAN ERROR';
        _threatText =
            'Realtime verification failed before the final verdict was returned.';
        _recommendation =
            'Keep the link unopened until backend connectivity is restored.';
        _intelSource = 'ERROR';
        _lastThreatType = 'Retry Needed';
        _riskScore = 0.0;
        _isThreat = false;
        _isAnalyzing = false;
      });
      debugPrint('Overlay URL verification failed: $e');
    }
  }

  void _applyUrlVerdict(
    UrlVerificationResult verdict, {
    String? packageName,
    bool fromCache = false,
  }) {
    final isDanger = _isDangerStatus(verdict.status);
    final normalizedScore =
        (verdict.riskScore / 100).clamp(0.0, 1.0).toDouble();

    if (!mounted) return;
    setState(() {
      _sourceApp = _prettyPackageName(packageName) == 'Protected App'
          ? _sourceApp
          : _prettyPackageName(packageName);
      _scannedUrl = verdict.url.isNotEmpty ? verdict.url : _scannedUrl;
      _status = isDanger
          ? 'DANGER DETECTED'
          : (fromCache ? 'RECENT RESULT' : 'LINK VERIFIED');
      _threatText = isDanger
          ? 'Threat indicators were detected for this destination.'
          : 'No known malicious indicators were found for this destination.';
      _recommendation = verdict.recommendation.isNotEmpty
          ? verdict.recommendation
          : (isDanger
              ? 'Do not open this link until the threat is reviewed.'
              : 'You can proceed, but keep normal caution.');
      _intelSource = verdict.intelligenceSource.isNotEmpty
          ? verdict.intelligenceSource.toUpperCase()
          : (fromCache ? 'LOCAL CACHE' : 'THREAT INTEL');
      _lastThreatType = verdict.threatType.isNotEmpty
          ? verdict.threatType
          : (isDanger ? 'Threat' : 'Safe');
      _riskScore = normalizedScore;
      _isThreat = isDanger;
      _isAnalyzing = false;
      _isCallActive = false;
      _isMinimized = false;
    });
  }

  Future<void> _handleCallState(String state, String? number) async {
    if (state == 'RINGING' || state == 'OFFHOOK') {
      if (mounted) {
        setState(() {
          _status = state == 'RINGING'
              ? 'INCOMING CALL ANALYSIS'
              : 'VOICE ANALYSIS ACTIVE';
          _isCallActive = true;
          _phoneNumber = (number != null && number.isNotEmpty)
              ? number
              : _phoneNumber;
          _callMessage = state == 'RINGING'
              ? 'Preparing a live voice profile before the call is answered.'
              : 'Collecting live voice features and updating the deepfake probability.';
          _sourceApp = 'Phone Service';
          _recommendation =
              'Keep the conversation going while RiskGuard monitors the caller in the background.';
          _intelSource = 'VOICE STREAM';
          _isThreat = false;
          _riskScore = 0.0;
          _isAnalyzing = true;
          _isMinimized = false;
        });
      }
      await _setSurface(_OverlaySurface.call);
      return;
    }

    if (state == 'IDLE') {
      if (mounted) {
        setState(() {
          _status = 'CALL ENDED';
          _callMessage = 'Call monitoring ended.';
          _isCallActive = false;
          _isAnalyzing = false;
          _isMinimized = true;
        });
      }
      await _setSurface(_OverlaySurface.bubble);
    }
  }

  void _applyOverlayPayload(Map<String, dynamic> payload) {
    final incomingStatus = payload['status']?.toString();
    final incomingThreatText = payload['threatText']?.toString();
    final incomingRecommendation = payload['recommendation']?.toString();
    final incomingSource = payload['source']?.toString();
    final incomingUrl = payload['url']?.toString();
    final incomingIntelSource = payload['intelSource']?.toString();
    final isCallActive = payload['isCallActive'] == true;
    final normalizedStatus = incomingStatus?.toUpperCase() ?? '';
    final isAnalyzing = payload['isAnalyzing'] == true ||
        normalizedStatus.contains('SCAN') ||
        normalizedStatus.contains('VERIFY') ||
        normalizedStatus.contains('ANALYZ');

    if (!mounted) return;
    setState(() {
      _status = incomingStatus ?? _status;
      _threatText = incomingThreatText ?? _threatText;
      _recommendation = incomingRecommendation ?? _recommendation;
      _sourceApp = incomingSource ?? _sourceApp;
      _scannedUrl = incomingUrl ?? _scannedUrl;
      _intelSource = incomingIntelSource ?? _intelSource;
      _isThreat = payload['isThreat'] == true;
      _riskScore = _readRiskScore(payload['riskScore']);
      _lastThreatType = payload['threatType']?.toString() ?? _lastThreatType;
      _phoneNumber = payload['phoneNumber']?.toString() ?? _phoneNumber;
      _callMessage = payload['message']?.toString() ?? _callMessage;
      _isCallActive = isCallActive;
      _isAnalyzing = isAnalyzing;
      if (incomingStatus == 'CALL ENDED') {
        _isMinimized = true;
      } else if (incomingStatus != 'MONITORING ACTIVE') {
        _isMinimized = false;
      }
    });

    if (isCallActive) {
      _setSurface(_OverlaySurface.call);
    } else if (incomingStatus == 'CALL ENDED') {
      _setSurface(_OverlaySurface.bubble);
    } else if (incomingStatus != null && incomingStatus != 'MONITORING ACTIVE') {
      _setSurface(_OverlaySurface.card);
    }
  }

  Future<void> _setSurface(_OverlaySurface nextSurface) async {
    if (_surface == nextSurface) {
      return;
    }
    if (mounted) {
      setState(() => _surface = nextSurface);
    } else {
      _surface = nextSurface;
    }

    switch (nextSurface) {
      case _OverlaySurface.bubble:
        await _resizeOverlay(_bubbleSize, _bubbleSize, true);
        break;
      case _OverlaySurface.card:
        await _resizeOverlay(_cardWidth, _cardHeight, true);
        break;
      case _OverlaySurface.call:
        await _resizeOverlay(-1, -1, false);
        break;
    }
  }

  Future<void> _resizeOverlay(int width, int height, bool enableDrag) async {
    try {
      await FlutterOverlayWindow.resizeOverlay(width, height, enableDrag);
    } catch (e) {
      debugPrint('Overlay resize failed: $e');
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: _surface == _OverlaySurface.call
          ? _buildCallScanner()
          : ((_isMinimized || _surface == _OverlaySurface.bubble)
                ? _buildMinimizedBubble()
                : _buildCommonOverlay()),
    );
  }

  Widget _buildMinimizedBubble() {
    final accentColor = _isThreat ? Colors.redAccent : Colors.cyanAccent;
    return GestureDetector(
      onTap: () async {
        setState(() => _isMinimized = false);
        await _setSurface(_OverlaySurface.card);
      },
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF071120).withOpacity(0.95),
          shape: BoxShape.circle,
          border: Border.all(
            color: accentColor.withOpacity(0.75),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.26),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              _isThreat ? Icons.warning_rounded : Icons.security_rounded,
              color: accentColor,
              size: 30,
            ),
            if (_isAnalyzing)
              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orangeAccent.withOpacity(0.45),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallScanner() {
    final accentColor =
        _riskScore >= 0.65 ? Colors.redAccent : Colors.cyanAccent;
    final displayedScore = _riskScore > 0 ? _riskScore : 0.18;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF050A12),
            Color(0xFF0B1421),
            Color(0xFF050A12),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: accentColor.withOpacity(0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.graphic_eq_rounded,
                          color: accentColor,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'RISKGUARD CALL ANALYSIS',
                          style: TextStyle(
                            color: accentColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () async {
                      setState(() => _isMinimized = true);
                      await _setSurface(_OverlaySurface.bubble);
                    },
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white70,
                      size: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.06),
                        border: Border.all(
                          color: accentColor.withOpacity(0.35),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        size: 52,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _phoneNumber,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.72),
                        fontSize: 14,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildCallChip('LIVE', accentColor),
                        _buildCallChip('VOICE STREAM', Colors.greenAccent),
                        _buildCallChip(
                          _isAnalyzing ? 'ANALYZING' : 'STABLE',
                          _isAnalyzing
                              ? Colors.orangeAccent
                              : Colors.cyanAccent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF09121F).withOpacity(0.96),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: accentColor.withOpacity(0.26)),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.12),
                        blurRadius: 26,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isThreat
                                ? Icons.warning_rounded
                                : Icons.shield_rounded,
                            color: accentColor,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Realtime Voice Verdict',
                            style: TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _intelSource,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 11,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      LinearProgressIndicator(
                        value: _isAnalyzing && _riskScore == 0
                            ? null
                            : displayedScore,
                        backgroundColor: Colors.white12,
                        color: accentColor,
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              'Deepfake probability',
                              '${(_riskScore * 100).round()}%',
                              accentColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard(
                              'Current state',
                              _isAnalyzing ? 'Profiling' : 'Stable',
                              Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _callMessage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _recommendation,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.68),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                setState(() => _isMinimized = true);
                                await _setSurface(_OverlaySurface.bubble);
                              },
                              icon: const Icon(
                                Icons.picture_in_picture_alt_rounded,
                              ),
                              label: const Text('Minimize'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70,
                                side: BorderSide(
                                  color: Colors.white.withOpacity(0.16),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                setState(() {
                                  _isCallActive = false;
                                  _isMinimized = true;
                                });
                                await _setSurface(_OverlaySurface.bubble);
                              },
                              icon: const Icon(Icons.call_end_rounded),
                              label: const Text('Hide Call Overlay'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFE53935),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: accentColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommonOverlay() {
    final accentColor = _isThreat ? Colors.redAccent : Colors.cyanAccent;
    final statusLabel = _isAnalyzing
        ? 'VERIFYING'
        : (_isThreat ? 'DANGER' : 'SAFE');

    return SafeArea(
      child: Center(
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF08111D).withOpacity(0.97),
                const Color(0xFF0F172A).withOpacity(0.97),
              ],
            ),
            border: Border.all(
              color: accentColor.withOpacity(0.34),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.18),
                blurRadius: 28,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isThreat
                          ? Icons.gpp_bad_rounded
                          : Icons.gpp_good_rounded,
                      color: accentColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'RISKGUARD PROACTIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _sourceApp,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.58),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_fullscreen_rounded,
                      color: Colors.white70,
                    ),
                    onPressed: () async {
                      setState(() => _isMinimized = true);
                      await _setSurface(_OverlaySurface.bubble);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildStatusBadge(statusLabel, accentColor),
                  _buildStatusBadge(
                    _lastThreatType.toUpperCase(),
                    Colors.white70,
                  ),
                  _buildStatusBadge(_intelSource, Colors.orangeAccent),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Captured target',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.48),
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatUrl(_scannedUrl),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: _isAnalyzing ? null : (_riskScore > 0 ? _riskScore : 0.04),
                backgroundColor: Colors.white12,
                color: accentColor,
                minHeight: 8,
                borderRadius: BorderRadius.circular(999),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _status,
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${(_riskScore * 100).round()}% score',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: accentColor.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _threatText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _recommendation,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.68),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

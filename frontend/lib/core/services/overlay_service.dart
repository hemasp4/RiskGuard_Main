/// Overlay Service - System-Wide Floating UI
///
/// Manages the floating overlay window that appears over other apps.
/// Uses flutter_overlay_window for system-level overlay.
library;

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../services/langchain_router.dart';

/// Overlay window entry point
/// This is called when the overlay window is created
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: OverlayWidget()),
  );
}

/// The actual overlay widget that floats over other apps
class OverlayWidget extends StatefulWidget {
  const OverlayWidget({super.key});

  @override
  State<OverlayWidget> createState() => _OverlayWidgetState();
}

class _OverlayWidgetState extends State<OverlayWidget>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  bool _isAnalyzing = false;
  AnalysisResult? _lastResult;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      _lastResult = null;
    });

    // Resize overlay when expanded/collapsed
    if (_isExpanded) {
      FlutterOverlayWindow.resizeOverlay(320, 160, true);
    } else {
      FlutterOverlayWindow.resizeOverlay(70, 70, true);
    }
  }

  void _closeOverlay() {
    FlutterOverlayWindow.closeOverlay();
  }

  Future<void> _requestAnalysis(InputType type) async {
    setState(() => _isAnalyzing = true);

    // Resize for result display
    FlutterOverlayWindow.resizeOverlay(320, 240, true);

    // Simulate analysis - in production, receive data via callback
    await Future.delayed(const Duration(seconds: 1));

    final router = LangChainRouter();
    AnalysisResult result;

    // Demo: analyze based on type
    switch (type) {
      case InputType.url:
        result = await router.analyze('https://example.com');
        break;
      case InputType.text:
        result = await router.analyze('Sample text for analysis');
        break;
      default:
        result = AnalysisResult.safe(
          inputType: type,
          explanation: 'Analysis complete',
        );
    }

    setState(() {
      _isAnalyzing = false;
      _lastResult = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_lastResult != null) {
      return _buildResultCard();
    }

    if (_isExpanded) {
      return _buildExpandedOverlay();
    }

    return _buildCollapsedOverlay();
  }

  Widget _buildCollapsedOverlay() {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: _toggleExpand,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFF667eea,
                    ).withOpacity(0.4 + _pulseController.value * 0.2),
                    blurRadius: 12 + _pulseController.value * 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.shield, color: Colors.white, size: 28),
            );
          },
        ),
      ),
    );
  }

  Widget _buildExpandedOverlay() {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a2e).withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'RiskGuard',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.remove,
                        color: Colors.white54,
                        size: 20,
                      ),
                      onPressed: _toggleExpand,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white54,
                        size: 20,
                      ),
                      onPressed: _closeOverlay,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.link,
                  label: 'Link',
                  color: const Color(0xFF3b82f6),
                  onTap: () => _requestAnalysis(InputType.url),
                ),
                _buildActionButton(
                  icon: Icons.text_fields,
                  label: 'Text',
                  color: const Color(0xFF22c55e),
                  onTap: () => _requestAnalysis(InputType.text),
                ),
                _buildActionButton(
                  icon: Icons.mic,
                  label: 'Voice',
                  color: const Color(0xFFf59e0b),
                  onTap: () => _requestAnalysis(InputType.audio),
                ),
                _buildActionButton(
                  icon: Icons.image,
                  label: 'Image',
                  color: const Color(0xFFec4899),
                  onTap: () => _requestAnalysis(InputType.image),
                ),
              ],
            ),
            if (_isAnalyzing) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation(Color(0xFF667eea)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Analyzing...',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final result = _lastResult!;
    final color = result.isThreat
        ? (result.confidence > 0.8
              ? const Color(0xFFef4444)
              : const Color(0xFFf59e0b))
        : const Color(0xFF22c55e);
    final icon = result.isThreat
        ? (result.confidence > 0.8 ? Icons.dangerous : Icons.warning_amber)
        : Icons.verified_user;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a2e).withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 20)],
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
                    color: color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.isThreat ? 'Risk Detected' : 'Appears Safe',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        '${(result.confidence * 100).toInt()}% confidence',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () {
                    FlutterOverlayWindow.resizeOverlay(70, 70, true);
                    setState(() {
                      _lastResult = null;
                      _isExpanded = false;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Confidence bar
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                widthFactor: result.confidence,
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                result.explanation,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Service for managing the overlay window
class OverlayService {
  // Singleton
  static final OverlayService _instance = OverlayService._internal();
  factory OverlayService() => _instance;
  OverlayService._internal();

  /// Check if overlay permission is granted
  Future<bool> isPermissionGranted() async {
    return await FlutterOverlayWindow.isPermissionGranted();
  }

  /// Request overlay permission
  Future<bool> requestPermission() async {
    final result = await FlutterOverlayWindow.requestPermission();
    return result ?? false;
  }

  /// Check if overlay is currently showing
  Future<bool> isOverlayActive() async {
    return await FlutterOverlayWindow.isActive();
  }

  /// Show the floating overlay
  Future<void> showOverlay() async {
    // Check permission first
    final hasPermission = await isPermissionGranted();
    if (!hasPermission) {
      final granted = await requestPermission();
      if (!granted) return;
    }

    // Check if already active
    if (await isOverlayActive()) return;

    await FlutterOverlayWindow.showOverlay(
      height: 70,
      width: 70,
      alignment: OverlayAlignment.topRight,
      enableDrag: true,
      overlayTitle: 'RiskGuard',
      overlayContent: 'RiskGuard Protection Active',
      flag: OverlayFlag.defaultFlag,
      visibility: NotificationVisibility.visibilityPublic,
      positionGravity: PositionGravity.auto,
    );
  }

  /// Hide the floating overlay
  Future<void> hideOverlay() async {
    if (await isOverlayActive()) {
      await FlutterOverlayWindow.closeOverlay();
    }
  }

  /// Toggle overlay visibility
  Future<bool> toggleOverlay() async {
    if (await isOverlayActive()) {
      await hideOverlay();
      return false;
    } else {
      await showOverlay();
      return true;
    }
  }

  /// Share data with the overlay window
  Future<void> shareData(Map<String, dynamic> data) async {
    await FlutterOverlayWindow.shareData(data);
  }

  /// Resize the overlay
  Future<void> resizeOverlay(int width, int height) async {
    await FlutterOverlayWindow.resizeOverlay(width, height, true);
  }
}

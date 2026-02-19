/// Floating Command Center Widget
///
/// Premium floating overlay with three states:
/// 1. Collapsed - Small draggable shield icon
/// 2. Expanded - Pill menu with action buttons
/// 3. Feedback - Truth report card
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/services/langchain_router.dart';

/// State of the floating overlay
enum OverlayState { collapsed, expanded, feedback }

/// Floating Command Center - Main overlay widget
class FloatingCommandCenter extends StatefulWidget {
  final VoidCallback? onClose;
  final Function(InputType)? onAnalysisRequested;

  const FloatingCommandCenter({
    super.key,
    this.onClose,
    this.onAnalysisRequested,
  });

  @override
  State<FloatingCommandCenter> createState() => _FloatingCommandCenterState();
}

class _FloatingCommandCenterState extends State<FloatingCommandCenter>
    with SingleTickerProviderStateMixin {
  OverlayState _state = OverlayState.collapsed;
  AnalysisResult? _lastResult;
  // ignore: unused_field
  bool _isDragging = false;
  Offset _position = const Offset(20, 100);

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
      if (_state == OverlayState.collapsed) {
        _state = OverlayState.expanded;
      } else if (_state == OverlayState.expanded) {
        _state = OverlayState.collapsed;
      } else if (_state == OverlayState.feedback) {
        _state = OverlayState.collapsed;
        _lastResult = null;
      }
    });
  }

  /// Show feedback card with analysis result
  /// Call this method to display the TruthReportCard
  void showFeedback(AnalysisResult result) {
    setState(() {
      _lastResult = result;
      _state = OverlayState.feedback;
    });
  }

  void _requestAnalysis(InputType type) {
    widget.onAnalysisRequested?.call(type);
    setState(() => _state = OverlayState.collapsed);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanStart: (_) => setState(() => _isDragging = true),
        onPanUpdate: (details) {
          setState(() {
            _position = Offset(
              _position.dx + details.delta.dx,
              _position.dy + details.delta.dy,
            );
          });
        },
        onPanEnd: (_) => setState(() => _isDragging = false),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeIn,
          child: _buildCurrentState(),
        ),
      ),
    );
  }

  Widget _buildCurrentState() {
    switch (_state) {
      case OverlayState.collapsed:
        return _buildCollapsedState();
      case OverlayState.expanded:
        return _buildExpandedState();
      case OverlayState.feedback:
        return _buildFeedbackState();
    }
  }

  Widget _buildCollapsedState() {
    return GestureDetector(
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
                  ).withValues(alpha: 0.4 + _pulseController.value * 0.2),
                  blurRadius: 12 + _pulseController.value * 8,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.shield, color: Colors.white, size: 28),
          );
        },
      ),
    ).animate().scale(
      begin: const Offset(0.8, 0.8),
      end: const Offset(1.0, 1.0),
      duration: 200.ms,
      curve: Curves.easeOutBack,
    );
  }

  Widget _buildExpandedState() {
    return Container(
          key: const ValueKey('expanded'),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.15),
                Colors.white.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.3),
                BlendMode.darken,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Close/collapse button
                  _buildActionButton(
                    icon: Icons.close,
                    color: Colors.grey,
                    onTap: _toggleExpand,
                  ),
                  const SizedBox(width: 4),
                  // Divider
                  Container(
                    width: 1,
                    height: 32,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  const SizedBox(width: 4),
                  // Action buttons
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
            ),
          ),
        )
        .animate()
        .scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1.0, 1.0),
          duration: 200.ms,
          curve: Curves.easeOutBack,
        )
        .fadeIn(duration: 150.ms);
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? label,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            if (label != null) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackState() {
    if (_lastResult == null) return const SizedBox();

    return TruthReportCard(
      key: const ValueKey('feedback'),
      result: _lastResult!,
      onDismiss: _toggleExpand,
      onExpand: () {
        // TODO: Navigate to detailed analysis screen
      },
    );
  }
}

/// Truth Report Card - Shows analysis result
class TruthReportCard extends StatelessWidget {
  final AnalysisResult result;
  final VoidCallback onDismiss;
  final VoidCallback? onExpand;

  const TruthReportCard({
    super.key,
    required this.result,
    required this.onDismiss,
    this.onExpand,
  });

  Color get _statusColor {
    if (result.isThreat) {
      if (result.confidence > 0.8) return const Color(0xFFef4444);
      return const Color(0xFFf59e0b);
    }
    return const Color(0xFF22c55e);
  }

  IconData get _statusIcon {
    if (result.isThreat) {
      if (result.confidence > 0.8) return Icons.dangerous;
      return Icons.warning_amber;
    }
    return Icons.verified_user;
  }

  String get _statusText {
    if (result.isThreat) {
      if (result.confidence > 0.8) return 'High Risk Detected';
      return 'Suspicious Content';
    }
    return 'Appears Safe';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
          width: 300,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                _statusColor.withValues(alpha: 0.15),
                Colors.black.withValues(alpha: 0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: _statusColor.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: _statusColor.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_statusIcon, color: _statusColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _statusText,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _statusColor,
                          ),
                        ),
                        Text(
                          '${(result.confidence * 100).toInt()}% confidence',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: Colors.white54,
                    onPressed: onDismiss,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Confidence bar
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: FractionallySizedBox(
                  widthFactor: result.confidence,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _statusColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Explanation
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.white.withValues(alpha: 0.5),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        result.explanation,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.8),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Analysis type badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getInputTypeIcon(result.inputType),
                          color: Colors.white70,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          result.inputType.name.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      result.wasLocalAnalysis ? 'LOCAL' : 'CLOUD',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (onExpand != null)
                    GestureDetector(
                      onTap: onExpand,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Details',
                            style: TextStyle(
                              fontSize: 12,
                              color: _statusColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: _statusColor,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        )
        .animate()
        .scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1.0, 1.0),
          duration: 250.ms,
          curve: Curves.easeOutBack,
        )
        .fadeIn(duration: 200.ms);
  }

  IconData _getInputTypeIcon(InputType type) {
    switch (type) {
      case InputType.url:
        return Icons.link;
      case InputType.text:
        return Icons.text_fields;
      case InputType.audio:
        return Icons.mic;
      case InputType.image:
        return Icons.image;
      case InputType.video:
        return Icons.videocam;
      case InputType.unknown:
        return Icons.help_outline;
    }
  }
}

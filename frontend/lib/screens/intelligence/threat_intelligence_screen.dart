import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/analysis_models.dart';
import '../../core/services/threat_intelligence_provider.dart';

class ThreatIntelligenceScreen extends StatefulWidget {
  const ThreatIntelligenceScreen({super.key});

  @override
  State<ThreatIntelligenceScreen> createState() =>
      _ThreatIntelligenceScreenState();
}

class _ThreatIntelligenceScreenState extends State<ThreatIntelligenceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ThreatIntelligenceProvider>().attachScreen();
    });
  }

  @override
  void dispose() {
    if (mounted) {
      context.read<ThreatIntelligenceProvider>().detachScreen();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060B12),
      body: SafeArea(
        child: Consumer<ThreatIntelligenceProvider>(
          builder: (context, provider, child) {
            return Column(
              children: [
                _Header(provider: provider),
                _StatusRow(provider: provider),
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                    child: _WorldMapPanel(provider: provider),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: _TerminalPanel(provider: provider),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.provider});
  final ThreatIntelligenceProvider provider;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            color: Colors.white70,
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF26D9FF).withOpacity(0.35)),
              gradient: const LinearGradient(
                colors: [Color(0x2214B8A6), Color(0x1117C6FF)],
              ),
            ),
            child: const Icon(
              Icons.public_rounded,
              color: Color(0xFF26D9FF),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Intelligence Center',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Privacy-safe deepfake telemetry only',
                  style: TextStyle(
                    color: Color(0xFF7AA6C1),
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: provider.isLoading ? null : provider.refreshAll,
            icon: const Icon(Icons.refresh_rounded),
            color: const Color(0xFF26D9FF),
          ),
          IconButton(
            onPressed: () => _showInfo(context),
            icon: const Icon(Icons.info_outline_rounded),
            color: Colors.white54,
          ),
        ],
      ),
    );
  }

  void _showInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0B1421),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        title: const Text(
          'Intelligence Scope',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'This view shows aggregated deepfake telemetry only. It does not expose usernames, phone numbers, raw URLs, file names, exact coordinates, or device identifiers.',
          style: TextStyle(
            color: Color(0xFFB8C7D1),
            fontSize: 13,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.provider});
  final ThreatIntelligenceProvider provider;

  @override
  Widget build(BuildContext context) {
    final hasData =
        provider.terminalThreats.isNotEmpty || provider.hotspots.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Expanded(
            child: _StatusChip(
              label: 'Feed',
              value: provider.isLoading
                  ? 'SYNCING'
                  : hasData
                  ? 'LIVE'
                  : 'STANDBY',
              color: provider.isLoading
                  ? Colors.orangeAccent
                  : hasData
                  ? const Color(0xFF26D9FF)
                  : Colors.greenAccent,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatusChip(
              label: 'Hotspots',
              value: provider.hotspots.length.toString(),
              color: const Color(0xFF26D9FF),
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: _StatusChip(
              label: 'Mode',
              value: 'DEEPFAKE',
              color: Color(0xFF14B8A6),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color.withOpacity(0.75),
              fontSize: 10,
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorldMapPanel extends StatelessWidget {
  const _WorldMapPanel({required this.provider});
  final ThreatIntelligenceProvider provider;

  @override
  Widget build(BuildContext context) {
    final hasData = provider.hotspots.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF08111D), Color(0xFF0D1726)],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _ProfessionalWorldMapPainter()),
            ),
            Positioned.fill(child: CustomPaint(painter: _GridPainter())),
            Positioned.fill(child: _ScanLineEffect()),
            Positioned.fill(child: _HotspotLayer(hotspots: provider.hotspots)),
            Positioned(
              left: 18,
              top: 18,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xCC08111D),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Text(
                  hasData
                      ? 'Aggregated deepfake hotspots only'
                      : 'Terminal standing by for validated deepfake telemetry',
                  style: const TextStyle(
                    color: Color(0xFFB8C7D1),
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TerminalPanel extends StatelessWidget {
  const _TerminalPanel({required this.provider});
  final ThreatIntelligenceProvider provider;

  @override
  Widget build(BuildContext context) {
    final threats = provider.terminalThreats;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF08111A),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFF26D9FF),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'THREAT TERMINAL',
                  style: TextStyle(
                    color: Color(0xFF26D9FF),
                    fontSize: 12,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '${threats.length} EVENTS',
                  style: const TextStyle(
                    color: Color(0xFF6A8293),
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: threats.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No verified deepfake hotspots in the current window.\nTerminal standing by for validated telemetry.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF7AA6C1),
                          fontSize: 13,
                          height: 1.6,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: threats.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 18, color: Colors.white.withOpacity(0.04)),
                    itemBuilder: (context, index) =>
                        _TerminalRow(threat: threats[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TerminalRow extends StatelessWidget {
  const _TerminalRow({required this.threat});
  final GlobalThreat threat;

  @override
  Widget build(BuildContext context) {
    final severityColor = switch (threat.severity) {
      'CRITICAL' => Colors.redAccent,
      'HIGH' => Colors.orangeAccent,
      _ => const Color(0xFF26D9FF),
    };
    final timestamp = threat.timestamp.length >= 19
        ? threat.timestamp.substring(11, 19)
        : threat.timestamp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$timestamp | ${threat.region} | ${threat.threatClass.toUpperCase()} | ${threat.severity} | ${threat.confidenceBand} | ${threat.analysisSource.toUpperCase()}',
          style: TextStyle(
            color: severityColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1.4,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${threat.cityOrZoneLabel} :: ${threat.artifactSummary}',
          style: const TextStyle(
            color: Color(0xFFB8C7D1),
            fontSize: 12,
            height: 1.5,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

class _HotspotLayer extends StatefulWidget {
  const _HotspotLayer({required this.hotspots});
  final List<RiskHotspot> hotspots;

  @override
  State<_HotspotLayer> createState() => _HotspotLayerState();
}

class _HotspotLayerState extends State<_HotspotLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _HotspotPainter(
            hotspots: widget.hotspots,
            progress: _controller.value,
          ),
        );
      },
    );
  }
}

class _HotspotPainter extends CustomPainter {
  const _HotspotPainter({required this.hotspots, required this.progress});
  final List<RiskHotspot> hotspots;
  final double progress;

  Offset _project(double lon, double lat, Size size) {
    final x = (lon + 180) / 360 * size.width;
    final y = (90 - lat) / 180 * size.height;
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final hotspot in hotspots.take(20)) {
      final point = _project(hotspot.lng, hotspot.lat, size);
      final pulse = (math.sin((progress * math.pi * 2) - hotspot.intensity) + 1) / 2;
      final radius = 5 + (18 * hotspot.intensity * pulse);
      final color = hotspot.intensity >= 0.8
          ? Colors.redAccent
          : hotspot.intensity >= 0.55
          ? Colors.orangeAccent
          : const Color(0xFF26D9FF);

      canvas.drawCircle(
        point,
        radius,
        Paint()
          ..color = color.withOpacity(0.16)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      canvas.drawCircle(
        point,
        2.8 + hotspot.intensity * 3,
        Paint()
          ..color = color.withOpacity(0.94)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HotspotPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.hotspots != hotspots;
}

class _ScanLineEffect extends StatefulWidget {
  @override
  State<_ScanLineEffect> createState() => _ScanLineEffectState();
}

class _ScanLineEffectState extends State<_ScanLineEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) =>
          CustomPaint(painter: _ScanLinePainter(progress: _controller.value)),
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  const _ScanLinePainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;
    canvas.drawRect(
      Rect.fromLTWH(0, y - 22, size.width, 44),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, y - 22),
          Offset(0, y + 22),
          [
            Colors.transparent,
            Colors.redAccent.withOpacity(0.07),
            Colors.transparent,
          ],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _ProfessionalWorldMapPainter extends CustomPainter {
  Offset _project(double lon, double lat, Size size) {
    final x = (lon + 180) / 360 * size.width;
    final y = (90 - lat) / 180 * size.height;
    return Offset(x, y);
  }

  Path _build(List<List<double>> coords, Size size) {
    final path = Path();
    if (coords.isEmpty) return path;
    final first = _project(coords.first[0], coords.first[1], size);
    path.moveTo(first.dx, first.dy);
    for (final point in coords.skip(1)) {
      final projected = _project(point[0], point[1], size);
      path.lineTo(projected.dx, projected.dy);
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final continents = <Path>[
      _build([
        [-168, 72], [-156, 71], [-148, 68], [-140, 62], [-132, 57], [-128, 52],
        [-126, 48], [-123, 46], [-124, 40], [-119, 36], [-117, 32], [-112, 27],
        [-108, 25], [-103, 23], [-97, 24], [-90, 28], [-84, 29], [-81, 26],
        [-80, 22], [-84, 18], [-87, 14], [-92, 16], [-97, 18], [-103, 21],
        [-108, 25], [-114, 31], [-120, 38], [-126, 47], [-136, 55], [-150, 63],
        [-160, 68], [-168, 72],
      ], size),
      _build([
        [-54, 59], [-48, 62], [-41, 69], [-33, 76], [-22, 78], [-18, 72],
        [-24, 64], [-34, 60], [-44, 58], [-54, 59],
      ], size),
      _build([
        [-82, 12], [-79, 8], [-77, 4], [-74, -1], [-71, -6], [-68, -10],
        [-64, -16], [-61, -22], [-58, -28], [-56, -34], [-58, -42], [-63, -49],
        [-69, -55], [-74, -50], [-76, -40], [-77, -28], [-79, -15], [-82, -2],
        [-82, 12],
      ], size),
      _build([
        [-10, 36], [-5, 43], [1, 49], [9, 54], [18, 57], [28, 58], [36, 55],
        [32, 49], [26, 46], [20, 43], [13, 42], [8, 40], [3, 39], [-3, 38],
        [-10, 36],
      ], size),
      _build([
        [-17, 35], [-10, 36], [-2, 35], [8, 33], [18, 33], [27, 31], [33, 24],
        [37, 15], [39, 6], [38, -4], [35, -15], [29, -24], [20, -33], [11, -35],
        [4, -27], [-1, -15], [-5, -2], [-8, 11], [-12, 22], [-17, 35],
      ], size),
      _build([
        [28, 41], [36, 46], [46, 51], [58, 56], [72, 60], [86, 64], [100, 68],
        [116, 70], [132, 66], [146, 58], [154, 50], [150, 42], [142, 33], [132, 22],
        [120, 17], [110, 12], [102, 7], [96, 7], [90, 14], [82, 20], [76, 24],
        [70, 22], [64, 18], [58, 20], [52, 26], [46, 31], [40, 34], [34, 38],
        [28, 41],
      ], size),
      _build([
        [68, 24], [74, 28], [81, 30], [88, 27], [92, 22], [90, 17], [84, 10],
        [77, 8], [72, 14], [68, 24],
      ], size),
      _build([
        [100, 8], [106, 11], [114, 10], [122, 6], [128, 1], [132, -5], [128, -8],
        [119, -7], [112, -3], [106, 1], [100, 8],
      ], size),
      _build([
        [112, -11], [120, -15], [130, -18], [141, -21], [150, -28], [150, -38],
        [140, -42], [128, -39], [119, -32], [113, -23], [112, -11],
      ], size),
      _build([
        [-9, 50], [-5, 53], [0, 55], [2, 52], [-2, 50], [-6, 50], [-9, 50],
      ], size),
      _build([
        [136, 34], [140, 38], [145, 42], [148, 38], [144, 34], [139, 32], [136, 34],
      ], size),
      _build([
        [-180, -60], [-140, -62], [-100, -64], [-60, -66], [-20, -67], [20, -66],
        [60, -65], [100, -64], [140, -62], [180, -60], [180, -78], [-180, -78], [-180, -60],
      ], size),
    ];

    final fill = Paint()
      ..color = const Color(0xFF123451).withOpacity(0.28)
      ..style = PaintingStyle.fill;
    final coast = Paint()
      ..color = const Color(0xFF3E709A).withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final glow = Paint()
      ..color = const Color(0xFF2BD3FF).withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    final dim = Paint()..color = const Color(0xFF284A69).withOpacity(0.55);
    final bright = Paint()..color = const Color(0xFF4B82B5).withOpacity(0.72);

    for (final continent in continents) {
      canvas.drawPath(continent, fill);
      canvas.drawPath(continent, glow);
      canvas.drawPath(continent, coast);
    }

    for (double x = 0; x < size.width; x += 5) {
      for (double y = 0; y < size.height; y += 5) {
        final point = Offset(x, y);
        for (final continent in continents) {
          if (continent.contains(point)) {
            canvas.drawCircle(
              point,
              1,
              ((x + y).toInt() % 6 == 0) ? bright : dim,
            );
            break;
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 36) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 36) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

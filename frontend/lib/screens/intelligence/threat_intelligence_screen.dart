import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/threat_intelligence_provider.dart';
import '../../core/models/analysis_models.dart';
import 'dart:ui' as ui;

// ══════════════════════════════════════════════════════════════════════════════
// INTELLIGENCE CENTER — Professional Cyber Command UI
// ══════════════════════════════════════════════════════════════════════════════

class ThreatIntelligenceScreen extends StatelessWidget {
  const ThreatIntelligenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080C14),
      body: SafeArea(
        child: Consumer<ThreatIntelligenceProvider>(
          builder: (context, provider, child) {
            return Column(
              children: [
                // ── Header ──
                _buildHeader(context, provider),
                // ── Status Pills ──
                _buildStatusPills(provider),
                // ── World Map ──
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _CyberWorldMap(provider: provider),
                  ),
                ),
                // ── Live Threat Feed ──
                Expanded(
                  flex: 4,
                  child: _LiveThreatFeed(provider: provider),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThreatIntelligenceProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 18),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          // Shield icon
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.redAccent.withOpacity(0.5), width: 1.5),
            ),
            child: const Icon(Icons.shield, color: Colors.redAccent, size: 18),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RiskGuard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              Text(
                'INTELLIGENCE CENTER',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Settings / Info
          IconButton(
            icon: Icon(Icons.info_outline, color: Colors.white.withOpacity(0.5), size: 20),
            onPressed: () => _showIntelligenceInfo(context),
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white.withOpacity(0.5), size: 20),
            onPressed: () => provider.refreshAll(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPills(ThreatIntelligenceProvider provider) {
    final maxIntensity = provider.hotspots.fold<double>(
      0.0,
      (current, hotspot) =>
          hotspot.intensity > current ? hotspot.intensity : current,
    );
    final normalizedIntensity = maxIntensity > 1
        ? (maxIntensity / 100).clamp(0.0, 1.0)
        : maxIntensity.clamp(0.0, 1.0);
    final scanLevel = normalizedIntensity >= 0.8
        ? 'CRITICAL'
        : normalizedIntensity >= 0.55
        ? 'HIGH'
        : provider.isLoading
        ? 'SYNCING'
        : 'GUARDED';
    final scanColor = normalizedIntensity >= 0.8
        ? Colors.redAccent
        : normalizedIntensity >= 0.55
        ? Colors.orangeAccent
        : Colors.greenAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          _StatusPill(
            label: 'THREAT LEVEL',
            value: scanLevel,
            color: scanColor,
          ),
          const SizedBox(width: 8),
          _StatusPill(
            label: 'HOTSPOTS',
            value: provider.hotspots.isEmpty
                ? '--'
                : provider.hotspots.length.toString(),
            color: Colors.cyanAccent,
          ),
          const SizedBox(width: 8),
          _StatusPill(
            label: 'FEED',
            value: provider.isLoading
                ? 'SYNCING'
                : provider.globalThreats.isEmpty
                ? 'IDLE'
                : 'LIVE',
            color: provider.isLoading ? Colors.orangeAccent : Colors.greenAccent,
          ),
        ],
      ),
    );
  }

  void _showIntelligenceInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.redAccent, width: 0.5),
        ),
        title: const Text(
          'SYSTEM DEBRIEF',
          style: TextStyle(
            color: Colors.redAccent,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoItem(title: 'Global Threat Map', desc: 'Real-time geographic visualization of active cyber threats worldwide.'),
            _InfoItem(title: 'Red Hotspots', desc: 'High-intensity threat zones detected by our 2.8k intercept nodes.'),
            _InfoItem(title: 'Live Feed', desc: 'Unfiltered detection stream from the proactive threat verification engine.'),
            _InfoItem(title: 'Status Pills', desc: 'Current system state — scan intensity, active nodes, and stealth mode.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ACKNOWLEDGE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STATUS PILL
// ══════════════════════════════════════════════════════════════════════════════

class _StatusPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatusPill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.25), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: color.withOpacity(0.6), fontSize: 7, fontWeight: FontWeight.w600, letterSpacing: 1),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CYBER WORLD MAP — Full professional dot-matrix map with threat hotspots
// ══════════════════════════════════════════════════════════════════════════════

class _CyberWorldMap extends StatelessWidget {
  final ThreatIntelligenceProvider provider;
  const _CyberWorldMap({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1020),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Dot-matrix world map
            Positioned.fill(
              child: CustomPaint(painter: _ProfessionalWorldMapPainter()),
            ),
            // Animated threat hotspots overlay
            Positioned.fill(
              child: _ThreatHotspotsOverlay(provider: provider),
            ),
            // Scan lines effect
            Positioned.fill(
              child: _ScanLineEffect(),
            ),
            // Grid overlay for cyber effect
            Positioned.fill(
              child: CustomPaint(painter: _GridOverlayPainter()),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PROFESSIONAL WORLD MAP PAINTER — Accurate continent dot-matrix
// ══════════════════════════════════════════════════════════════════════════════

class _ProfessionalWorldMapPainter extends CustomPainter {
  // World coordinates [lon, lat] mapped to canvas coordinates using
  // Equirectangular projection. Polygons are simplified but geographically accurate.
  // lon: -180..+180 → x: 0..width
  // lat: +90..-90  → y: 0..height

  Offset _project(double lon, double lat, Size size) {
    final x = (lon + 180) / 360 * size.width;
    final y = (90 - lat) / 180 * size.height;
    return Offset(x, y);
  }

  Path _buildContinent(List<List<double>> coords, Size size) {
    final path = Path();
    if (coords.isEmpty) return path;
    final first = _project(coords[0][0], coords[0][1], size);
    path.moveTo(first.dx, first.dy);
    for (int i = 1; i < coords.length; i++) {
      final p = _project(coords[i][0], coords[i][1], size);
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // ── Continent coordinate data (simplified polygons in [lon, lat]) ──

    // North America
    final northAmerica = _buildContinent([
      [-168, 72], [-140, 70], [-130, 72], [-100, 72], [-85, 75],
      [-60, 72], [-55, 52], [-65, 45], [-70, 43], [-75, 35],
      [-80, 25], [-88, 18], [-97, 16], [-105, 20], [-117, 32],
      [-125, 48], [-135, 58], [-145, 60], [-165, 63], [-168, 72],
    ], size);

    // Greenland
    final greenland = _buildContinent([
      [-55, 82], [-20, 82], [-15, 75], [-20, 60], [-45, 60], [-55, 65], [-55, 82],
    ], size);

    // South America
    final southAmerica = _buildContinent([
      [-80, 10], [-60, 12], [-50, 5], [-35, -5], [-35, -20],
      [-40, -22], [-50, -30], [-55, -35], [-65, -55], [-75, -50],
      [-70, -18], [-75, -5], [-80, 0], [-80, 10],
    ], size);

    // Central America
    final centralAmerica = _buildContinent([
      [-88, 18], [-80, 10], [-77, 8], [-82, 8], [-85, 10], [-90, 14], [-92, 16], [-88, 18],
    ], size);

    // Europe
    final europe = _buildContinent([
      [-10, 60], [5, 62], [15, 70], [30, 72], [40, 68],
      [45, 55], [40, 50], [30, 45], [20, 40], [10, 38],
      [0, 36], [-10, 36], [-10, 43], [-5, 48], [-10, 55], [-10, 60],
    ], size);

    // UK/Ireland
    final uk = _buildContinent([
      [-10, 58], [-5, 58], [2, 56], [2, 51], [-5, 50], [-10, 52], [-10, 58],
    ], size);

    // Africa
    final africa = _buildContinent([
      [-15, 35], [10, 37], [30, 32], [35, 30], [42, 12], [50, 5],
      [40, -12], [35, -25], [28, -34], [18, -35], [12, -20],
      [10, 0], [5, 5], [-5, 5], [-15, 10], [-17, 15], [-15, 35],
    ], size);

    // Madagascar
    final madagascar = _buildContinent([
      [44, -12], [50, -15], [50, -25], [44, -25], [44, -12],
    ], size);

    // Asia (mainland)
    final asia = _buildContinent([
      [45, 55], [60, 60], [70, 65], [90, 72], [120, 75], [140, 72],
      [155, 62], [160, 55], [140, 50], [130, 42], [120, 30],
      [110, 20], [100, 10], [95, 5], [80, 8], [75, 15],
      [70, 25], [60, 30], [50, 35], [40, 35], [30, 45], [40, 50], [45, 55],
    ], size);

    // Japan
    final japan = _buildContinent([
      [130, 45], [140, 45], [145, 40], [140, 33], [130, 32], [130, 45],
    ], size);

    // Indonesia / SE Asia islands
    final indonesia = _buildContinent([
      [95, 6], [105, 6], [115, -2], [125, -5], [140, -5],
      [140, -10], [115, -8], [105, -5], [95, 0], [95, 6],
    ], size);

    // Philippines
    final philippines = _buildContinent([
      [118, 18], [125, 18], [127, 10], [122, 6], [118, 10], [118, 18],
    ], size);

    // Australia
    final australia = _buildContinent([
      [115, -12], [135, -12], [150, -15], [153, -25], [150, -38],
      [140, -38], [130, -35], [115, -35], [113, -25], [115, -12],
    ], size);

    // New Zealand
    final newZealand = _buildContinent([
      [166, -35], [178, -38], [178, -46], [168, -46], [166, -35],
    ], size);

    // India subcontinent (more detail)
    final india = _buildContinent([
      [68, 28], [75, 32], [88, 27], [92, 22], [88, 12],
      [80, 8], [75, 12], [72, 18], [68, 22], [68, 28],
    ], size);

    // Arabian Peninsula
    final arabia = _buildContinent([
      [35, 30], [42, 28], [50, 26], [56, 22], [55, 15],
      [48, 12], [43, 14], [35, 20], [35, 30],
    ], size);

    final continents = [
      northAmerica, greenland, southAmerica, centralAmerica,
      europe, uk, africa, madagascar,
      asia, japan, indonesia, philippines,
      australia, newZealand, india, arabia,
    ];

    // ── Draw dots inside continents ──
    final landDotPaint = Paint()
      ..color = const Color(0xFF2A4A6B).withOpacity(0.8)
      ..style = PaintingStyle.fill;

    final landDotBrightPaint = Paint()
      ..color = const Color(0xFF3D6B99).withOpacity(0.6)
      ..style = PaintingStyle.fill;

    const double spacing = 5.0;
    const double dotRadius = 1.0;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        final point = Offset(x, y);
        for (final continent in continents) {
          if (continent.contains(point)) {
            // Add slight variation for organic look
            final hash = (x * 7 + y * 13).toInt() % 5;
            canvas.drawCircle(
              point,
              dotRadius,
              hash == 0 ? landDotBrightPaint : landDotPaint,
            );
            break;
          }
        }
      }
    }

    // ── Draw continent outlines (subtle glow) ──
    final outlinePaint = Paint()
      ..color = const Color(0xFF1A3A5C).withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (final continent in continents) {
      canvas.drawPath(continent, outlinePaint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// ══════════════════════════════════════════════════════════════════════════════
// GRID OVERLAY for tech feel
// ══════════════════════════════════════════════════════════════════════════════

class _GridOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.015)
      ..strokeWidth = 0.5;

    // Horizontal lines
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Vertical lines
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// ══════════════════════════════════════════════════════════════════════════════
// SCAN LINE EFFECT
// ══════════════════════════════════════════════════════════════════════════════

class _ScanLineEffect extends StatefulWidget {
  @override
  State<_ScanLineEffect> createState() => _ScanLineEffectState();
}

class _ScanLineEffectState extends State<_ScanLineEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
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
          painter: _ScanLinePainter(progress: _controller.value),
        );
      },
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  final double progress;
  _ScanLinePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, y - 20),
        Offset(0, y + 20),
        [
          Colors.transparent,
          Colors.redAccent.withOpacity(0.08),
          Colors.transparent,
        ],
        [0.0, 0.5, 1.0],
      );
    canvas.drawRect(Rect.fromLTWH(0, y - 20, size.width, 40), paint);
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter oldDelegate) => true;
}

// ══════════════════════════════════════════════════════════════════════════════
// ANIMATED THREAT HOTSPOTS — Red glowing pulses on the map
// ══════════════════════════════════════════════════════════════════════════════

class _ThreatHotspotsOverlay extends StatefulWidget {
  final ThreatIntelligenceProvider provider;
  const _ThreatHotspotsOverlay({required this.provider});

  @override
  State<_ThreatHotspotsOverlay> createState() => _ThreatHotspotsOverlayState();
}

class _ThreatHotspotsOverlayState extends State<_ThreatHotspotsOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  // Fixed threat hotspot locations [lon, lat, intensity]
  static const List<List<double>> _threatLocations = [
    // Major cyber threat hotspots worldwide
    [-74.0, 40.7, 0.9],    // New York
    [-118.2, 34.0, 0.7],   // Los Angeles
    [-87.6, 41.9, 0.5],    // Chicago
    [-99.1, 19.4, 0.6],    // Mexico City
    [-43.2, -22.9, 0.5],   // Rio de Janeiro
    [-58.4, -34.6, 0.4],   // Buenos Aires
    [0.0, 51.5, 0.8],      // London
    [2.3, 48.9, 0.6],      // Paris
    [13.4, 52.5, 0.5],     // Berlin
    [37.6, 55.8, 0.9],     // Moscow
    [12.5, 41.9, 0.4],     // Rome
    [28.9, 41.0, 0.5],     // Istanbul
    [31.2, 30.0, 0.4],     // Cairo
    [3.4, 6.5, 0.6],       // Lagos
    [36.8, -1.3, 0.3],     // Nairobi
    [55.3, 25.3, 0.5],     // Dubai
    [51.4, 35.7, 0.7],     // Tehran
    [69.0, 33.9, 0.4],     // Kabul
    [72.9, 19.1, 0.6],     // Mumbai
    [77.2, 28.6, 0.7],     // Delhi
    [88.4, 22.6, 0.4],     // Kolkata
    [100.5, 13.8, 0.5],    // Bangkok
    [103.8, 1.4, 0.6],     // Singapore
    [106.8, -6.2, 0.5],    // Jakarta
    [116.4, 39.9, 0.95],   // Beijing
    [121.5, 31.2, 0.85],   // Shanghai
    [126.9, 37.6, 0.7],    // Seoul
    [139.7, 35.7, 0.8],    // Tokyo
    [114.2, 22.3, 0.6],    // Hong Kong
    [121.0, 14.6, 0.4],    // Manila
    [151.2, -33.9, 0.5],   // Sydney
    [174.8, -41.3, 0.3],   // Wellington
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Offset _project(double lon, double lat, Size size) {
    final x = (lon + 180) / 360 * size.width;
    final y = (90 - lat) / 180 * size.height;
    return Offset(x, y);
  }

  List<List<double>> get _resolvedLocations {
    if (widget.provider.hotspots.isEmpty) {
      return _threatLocations;
    }

    return widget.provider.hotspots.map((hotspot) {
      final normalizedIntensity = hotspot.intensity > 1
          ? (hotspot.intensity / 100).clamp(0.18, 1.0).toDouble()
          : hotspot.intensity.clamp(0.18, 1.0).toDouble();
      return [hotspot.lng, hotspot.lat, normalizedIntensity];
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return CustomPaint(
          painter: _HotspotsPainter(
            progress: _pulseController.value,
            locations: _resolvedLocations,
            projectFn: _project,
          ),
        );
      },
    );
  }
}

class _HotspotsPainter extends CustomPainter {
  final double progress;
  final List<List<double>> locations;
  final Offset Function(double lon, double lat, Size size) projectFn;

  _HotspotsPainter({required this.progress, required this.locations, required this.projectFn});

  @override
  void paint(Canvas canvas, Size size) {
    for (final loc in locations) {
      final pos = projectFn(loc[0], loc[1], size);
      final intensity = loc[2];

      // Phase offset per hotspot for organic feel
      final phaseOffset = (loc[0].abs() * 0.01 + loc[1].abs() * 0.02) % 1.0;
      final localProgress = (progress + phaseOffset) % 1.0;

      // Outer glow pulse
      final outerRadius = 4 + (12 * intensity * localProgress);
      final outerPaint = Paint()
        ..color = Colors.redAccent.withOpacity(0.15 * intensity * (1 - localProgress))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(pos, outerRadius, outerPaint);

      // Mid glow
      final midRadius = 2 + (6 * intensity * localProgress);
      final midPaint = Paint()
        ..color = Colors.red.withOpacity(0.25 * intensity * (1 - localProgress))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(pos, midRadius, midPaint);

      // Core dot (always visible)
      final corePaint = Paint()
        ..color = Color.lerp(Colors.orange, Colors.redAccent, intensity)!.withOpacity(0.7 + 0.3 * intensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);
      canvas.drawCircle(pos, 1.5 + intensity, corePaint);

      // Bright center
      final centerPaint = Paint()
        ..color = Colors.orangeAccent.withOpacity(0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.5);
      canvas.drawCircle(pos, 0.8, centerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ══════════════════════════════════════════════════════════════════════════════
// LIVE THREAT FEED — Terminal-style scrolling feed
// ══════════════════════════════════════════════════════════════════════════════

class _LiveThreatFeed extends StatelessWidget {
  final ThreatIntelligenceProvider provider;
  const _LiveThreatFeed({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Feed header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(bottom: BorderSide(color: Colors.redAccent.withOpacity(0.15))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 6, color: Colors.redAccent),
                      SizedBox(width: 4),
                      Text(
                        'LIVE THREAT FEED',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '${provider.globalThreats.length} DETECTIONS',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 9,
                    fontFamily: 'monospace',
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          // Scrollable feed
          Expanded(
            child: provider.globalThreats.isEmpty
                ? Center(
                    child: Text(
                      'AWAITING_THREAT_DATA...',
                      style: TextStyle(color: Colors.white.withOpacity(0.2), fontFamily: 'monospace', fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: provider.globalThreats.length,
                    itemBuilder: (context, index) {
                      final threat = provider.globalThreats[index];
                      return _ThreatFeedItem(threat: threat, index: index);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ThreatFeedItem extends StatelessWidget {
  final GlobalThreat threat;
  final int index;
  const _ThreatFeedItem({required this.threat, required this.index});

  @override
  Widget build(BuildContext context) {
    Color severityColor = Colors.greenAccent;
    if (threat.severity == 'HIGH') severityColor = Colors.orangeAccent;
    if (threat.severity == 'CRITICAL') severityColor = Colors.redAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.03)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp + Region + Severity
          Row(
            children: [
              Text(
                threat.timestamp.length > 10 ? threat.timestamp.substring(11, 19) : threat.timestamp,
                style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 9, fontFamily: 'monospace'),
              ),
              const SizedBox(width: 8),
              Text(
                '[${threat.region}]',
                style: const TextStyle(color: Colors.cyanAccent, fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: severityColor.withOpacity(0.1),
                  border: Border.all(color: severityColor.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  threat.severity,
                  style: TextStyle(color: severityColor, fontSize: 7, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ),
              const Spacer(),
              if (threat.blockchainVerified)
                Icon(Icons.verified, size: 10, color: Colors.blueAccent.withOpacity(0.6)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '> ${threat.category.toUpperCase()} :: ${threat.campaign.toUpperCase()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: severityColor.withOpacity(0.9),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            threat.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 11,
              height: 1.3,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// INFO ITEM (for dialog)
// ══════════════════════════════════════════════════════════════════════════════

class _InfoItem extends StatelessWidget {
  final String title;
  final String desc;
  const _InfoItem({required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 2),
          Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}

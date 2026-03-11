/// API configuration — centralized endpoints & base URL
class ApiConfig {
  ApiConfig._();

  // Base URL: localhost for web/desktop testing
  static const String baseUrl = 'http://localhost:8000';

  // ── Endpoints ──────────────────────────────────────────────────────────────
  static const String textAnalysis = '/api/v1/analyze/text';
  static const String voiceAnalysis = '/api/v1/analyze/voice';
  static const String voiceRealtime = '/api/v1/analyze/voice/realtime';
  static const String imageAnalysis = '/api/v1/analyze/image';
  static const String imageBatch = '/api/v1/analyze/image/batch';
  static const String videoAnalysis = '/api/v1/analyze/video';
  static const String riskCalculate = '/api/v1/score/calculate';
  static const String riskWeights = '/api/v1/score/weights';
  static const String health = '/health';
  static const String status = '/api/v1/status';

  // ── Blockchain Evidence ────────────────────────────────────────────────────
  static const String blockchainReport = '/api/v1/blockchain/report';
  static const String blockchainReports = '/api/v1/blockchain/reports';
  static const String blockchainAnchor = '/api/v1/blockchain/anchor';
  static const String blockchainStatus = '/api/v1/blockchain/status';

  // ── Timeouts ───────────────────────────────────────────────────────────────
  static const Duration defaultTimeout = Duration(seconds: 30);
  static const Duration uploadTimeout = Duration(seconds: 60);
  static const Duration healthTimeout = Duration(seconds: 5);
}

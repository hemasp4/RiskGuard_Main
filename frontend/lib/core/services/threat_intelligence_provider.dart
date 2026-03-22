import 'package:flutter/foundation.dart';
import 'dart:async';
import 'api_service.dart';
import '../models/analysis_models.dart';

class ThreatIntelligenceProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<GlobalThreat> _globalThreats = [];
  List<RiskHotspot> _hotspots = [];
  bool _isLoading = false;
  Timer? _refreshTimer;

  List<GlobalThreat> get globalThreats => _globalThreats;
  List<RiskHotspot> get hotspots => _hotspots;
  bool get isLoading => _isLoading;

  ThreatIntelligenceProvider() {
    init();
  }

  void init() {
    refreshAll();
    // Refresh every 60 seconds for a "live" feel
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) => refreshAll());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> refreshAll() async {
    _isLoading = true;
    notifyListeners();

    final results = await Future.wait([
      _apiService.getGlobalThreats(),
      _apiService.getRiskMap(),
    ]);

    final threatResult = results[0] as ApiResult<List<GlobalThreat>>;
    final hotspotResult = results[1] as ApiResult<List<RiskHotspot>>;

    if (threatResult.isSuccess) {
      _globalThreats = threatResult.data!;
    }
    
    if (hotspotResult.isSuccess) {
      _hotspots = hotspotResult.data!;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<UrlVerificationResult?> verifyUrl(String url) async {
    final result = await _apiService.verifyUrl(url);
    if (result.isSuccess) {
      return result.data;
    }
    return null;
  }
}

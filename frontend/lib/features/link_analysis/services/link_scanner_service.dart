/// Link Scanner Service
///
/// Analyzes URLs for phishing, typosquatting, and other threats.
/// Uses local pattern matching with optional Google Safe Browsing API.
library;

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Result of link analysis
class LinkAnalysisResult {
  final String url;
  final double riskScore;
  final bool isSafe;
  final List<String> warnings;
  final String? domain;
  final bool usedCloudApi;
  final DateTime timestamp;

  const LinkAnalysisResult({
    required this.url,
    required this.riskScore,
    required this.isSafe,
    required this.warnings,
    this.domain,
    this.usedCloudApi = false,
    required this.timestamp,
  });

  String get riskLevel {
    if (riskScore > 0.7) return 'High';
    if (riskScore > 0.4) return 'Medium';
    return 'Low';
  }

  Map<String, dynamic> toJson() => {
    'url': url,
    'riskScore': riskScore,
    'isSafe': isSafe,
    'warnings': warnings,
    'domain': domain,
    'usedCloudApi': usedCloudApi,
    'riskLevel': riskLevel,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Link Scanner Service with local + cloud analysis
class LinkScannerService {
  // Placeholder for Google Safe Browsing API key
  // Replace with your actual API key from Google Cloud Console
  static const String _safeBrowsingApiKey = 'YOUR_GOOGLE_API_KEY_HERE';

  // Google Safe Browsing API endpoint
  static const String _safeBrowsingUrl =
      'https://safebrowsing.googleapis.com/v4/threatMatches:find';

  final Dio _dio = Dio();

  // Singleton pattern
  static final LinkScannerService _instance = LinkScannerService._internal();
  factory LinkScannerService() => _instance;
  LinkScannerService._internal();

  /// Analyze a URL for threats
  Future<LinkAnalysisResult> analyzeUrl(String url) async {
    debugPrint('[LinkScanner] Analyzing: $url');

    final warnings = <String>[];
    double riskScore = 0.0;
    bool usedCloud = false;

    // Normalize URL
    final normalizedUrl = _normalizeUrl(url);
    final uri = Uri.tryParse(normalizedUrl);
    final domain = uri?.host;

    // Step 1: Local pattern analysis (always works)
    final localResult = _analyzeLocally(normalizedUrl);
    riskScore += localResult.score;
    warnings.addAll(localResult.warnings);

    // Step 2: Try Google Safe Browsing API if configured
    if (_isApiConfigured() && riskScore < 0.3) {
      try {
        final cloudResult = await _checkSafeBrowsing(normalizedUrl);
        if (cloudResult.isThreat) {
          riskScore += 0.6;
          warnings.addAll(cloudResult.warnings);
          usedCloud = true;
        }
      } catch (e) {
        debugPrint('[LinkScanner] Safe Browsing API error: $e');
      }
    }

    riskScore = riskScore.clamp(0.0, 1.0);

    return LinkAnalysisResult(
      url: url,
      riskScore: riskScore,
      isSafe: riskScore < 0.4,
      warnings: warnings,
      domain: domain,
      usedCloudApi: usedCloud,
      timestamp: DateTime.now(),
    );
  }

  bool _isApiConfigured() {
    return _safeBrowsingApiKey != 'YOUR_GOOGLE_API_KEY_HERE' &&
        _safeBrowsingApiKey.isNotEmpty;
  }

  String _normalizeUrl(String url) {
    var normalized = url.trim();

    // Add protocol if missing
    if (!normalized.startsWith('http://') &&
        !normalized.startsWith('https://')) {
      normalized = 'https://$normalized';
    }

    return normalized;
  }

  /// Local pattern-based analysis
  _LocalAnalysisResult _analyzeLocally(String url) {
    final warnings = <String>[];
    double score = 0.0;
    final urlLower = url.toLowerCase();
    final uri = Uri.tryParse(url);

    // Check 1: IP-based URL
    if (RegExp(r'https?://\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}').hasMatch(url)) {
      score += 0.35;
      warnings.add('URL uses an IP address instead of a domain name');
    }

    // Check 2: Typosquatting detection
    final typosquatPatterns = {
      'faceb00k': 'Facebook',
      'facebok': 'Facebook',
      'faceboook': 'Facebook',
      'g00gle': 'Google',
      'googl3': 'Google',
      'gooogle': 'Google',
      'amaz0n': 'Amazon',
      'amazn': 'Amazon',
      'paypa1': 'PayPal',
      'app1e': 'Apple',
      'micros0ft': 'Microsoft',
      'netf1ix': 'Netflix',
      'instgram': 'Instagram',
      'instagr4m': 'Instagram',
      'twiter': 'Twitter',
      'linkedln': 'LinkedIn',
      'whatsap': 'WhatsApp',
      'whatapp': 'WhatsApp',
    };

    for (final entry in typosquatPatterns.entries) {
      if (urlLower.contains(entry.key)) {
        score += 0.5;
        warnings.add('URL mimics ${entry.value} (possible typosquatting)');
        break;
      }
    }

    // Check 3: Suspicious TLDs
    final suspiciousTlds = [
      '.xyz',
      '.tk',
      '.ml',
      '.ga',
      '.cf',
      '.gq',
      '.top',
      '.loan',
      '.work',
      '.click',
      '.link',
      '.download',
      '.zip',
      '.review',
      '.country',
    ];

    for (final tld in suspiciousTlds) {
      if (urlLower.endsWith(tld) ||
          urlLower.contains('$tld/') ||
          urlLower.contains('$tld?')) {
        score += 0.25;
        warnings.add('Uses suspicious domain extension ($tld)');
        break;
      }
    }

    // Check 4: Excessive subdomains
    if (uri != null && uri.host.split('.').length > 4) {
      score += 0.2;
      warnings.add('Unusual number of subdomains');
    }

    // Check 5: URL contains urgency/action keywords
    final urgencyPatterns = [
      'verify',
      'confirm',
      'update',
      'secure',
      'login',
      'password',
      'account',
      'suspend',
      'urgent',
      'expire',
      'validate',
      'authenticate',
      'unlock',
    ];

    int urgencyCount = 0;
    for (final pattern in urgencyPatterns) {
      if (urlLower.contains(pattern)) {
        urgencyCount++;
      }
    }
    if (urgencyCount >= 2) {
      score += 0.15;
      warnings.add('URL contains multiple action keywords');
    }

    // Check 6: Suspicious characters
    if (url.contains('@') || url.contains('%40')) {
      score += 0.3;
      warnings.add('URL contains @ symbol (possible URL obfuscation)');
    }

    // Check 7: Very long URL
    if (url.length > 200) {
      score += 0.1;
      warnings.add('Unusually long URL');
    }

    // Check 8: No HTTPS
    if (url.startsWith('http://') && !url.contains('localhost')) {
      score += 0.1;
      warnings.add('Not using secure HTTPS connection');
    }

    // Check 9: Multiple redirects in URL
    if (urlLower.contains('redirect') ||
        urlLower.contains('redir') ||
        urlLower.contains('goto')) {
      score += 0.15;
      warnings.add('URL contains redirect parameters');
    }

    // Check 10: Encoded characters
    if (RegExp(r'%[0-9a-fA-F]{2}').allMatches(url).length > 5) {
      score += 0.1;
      warnings.add('URL contains many encoded characters');
    }

    return _LocalAnalysisResult(
      score: score.clamp(0.0, 1.0),
      warnings: warnings,
    );
  }

  /// Check URL against Google Safe Browsing API
  Future<_CloudAnalysisResult> _checkSafeBrowsing(String url) async {
    final requestBody = {
      'client': {'clientId': 'riskguard', 'clientVersion': '1.0.0'},
      'threatInfo': {
        'threatTypes': [
          'MALWARE',
          'SOCIAL_ENGINEERING',
          'UNWANTED_SOFTWARE',
          'POTENTIALLY_HARMFUL_APPLICATION',
        ],
        'platformTypes': ['ANY_PLATFORM'],
        'threatEntryTypes': ['URL'],
        'threatEntries': [
          {'url': url},
        ],
      },
    };

    final response = await _dio.post(
      '$_safeBrowsingUrl?key=$_safeBrowsingApiKey',
      data: json.encode(requestBody),
      options: Options(headers: {'Content-Type': 'application/json'}),
    );

    if (response.data != null && response.data['matches'] != null) {
      final matches = response.data['matches'] as List;
      if (matches.isNotEmpty) {
        final threats = matches.map((m) => m['threatType'].toString()).toList();
        return _CloudAnalysisResult(
          isThreat: true,
          warnings: threats
              .map((t) => 'Google Safe Browsing: $t detected')
              .toList(),
        );
      }
    }

    return const _CloudAnalysisResult(isThreat: false, warnings: []);
  }

  /// Quick check if URL looks suspicious (no async)
  bool isObviouslySuspicious(String url) {
    final local = _analyzeLocally(url);
    return local.score > 0.5;
  }

  /// Extract domain from URL
  String? extractDomain(String url) {
    try {
      final normalized = _normalizeUrl(url);
      return Uri.parse(normalized).host;
    } catch (e) {
      return null;
    }
  }

  /// Get human-readable summary
  String getSummary(LinkAnalysisResult result) {
    if (result.isSafe) {
      return 'This link appears to be safe.';
    }

    if (result.riskScore > 0.7) {
      return 'High risk detected! ${result.warnings.first}';
    }

    return 'Some suspicious patterns detected. ${result.warnings.first}';
  }
}

class _LocalAnalysisResult {
  final double score;
  final List<String> warnings;

  const _LocalAnalysisResult({required this.score, required this.warnings});
}

class _CloudAnalysisResult {
  final bool isThreat;
  final List<String> warnings;

  const _CloudAnalysisResult({required this.isThreat, required this.warnings});
}

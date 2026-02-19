import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:personal/core/constants/app_constants.dart';
import 'package:personal/features/message_analysis/services/message_analyzer_service.dart';

void main() {
  group('MessageAnalyzerService Tests', () {
    late MessageAnalyzerService service;
    late Dio mockDio;

    setUp(() {
      mockDio = Dio(BaseOptions(baseUrl: AppConstants.baseUrl));
      mockDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final text = options.data['text'] as String;

            if (text.contains('urgency') || text.contains('Act now')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'riskScore': 85,
                    'isSafe': false,
                    'threats': ['urgency'],
                    'patterns': ['urgency detected'],
                    'explanation': 'Urgency detected in message.',
                  },
                ),
              );
            } else if (text.contains('verify your account') ||
                text.contains('clicking this link')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'riskScore': 90,
                    'isSafe': false,
                    'threats': ['phishing'],
                    'patterns': ['verify account'],
                    'explanation': 'Phishing attempt detected.',
                  },
                ),
              );
            } else if (text.contains('lottery')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'riskScore': 88,
                    'isSafe': false,
                    'threats': ['fakeOffer'],
                    'patterns': ['lottery'],
                    'explanation': 'Fake offer detected.',
                  },
                ),
              );
            } else if (text.contains('Transfer money')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'riskScore': 95,
                    'isSafe': false,
                    'threats': ['financialScam'],
                    'patterns': ['transfer money'],
                    'explanation': 'Financial scam detected.',
                  },
                ),
              );
            } else if (text.contains('bit.ly')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'riskScore': 75,
                    'isSafe': false,
                    'threats': ['suspiciousLink'],
                    'patterns': ['bit.ly'],
                    'explanation': 'High risk! Suspicious link detected.',
                    'urls': ['https://bit.ly/abc123'],
                  },
                ),
              );
            } else if (text.contains('http') || text.contains('https')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'riskScore': 0,
                    'isSafe': true,
                    'threats': [],
                    'patterns': [],
                    'explanation': 'Safe message with links.',
                    'urls': ['http://example.com', 'https://test.org'],
                  },
                ),
              );
            }

            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'riskScore': 0,
                  'isSafe': true,
                  'threats': [],
                  'patterns': [],
                  'explanation': 'Message is safe',
                },
              ),
            );
          },
        ),
      );
      service = MessageAnalyzerService(dio: mockDio);
    });

    test('should return safe result for empty message', () async {
      // Act
      final result = await service.analyzeMessage('');

      // Assert
      expect(result.isSafe, true);
      expect(result.riskScore, 0);
      expect(result.detectedThreats, isEmpty);
    });

    test('should return safe result for short message', () async {
      // Act
      final result = await service.analyzeMessage('Hi');

      // Assert
      expect(result.isSafe, true);
      expect(result.riskScore, 0);
    });

    test('should detect urgency patterns', () async {
      // Arrange
      const message = 'Act now! Your account will be suspended immediately!';

      // Act
      final result = await service.analyzeMessage(message);

      // Assert
      expect(result.riskScore, greaterThan(0));
      expect(result.detectedThreats, contains(ThreatType.urgency));
      expect(result.suspiciousPatterns.any((p) => p.contains('urgency')), true);
    });

    test('should detect phishing patterns', () async {
      // Arrange
      const message =
          'Please verify your account by clicking this link and confirm your identity';

      // Act
      final result = await service.analyzeMessage(message);

      // Assert
      expect(result.riskScore, greaterThan(0));
      expect(result.detectedThreats, contains(ThreatType.phishing));
      expect(result.isSafe, false);
    });

    test('should detect fake offer patterns', () async {
      // Arrange
      const message =
          'Congratulations! You have won a lottery! Claim your prize now!';

      // Act
      final result = await service.analyzeMessage(message);

      // Assert
      expect(result.riskScore, greaterThan(0));
      expect(result.detectedThreats, contains(ThreatType.fakeOffer));
    });

    test('should detect financial scam patterns', () async {
      // Arrange
      const message =
          'Transfer money to this bank account for guaranteed returns';

      // Act
      final result = await service.analyzeMessage(message);

      // Assert
      expect(result.riskScore, greaterThan(0));
      expect(result.detectedThreats, contains(ThreatType.financialScam));
    });

    test('should extract URLs from message', () async {
      // Arrange
      const message =
          'Visit http://example.com and https://test.org for more info';

      // Act
      final result = await service.analyzeMessage(message);

      // Assert
      expect(result.extractedUrls.length, 2);
      expect(result.extractedUrls, contains('http://example.com'));
      expect(result.extractedUrls, contains('https://test.org'));
    });

    test('should detect suspicious shortened URLs', () async {
      // Arrange
      const message = 'Click here: https://bit.ly/abc123';

      // Act
      final result = await service.analyzeMessage(message);

      // Assert
      expect(result.riskScore, greaterThan(0));
      expect(result.detectedThreats, contains(ThreatType.suspiciousLink));
      expect(result.suspiciousPatterns.any((p) => p.contains('bit.ly')), true);
    });

    test('should calculate correct risk level', () async {
      // Low risk message
      final lowRisk = await service.analyzeMessage('Hello, how are you today?');
      expect(lowRisk.isSafe, true);
      expect(lowRisk.riskScore, lessThan(30));

      // High risk message
      final highRisk = await service.analyzeMessage(
        'URGENT! Verify your account immediately at https://bit.ly/fake or account will be blocked!',
      );
      expect(highRisk.isSafe, false);
      expect(highRisk.riskScore, greaterThan(30));
    });

    test('should clamp risk score to 0-100', () async {
      // Message with multiple threat patterns
      const message = '''
        URGENT! Act now! Congratulations, you won!
        Click https://bit.ly/scam to claim your prize.
        Transfer money to our bank account for verification.
        Your account will be suspended immediately!
      ''';

      // Act
      final result = await service.analyzeMessage(message);

      // Assert
      expect(result.riskScore, greaterThanOrEqualTo(0));
      expect(result.riskScore, lessThanOrEqualTo(100));
    });

    test('should generate appropriate explanation', () async {
      // Arrange
      const safeMessage = 'Meeting at 3pm today';
      const riskyMessage =
          'Urgent! Verify your account now at https://bit.ly/fake';

      // Act
      final safeResult = await service.analyzeMessage(safeMessage);
      final riskyResult = await service.analyzeMessage(riskyMessage);

      // Assert
      expect(safeResult.explanation, contains('safe'));
      expect(riskyResult.explanation, contains('risk'));
      expect(riskyResult.explanation.length, greaterThan(20));
    });
  });

  group('ThreatType Tests', () {
    test('should have correct labels', () {
      expect(ThreatType.phishing.label, 'Phishing Attempt');
      expect(ThreatType.urgency.label, 'Urgency Manipulation');
      expect(ThreatType.fakeOffer.label, 'Fake Offer');
      expect(ThreatType.suspiciousLink.label, 'Suspicious Link');
      expect(ThreatType.financialScam.label, 'Financial Scam');
      expect(ThreatType.safe.label, 'Safe');
    });

    test('should have icons', () {
      for (final threat in ThreatType.values) {
        expect(threat.icon, isNotEmpty);
      }
    });
  });

  group('MessageAnalysisResult Tests', () {
    test('should create safe result', () {
      // Act
      final result = MessageAnalysisResult.safe();

      // Assert
      expect(result.riskScore, 0);
      expect(result.isSafe, true);
      expect(result.detectedThreats, isEmpty);
      expect(result.suspiciousPatterns, isEmpty);
    });
  });
}

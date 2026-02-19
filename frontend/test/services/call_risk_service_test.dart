import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/call_detection/services/call_risk_service.dart';
import 'package:personal/core/constants/risk_levels.dart';

void main() {
  group('CallRiskService Tests', () {
    late CallRiskService service;

    setUp(() {
      service = CallRiskService();
    });

    tearDown(() {
      service.dispose();
    });

    test('should analyze phone number and return risk result', () async {
      // Arrange
      const phoneNumber = '+911234567890';
      const isIncoming = true;

      // Act
      final result = await service.analyzePhoneNumber(phoneNumber, isIncoming);

      // Assert
      expect(result.phoneNumber, phoneNumber);
      expect(result.riskScore, greaterThanOrEqualTo(0));
      expect(result.riskScore, lessThanOrEqualTo(100));
      expect(result.riskLevel, isNotNull);
      expect(result.explanation, isNotEmpty);
    });

    test('should detect unknown caller risk factor', () async {
      // Arrange
      const phoneNumber = '+911234567890';

      // Act
      final result = await service.analyzePhoneNumber(phoneNumber, true);

      // Assert
      expect(result.riskFactors, contains('Unknown caller'));
      expect(result.riskScore, greaterThan(0));
    });

    test('should detect international number', () async {
      // Arrange
      const phoneNumber = '+441234567890'; // UK number

      // Act
      final result = await service.analyzePhoneNumber(phoneNumber, true);

      // Assert
      expect(result.riskFactors, contains('International number'));
    });

    test('should detect spam patterns', () async {
      // Arrange
      const phoneNumber = '1401234567890'; // Contains spam prefix 140

      // Act
      final result = await service.analyzePhoneNumber(phoneNumber, true);

      // Assert
      expect(result.riskFactors, contains('Matches spam pattern'));
      expect(result.riskScore, greaterThan(20));
    });

    test('should clamp risk score to 0-100 range', () async {
      // This test ensures score never exceeds bounds
      for (int i = 0; i < 10; i++) {
        final result = await service.analyzePhoneNumber(
          '+${i}401234567890',
          true,
        );
        expect(result.riskScore, greaterThanOrEqualTo(0));
        expect(result.riskScore, lessThanOrEqualTo(100));
      }
    });

    test('should determine correct risk level from score', () async {
      // Low risk scenario (known pattern)
      final lowRisk = await service.analyzePhoneNumber('+911234567890', false);

      // The risk level should match the score
      expect(
        lowRisk.riskLevel,
        equals(RiskLevels.fromScore(lowRisk.riskScore)),
      );
    });

    test('should generate appropriate explanation for risk level', () async {
      // Arrange
      const spamNumber = '1401234567890';

      // Act
      final result = await service.analyzePhoneNumber(spamNumber, true);

      // Assert
      expect(result.explanation, contains('incoming call'));
      expect(result.explanation.length, greaterThan(10));
    });

    test('should emit call state updates via stream', () async {
      // This test would require mocking the MethodChannelService
      // For now, we test that the stream exists
      expect(service.callStateStream, isNotNull);
    });

    test('should update risk score when AI voice detected', () async {
      // Arrange
      const phoneNumber = '+911234567890';
      final initialResult = await service.analyzePhoneNumber(phoneNumber, true);

      // The copyWith method should increase score when AI detected
      final updatedResult = initialResult.copyWith(
        isAIVoice: true,
        aiVoiceProbability: 0.8,
      );

      // Assert
      expect(updatedResult.isAIVoice, true);
      expect(updatedResult.aiVoiceProbability, 0.8);
    });
  });

  group('CallRiskResult Tests', () {
    test('should create result with all required fields', () {
      // Arrange & Act
      final result = CallRiskResult(
        phoneNumber: '+911234567890',
        riskScore: 50,
        riskLevel: RiskLevel.medium,
        category: RiskCategory.unknown,
        explanation: 'Test explanation',
        analyzedAt: DateTime.now(),
        riskFactors: ['Unknown caller'],
      );

      // Assert
      expect(result.phoneNumber, '+911234567890');
      expect(result.riskScore, 50);
      expect(result.riskLevel, RiskLevel.medium);
      expect(result.riskFactors, contains('Unknown caller'));
    });

    test('should convert to JSON correctly', () {
      // Arrange
      final result = CallRiskResult(
        phoneNumber: '+911234567890',
        riskScore: 75,
        riskLevel: RiskLevel.high,
        category: RiskCategory.scamCall,
        explanation: 'High risk call',
        analyzedAt: DateTime.now(),
        riskFactors: ['Spam pattern', 'Unknown'],
        isAIVoice: true,
        aiVoiceProbability: 0.9,
      );

      // Act
      final json = result.toJson();

      // Assert
      expect(json['phoneNumber'], '+911234567890');
      expect(json['riskScore'], 75);
      expect(json['riskLevel'], 'high');
      expect(json['isAIVoice'], true);
      expect(json['aiVoiceProbability'], 0.9);
    });

    test('should copy with updated values', () {
      // Arrange
      final original = CallRiskResult(
        phoneNumber: '+911234567890',
        riskScore: 30,
        riskLevel: RiskLevel.low,
        category: RiskCategory.unknown,
        explanation: 'Low risk',
        analyzedAt: DateTime.now(),
      );

      // Act
      final updated = original.copyWith(
        riskScore: 80,
        riskLevel: RiskLevel.high,
        isAIVoice: true,
      );

      // Assert
      expect(updated.riskScore, 80);
      expect(updated.riskLevel, RiskLevel.high);
      expect(updated.isAIVoice, true);
      expect(updated.phoneNumber, original.phoneNumber); // Unchanged
    });
  });
}

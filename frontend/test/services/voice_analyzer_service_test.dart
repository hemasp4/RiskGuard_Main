import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/voice_analysis/services/voice_analyzer_service.dart';

void main() {
  group('VoiceAnalyzerService Tests', () {
    late VoiceAnalyzerService service;

    setUp(() {
      service = VoiceAnalyzerService();
    });

    test('should analyze audio and return result', () async {
      // Arrange
      const audioPath = '/path/to/test/audio.m4a';

      // Act
      final result = await service.analyzeAudio(audioPath);

      // Assert
      expect(result, isNotNull);
      expect(result.syntheticProbability, greaterThanOrEqualTo(0.0));
      expect(result.syntheticProbability, lessThanOrEqualTo(1.0));
      expect(result.confidence, greaterThanOrEqualTo(0.0));
      expect(result.confidence, lessThanOrEqualTo(1.0));
      expect(result.explanation, isNotEmpty);
      expect(result.classification, isNotNull);
    });

    test('should classify as human for low synthetic probability', () async {
      // This test verifies the classification thresholds
      // Since local analysis uses random values, we test multiple times
      bool foundHumanClassification = false;

      for (int i = 0; i < 10; i++) {
        final result = await service.analyzeAudio('/test/audio$i.m4a');
        if (result.classification == VoiceClassification.human) {
          foundHumanClassification = true;
          expect(result.syntheticProbability, lessThan(0.35));
          expect(result.isLikelyAI, false);
          break;
        }
      }

      // At least one should be human in 10 tries (probability based)
      expect(foundHumanClassification, true);
    });

    test('should classify as uncertain for moderate probability', () async {
      // Test that uncertain classification exists
      bool foundUncertainClassification = false;

      for (int i = 0; i < 20; i++) {
        final result = await service.analyzeAudio('/test/audio$i.m4a');
        if (result.classification == VoiceClassification.uncertain) {
          foundUncertainClassification = true;
          expect(result.syntheticProbability, greaterThanOrEqualTo(0.35));
          expect(result.syntheticProbability, lessThan(0.65));
          break;
        }
      }

      expect(foundUncertainClassification, true);
    });

    test('should return default result on error', () async {
      // Arrange - Using invalid path to trigger error
      const invalidPath = '';

      // Act
      final result = await service.analyzeAudio(invalidPath);

      // Assert - Should return safe default
      expect(result.syntheticProbability, 0.0);
      expect(result.confidence, 0.0);
      expect(result.classification, VoiceClassification.uncertain);
      expect(result.explanation, contains('Unable to analyze'));
    });

    test('should include detected patterns for high probability', () async {
      // Run multiple times to find a high-probability result
      bool foundPatternsTest = false;

      for (int i = 0; i < 20; i++) {
        final result = await service.analyzeAudio('/test/audio$i.m4a');
        if (result.syntheticProbability > 0.3) {
          foundPatternsTest = true;
          expect(result.detectedPatterns, isNotEmpty);
          break;
        }
      }

      // Should find at least one with patterns
      expect(foundPatternsTest, true);
    });
  });

  group('VoiceAnalysisResult Tests', () {
    test('should create result with all fields', () {
      // Arrange & Act
      final result = VoiceAnalysisResult(
        syntheticProbability: 0.5,
        confidence: 0.8,
        detectedPatterns: ['Pattern 1', 'Pattern 2'],
        explanation: 'Test explanation',
        isLikelyAI: false,
        classification: VoiceClassification.uncertain,
      );

      // Assert
      expect(result.syntheticProbability, 0.5);
      expect(result.confidence, 0.8);
      expect(result.detectedPatterns.length, 2);
      expect(result.isLikelyAI, false);
      expect(result.classification, VoiceClassification.uncertain);
    });

    test('should convert to JSON correctly', () {
      // Arrange
      final result = VoiceAnalysisResult(
        syntheticProbability: 0.7,
        confidence: 0.9,
        detectedPatterns: ['Unusual pitch'],
        explanation: 'AI detected',
        isLikelyAI: true,
        classification: VoiceClassification.aiGenerated,
      );

      // Act
      final json = result.toJson();

      // Assert
      expect(json['syntheticProbability'], 0.7);
      expect(json['confidence'], 0.9);
      expect(json['isLikelyAI'], true);
      expect(json['classification'], 'aiGenerated');
      expect(json['detectedPatterns'], contains('Unusual pitch'));
    });

    test('should create from JSON correctly', () {
      // Arrange
      final json = {
        'syntheticProbability': 0.6,
        'confidence': 0.85,
        'detectedPatterns': ['Pattern A'],
        'explanation': 'Test',
        'isLikelyAI': true,
      };

      // Act
      final result = VoiceAnalysisResult.fromJson(json);

      // Assert
      expect(result.syntheticProbability, 0.6);
      expect(result.confidence, 0.85);
      expect(result.classification, VoiceClassification.aiGenerated); // >0.65
    });
  });

  group('VoiceClassification Tests', () {
    test('should have correct labels', () {
      expect(VoiceClassification.human.label, 'Human Voice');
      expect(VoiceClassification.aiGenerated.label, 'AI Generated');
      expect(VoiceClassification.uncertain.label, 'Uncertain');
    });

    test('should have correct icons', () {
      expect(VoiceClassification.human.icon, '👤');
      expect(VoiceClassification.aiGenerated.icon, '🤖');
      expect(VoiceClassification.uncertain.icon, '❓');
    });
  });
}

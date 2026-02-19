import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'package:personal/core/constants/app_constants.dart';
import 'package:personal/features/video_analysis/services/video_analyzer_service.dart';

void main() {
  group('VideoAnalyzerService Tests', () {
    late VideoAnalyzerService service;
    late Dio mockDio;

    int mockCounter = 0;
    late File tempFile;

    setUp(() async {
      mockCounter = 0;
      mockDio = Dio(BaseOptions(baseUrl: AppConstants.baseUrl));

      // Create a dummy video file
      tempFile = File('./test_video.mp4');
      if (!await tempFile.exists()) {
        await tempFile.create();
        await tempFile.writeAsString('dummy content');
      }

      mockDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            // Deterministic mock logic
            mockCounter++;
            final isDeepfake = mockCounter % 2 == 0;

            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'deepfakeProbability': isDeepfake ? 0.9 : 0.1,
                  'confidence': 0.95,
                  'analyzedFrames': 30,
                  'frameResults': [],
                  'detectedPatterns': isDeepfake ? ['deepfake'] : [],
                  'explanation': isDeepfake
                      ? 'Deepfake detected'
                      : 'Authentic video.',
                  'isDeepfake': isDeepfake,
                },
              ),
            );
          },
        ),
      );

      service = VideoAnalyzerService(
        dio: mockDio,
        fileExistsChecker: (path) async => true,
      );
    });

    tearDown(() async {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    });

    test('should analyze video and return result', () async {
      // Act
      final result = await service.analyzeVideo(tempFile.path);

      // Assert
      expect(result, isNotNull);
      expect(result.videoPath, tempFile.path);
      expect(result.deepfakeProbability, greaterThanOrEqualTo(0.0));
      expect(result.deepfakeProbability, lessThanOrEqualTo(1.0));
    });

    test('should classify as authentic for low deepfake probability', () async {
      // Run multiple analyses to find authentic classification
      bool foundAuthentic = false;

      for (int i = 0; i < 10; i++) {
        final result = await service.analyzeVideo(tempFile.path);
        if (result.isAuthentic) {
          foundAuthentic = true;
          expect(result.deepfakeProbability, lessThan(0.2));
          break;
        }
      }

      expect(foundAuthentic, true);
    });

    test('should detect manipulation patterns for high probability', () async {
      // Run multiple analyses to find manipulation
      bool foundManipulation = false;

      for (int i = 0; i < 20; i++) {
        final result = await service.analyzeVideo(tempFile.path);
        if (!result.isAuthentic) {
          foundManipulation = true;
          expect(result.deepfakeProbability, greaterThanOrEqualTo(0.2));
          expect(result.manipulationPatterns, isNotEmpty);
          break;
        }
      }

      expect(foundManipulation, true);
    });

    test('should handle errors gracefully', () async {
      // Arrange - empty path to trigger error
      const invalidPath = '';

      // Act
      final result = await service.analyzeVideo(invalidPath);

      // Assert - Should return safe default
      expect(result.isAuthentic, true);
      expect(result.deepfakeProbability, 0.0);
    });

    test('should extract frames during analysis', () async {
      // Arrange
      const videoPath = '/test/video.mp4';

      // Act
      final result = await service.analyzeVideo(videoPath);

      // Assert - Should have attempted frame extraction
      expect(result.analyzedFrames, greaterThanOrEqualTo(0));
    });
  });

  group('VideoAnalysisResult Tests', () {
    test('should create result with all fields', () {
      // Arrange & Act
      final result = VideoAnalysisResult(
        videoPath: '/test/video.mp4',
        deepfakeProbability: 0.7,
        confidence: 0.85,
        detectedThreats: [VideoThreatType.deepfake],
        manipulationPatterns: ['Pattern 1'],
        analyzedFrames: 10,
        frameResults: [],
        explanation: 'Deepfake detected',
        isAuthentic: false,
        analyzedAt: DateTime.now(),
      );

      // Assert
      expect(result.deepfakeProbability, 0.7);
      expect(result.confidence, 0.85);
      expect(result.detectedThreats, contains(VideoThreatType.deepfake));
      expect(result.isAuthentic, false);
    });

    test('should create safe result', () {
      // Act
      final result = VideoAnalysisResult.safe('/test/video.mp4');

      // Assert
      expect(result.isAuthentic, true);
      expect(result.deepfakeProbability, 0.0);
      expect(result.detectedThreats, contains(VideoThreatType.safe));
      expect(result.manipulationPatterns, isEmpty);
    });

    test('should convert to JSON correctly', () {
      // Arrange
      final result = VideoAnalysisResult(
        videoPath: '/test/video.mp4',
        deepfakeProbability: 0.5,
        confidence: 0.8,
        detectedThreats: [VideoThreatType.manipulation],
        manipulationPatterns: ['Artifact detected'],
        analyzedFrames: 5,
        frameResults: [],
        explanation: 'Test explanation',
        isAuthentic: false,
        analyzedAt: DateTime.now(),
      );

      // Act
      final json = result.toJson();

      // Assert
      expect(json['videoPath'], '/test/video.mp4');
      expect(json['deepfakeProbability'], 0.5);
      expect(json['confidence'], 0.8);
      expect(json['isAuthentic'], false);
      expect(json['detectedThreats'], contains('manipulation'));
    });
  });

  group('VideoThreatType Tests', () {
    test('should have correct labels', () {
      expect(VideoThreatType.deepfake.label, 'Deepfake Detected');
      expect(VideoThreatType.faceSwap.label, 'Face Swap');
      expect(VideoThreatType.lipSync.label, 'Lip Sync Manipulation');
      expect(VideoThreatType.manipulation.label, 'Video Manipulation');
      expect(VideoThreatType.safe.label, 'Authentic Video');
    });

    test('should have icons', () {
      for (final threat in VideoThreatType.values) {
        expect(threat.icon, isNotEmpty);
      }
    });
  });
}

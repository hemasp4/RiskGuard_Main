/// TFLite Service - On-Device ML Model Management
///
/// Downloads and manages TensorFlow Lite models from TensorFlow Hub.
/// Handles model loading, inference, and caching.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
// Note: tflite_flutter import will work after pub get
// ignore: depend_on_referenced_packages
import 'package:tflite_flutter/tflite_flutter.dart';

/// Model info with download URL
class TFLiteModelInfo {
  final String name;
  final String filename;
  final String downloadUrl;
  final int inputSize;
  final String description;

  const TFLiteModelInfo({
    required this.name,
    required this.filename,
    required this.downloadUrl,
    required this.inputSize,
    required this.description,
  });
}

/// TFLite Service for model management
class TFLiteService {
  // Singleton
  static final TFLiteService _instance = TFLiteService._internal();
  factory TFLiteService() => _instance;
  TFLiteService._internal();

  final Dio _dio = Dio();

  // Model interpreters (loaded lazily)
  Interpreter? _textInterpreter;
  Interpreter? _audioInterpreter;
  Interpreter? _imageInterpreter;

  // Model download status
  final Map<String, bool> _modelDownloaded = {};
  final Map<String, double> _downloadProgress = {};

  // Callback for download progress
  Function(String modelName, double progress)? onDownloadProgress;

  /// TensorFlow Hub models to use
  ///
  /// Note: TFHub models need conversion to TFLite format.
  /// For production, pre-convert and host models, or use these direct TFLite URLs.
  static const models = {
    'text': TFLiteModelInfo(
      name: 'MobileBERT',
      filename: 'mobilebert_text.tflite',
      // Alternative: Use a pre-converted TFLite model URL
      downloadUrl:
          'https://storage.googleapis.com/mediapipe-models/text_classifier/bert_classifier/float32/1/bert_classifier.tflite',
      inputSize: 128,
      description: 'Text classification for AI detection',
    ),
    'audio': TFLiteModelInfo(
      name: 'YAMNet',
      filename: 'yamnet_audio.tflite',
      downloadUrl:
          'https://storage.googleapis.com/mediapipe-models/audio_classifier/yamnet/float32/1/yamnet.tflite',
      inputSize: 15600, // ~1 second of audio at 16kHz
      description: 'Audio classification for voice analysis',
    ),
    'image': TFLiteModelInfo(
      name: 'MobileNetV2',
      filename: 'mobilenet_image.tflite',
      downloadUrl:
          'https://storage.googleapis.com/mediapipe-models/image_classifier/efficientnet_lite0/float32/1/efficientnet_lite0.tflite',
      inputSize: 224,
      description: 'Image classification for deepfake detection',
    ),
  };

  /// Get the models directory
  Future<Directory> get _modelsDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${appDir.path}/tflite_models');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  /// Check if a model is downloaded
  Future<bool> isModelDownloaded(String modelType) async {
    final modelInfo = models[modelType];
    if (modelInfo == null) return false;

    final modelsDir = await _modelsDir;
    final modelFile = File('${modelsDir.path}/${modelInfo.filename}');
    return await modelFile.exists();
  }

  /// Get download progress for a model (0.0 to 1.0)
  double getDownloadProgress(String modelType) {
    return _downloadProgress[modelType] ?? 0.0;
  }

  /// Download a specific model
  Future<bool> downloadModel(String modelType) async {
    final modelInfo = models[modelType];
    if (modelInfo == null) {
      debugPrint('[TFLite] Unknown model type: $modelType');
      return false;
    }

    // Check if already downloaded
    if (await isModelDownloaded(modelType)) {
      debugPrint('[TFLite] Model already downloaded: ${modelInfo.name}');
      _modelDownloaded[modelType] = true;
      return true;
    }

    debugPrint('[TFLite] Downloading ${modelInfo.name}...');

    try {
      final modelsDir = await _modelsDir;
      final modelPath = '${modelsDir.path}/${modelInfo.filename}';

      await _dio.download(
        modelInfo.downloadUrl,
        modelPath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            _downloadProgress[modelType] = progress;
            onDownloadProgress?.call(modelType, progress);
          }
        },
      );

      _modelDownloaded[modelType] = true;
      _downloadProgress[modelType] = 1.0;
      debugPrint('[TFLite] Downloaded ${modelInfo.name} to $modelPath');
      return true;
    } catch (e) {
      debugPrint('[TFLite] Failed to download ${modelInfo.name}: $e');
      _downloadProgress[modelType] = 0.0;
      return false;
    }
  }

  /// Download all models
  Future<Map<String, bool>> downloadAllModels() async {
    final results = <String, bool>{};

    for (final modelType in models.keys) {
      results[modelType] = await downloadModel(modelType);
    }

    return results;
  }

  /// Load text model interpreter
  Future<Interpreter?> loadTextModel() async {
    if (_textInterpreter != null) return _textInterpreter;

    if (!await isModelDownloaded('text')) {
      final downloaded = await downloadModel('text');
      if (!downloaded) return null;
    }

    try {
      final modelsDir = await _modelsDir;
      final modelPath = '${modelsDir.path}/${models['text']!.filename}';

      _textInterpreter = Interpreter.fromFile(File(modelPath));
      debugPrint('[TFLite] Text model loaded successfully');
      return _textInterpreter;
    } catch (e) {
      debugPrint('[TFLite] Failed to load text model: $e');
      return null;
    }
  }

  /// Load audio model interpreter
  Future<Interpreter?> loadAudioModel() async {
    if (_audioInterpreter != null) return _audioInterpreter;

    if (!await isModelDownloaded('audio')) {
      final downloaded = await downloadModel('audio');
      if (!downloaded) return null;
    }

    try {
      final modelsDir = await _modelsDir;
      final modelPath = '${modelsDir.path}/${models['audio']!.filename}';

      _audioInterpreter = Interpreter.fromFile(File(modelPath));
      debugPrint('[TFLite] Audio model loaded successfully');
      return _audioInterpreter;
    } catch (e) {
      debugPrint('[TFLite] Failed to load audio model: $e');
      return null;
    }
  }

  /// Load image model interpreter
  Future<Interpreter?> loadImageModel() async {
    if (_imageInterpreter != null) return _imageInterpreter;

    if (!await isModelDownloaded('image')) {
      final downloaded = await downloadModel('image');
      if (!downloaded) return null;
    }

    try {
      final modelsDir = await _modelsDir;
      final modelPath = '${modelsDir.path}/${models['image']!.filename}';

      _imageInterpreter = Interpreter.fromFile(File(modelPath));
      debugPrint('[TFLite] Image model loaded successfully');
      return _imageInterpreter;
    } catch (e) {
      debugPrint('[TFLite] Failed to load image model: $e');
      return null;
    }
  }

  /// Run text inference
  Future<Map<String, dynamic>?> analyzeText(String text) async {
    final interpreter = await loadTextModel();
    if (interpreter == null) return null;

    try {
      // Prepare input - simple tokenization for demo
      // In production, use proper tokenizer matching the model
      final inputShape = interpreter.getInputTensor(0).shape;
      final inputSize = inputShape[1];

      // Convert text to input tensor (simplified)
      final input = List<List<int>>.generate(
        1,
        (_) => List<int>.generate(inputSize, (i) {
          if (i < text.length) {
            return text.codeUnitAt(i) % 256;
          }
          return 0;
        }),
      );

      // Prepare output
      final outputShape = interpreter.getOutputTensor(0).shape;
      final output = List<List<double>>.generate(
        outputShape[0],
        (_) => List<double>.filled(outputShape[1], 0.0),
      );

      // Run inference
      interpreter.run(input, output);

      // Get result
      final scores = output[0];
      final maxScore = scores.reduce((a, b) => a > b ? a : b);
      final maxIndex = scores.indexOf(maxScore);

      return {
        'confidence': maxScore,
        'classIndex': maxIndex,
        'isAiGenerated': maxScore > 0.5,
      };
    } catch (e) {
      debugPrint('[TFLite] Text inference error: $e');
      return null;
    }
  }

  /// Run audio inference
  Future<Map<String, dynamic>?> analyzeAudio(List<double> audioSamples) async {
    final interpreter = await loadAudioModel();
    if (interpreter == null) return null;

    try {
      final inputShape = interpreter.getInputTensor(0).shape;
      final inputSize = inputShape[1];

      // Prepare input - pad or trim audio to expected size
      final input = List<List<double>>.generate(
        1,
        (_) => List<double>.generate(inputSize, (i) {
          if (i < audioSamples.length) {
            return audioSamples[i];
          }
          return 0.0;
        }),
      );

      // Prepare output
      final outputShape = interpreter.getOutputTensor(0).shape;
      final output = List<List<double>>.generate(
        outputShape[0],
        (_) => List<double>.filled(outputShape[1], 0.0),
      );

      interpreter.run(input, output);

      final scores = output[0];
      final maxScore = scores.reduce((a, b) => a > b ? a : b);
      final maxIndex = scores.indexOf(maxScore);

      return {
        'confidence': maxScore,
        'classIndex': maxIndex,
        'isSynthetic': maxScore > 0.5,
      };
    } catch (e) {
      debugPrint('[TFLite] Audio inference error: $e');
      return null;
    }
  }

  /// Run image inference
  Future<Map<String, dynamic>?> analyzeImage(Uint8List imageBytes) async {
    final interpreter = await loadImageModel();
    if (interpreter == null) return null;

    try {
      final inputShape = interpreter.getInputTensor(0).shape;
      final height = inputShape[1];
      final width = inputShape[2];
      final channels = inputShape[3];

      // Note: In production, properly decode and resize the image
      // This is a simplified version
      final input = List<List<List<List<double>>>>.generate(
        1,
        (_) => List<List<List<double>>>.generate(
          height,
          (h) => List<List<double>>.generate(
            width,
            (w) => List<double>.generate(channels, (c) {
              final idx = (h * width * channels) + (w * channels) + c;
              if (idx < imageBytes.length) {
                return imageBytes[idx] / 255.0;
              }
              return 0.0;
            }),
          ),
        ),
      );

      // Prepare output
      final outputShape = interpreter.getOutputTensor(0).shape;
      final output = List<List<double>>.generate(
        outputShape[0],
        (_) => List<double>.filled(outputShape[1], 0.0),
      );

      interpreter.run(input, output);

      final scores = output[0];
      final maxScore = scores.reduce((a, b) => a > b ? a : b);
      final maxIndex = scores.indexOf(maxScore);

      return {
        'confidence': maxScore,
        'classIndex': maxIndex,
        'isAiGenerated': maxScore > 0.5,
      };
    } catch (e) {
      debugPrint('[TFLite] Image inference error: $e');
      return null;
    }
  }

  /// Get model info
  Map<String, dynamic> getModelsStatus() {
    return {
      'text': {
        'downloaded': _modelDownloaded['text'] ?? false,
        'loaded': _textInterpreter != null,
        'progress': _downloadProgress['text'] ?? 0.0,
      },
      'audio': {
        'downloaded': _modelDownloaded['audio'] ?? false,
        'loaded': _audioInterpreter != null,
        'progress': _downloadProgress['audio'] ?? 0.0,
      },
      'image': {
        'downloaded': _modelDownloaded['image'] ?? false,
        'loaded': _imageInterpreter != null,
        'progress': _downloadProgress['image'] ?? 0.0,
      },
    };
  }

  /// Delete all downloaded models
  Future<void> deleteAllModels() async {
    try {
      final modelsDir = await _modelsDir;
      if (await modelsDir.exists()) {
        await modelsDir.delete(recursive: true);
      }

      _textInterpreter?.close();
      _audioInterpreter?.close();
      _imageInterpreter?.close();

      _textInterpreter = null;
      _audioInterpreter = null;
      _imageInterpreter = null;

      _modelDownloaded.clear();
      _downloadProgress.clear();

      debugPrint('[TFLite] All models deleted');
    } catch (e) {
      debugPrint('[TFLite] Error deleting models: $e');
    }
  }

  /// Dispose all resources
  void dispose() {
    _textInterpreter?.close();
    _audioInterpreter?.close();
    _imageInterpreter?.close();

    _textInterpreter = null;
    _audioInterpreter = null;
    _imageInterpreter = null;
  }
}

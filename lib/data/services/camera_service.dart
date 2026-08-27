import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';

enum CameraPermissionStatus { unknown, granted, denied, permanentlyDenied }

enum CameraFailureReason {
  permissionDenied,
  unavailable,
  initializationFailed,
  streamFailed,
}

class CameraServiceException implements Exception {
  const CameraServiceException(this.reason, this.message);

  final CameraFailureReason reason;
  final String message;

  @override
  String toString() => message;
}

class CameraPlaneData {
  const CameraPlaneData({
    required this.bytes,
    required this.bytesPerRow,
    this.bytesPerPixel,
    this.width,
    this.height,
  });

  final Uint8List bytes;
  final int bytesPerRow;
  final int? bytesPerPixel;
  final int? width;
  final int? height;
}

class CameraFrame {
  const CameraFrame({
    required this.width,
    required this.height,
    required this.format,
    required this.planes,
    required this.capturedAt,
  });

  final int width;
  final int height;
  final String format;
  final List<CameraPlaneData> planes;
  final DateTime capturedAt;
}

typedef CameraFrameCallback = FutureOr<void> Function(CameraFrame frame);

abstract interface class CameraService {
  CameraController? get controller;

  bool get isInitialized;

  Future<CameraPermissionStatus> checkPermission();

  Future<CameraPermissionStatus> requestPermission();

  Future<bool> openAppSettings();

  Future<void> initialize();

  Future<void> startFrameStream(
    CameraFrameCallback onFrame, {
    Duration sampleInterval = const Duration(milliseconds: 333),
  });

  Future<void> stopFrameStream();

  Future<void> pause();

  Future<void> resume();

  Future<void> dispose();
}

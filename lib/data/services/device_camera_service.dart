import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;

import 'camera_service.dart';

class DeviceCameraService implements CameraService {
  CameraController? _controller;
  Future<void>? _initialization;
  Future<void>? _streamStart;
  bool _streamRequested = false;
  bool _callbackBusy = false;
  bool _disposed = false;

  @override
  CameraController? get controller => _controller;

  @override
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  @override
  Future<CameraPermissionStatus> checkPermission() async {
    return _mapPermission(await permissions.Permission.camera.status);
  }

  @override
  Future<CameraPermissionStatus> requestPermission() async {
    return _mapPermission(await permissions.Permission.camera.request());
  }

  @override
  Future<bool> openAppSettings() => permissions.openAppSettings();

  @override
  Future<void> initialize() {
    if (_disposed) {
      throw const CameraServiceException(
        CameraFailureReason.initializationFailed,
        'Camera service has been disposed.',
      );
    }
    if (isInitialized) return Future<void>.value();
    return _initialization ??= _initialize().whenComplete(() {
      _initialization = null;
    });
  }

  Future<void> _initialize() async {
    final permission = await checkPermission();
    if (permission != CameraPermissionStatus.granted) {
      throw const CameraServiceException(
        CameraFailureReason.permissionDenied,
        'Camera permission is required to show the road preview.',
      );
    }

    try {
      await _disposeController();
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw const CameraServiceException(
          CameraFailureReason.unavailable,
          'No camera is available on this device.',
        );
      }
      final rear = cameras.where(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      );
      final selected = rear.isNotEmpty ? rear.first : cameras.first;
      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      _controller = controller;
      await controller.initialize();
      if (_disposed) await _disposeController();
    } on CameraServiceException {
      rethrow;
    } on CameraException catch (error) {
      await _disposeController();
      final denied =
          error.code.contains('AccessDenied') ||
          error.code.contains('Restricted');
      throw CameraServiceException(
        denied
            ? CameraFailureReason.permissionDenied
            : CameraFailureReason.initializationFailed,
        error.description ?? 'The rear camera could not be initialized.',
      );
    } on Object catch (error) {
      await _disposeController();
      throw CameraServiceException(
        CameraFailureReason.initializationFailed,
        'The rear camera could not be initialized: $error',
      );
    }
  }

  @override
  Future<void> startFrameStream(
    CameraFrameCallback onFrame, {
    Duration sampleInterval = const Duration(milliseconds: 333),
  }) async {
    _streamRequested = true;
    await initialize();
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw const CameraServiceException(
        CameraFailureReason.unavailable,
        'Camera is not ready.',
      );
    }
    if (controller.value.isStreamingImages) return;

    DateTime? lastSampleAt;
    try {
      final start = controller.startImageStream((image) {
        if (!_streamRequested || _callbackBusy) return;
        final now = DateTime.now();
        if (lastSampleAt != null &&
            now.difference(lastSampleAt!) < sampleInterval) {
          return;
        }
        lastSampleAt = now;
        _callbackBusy = true;
        final frame = CameraFrame(
          width: image.width,
          height: image.height,
          format: image.format.group.name,
          capturedAt: now,
          planes: List<CameraPlaneData>.unmodifiable(
            image.planes.map(
              (plane) => CameraPlaneData(
                bytes: Uint8List.fromList(plane.bytes),
                bytesPerRow: plane.bytesPerRow,
                bytesPerPixel: plane.bytesPerPixel,
                width: plane.width,
                height: plane.height,
              ),
            ),
          ),
        );
        Future<void>.sync(() => onFrame(frame)).whenComplete(() {
          _callbackBusy = false;
        });
      });
      _streamStart = start;
      await start;
      if (!_streamRequested) await stopFrameStream();
    } on CameraException catch (error) {
      _streamRequested = false;
      throw CameraServiceException(
        CameraFailureReason.streamFailed,
        error.description ?? 'Camera frames could not be started.',
      );
    } finally {
      _streamStart = null;
    }
  }

  @override
  Future<void> stopFrameStream() async {
    _streamRequested = false;
    final pendingStart = _streamStart;
    if (pendingStart != null) {
      try {
        await pendingStart;
      } on Object {
        return;
      }
    }
    final controller = _controller;
    if (controller?.value.isStreamingImages ?? false) {
      try {
        await controller!.stopImageStream();
      } on CameraException {
        // The platform may already have stopped the stream during lifecycle loss.
      }
    }
  }

  @override
  Future<void> pause() async {
    await stopFrameStream();
    await _disposeController();
  }

  @override
  Future<void> resume() => initialize();

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    if (controller != null) await controller.dispose();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stopFrameStream();
    await _disposeController();
  }

  static CameraPermissionStatus _mapPermission(
    permissions.PermissionStatus status,
  ) {
    if (status.isGranted || status.isLimited) {
      return CameraPermissionStatus.granted;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return CameraPermissionStatus.permanentlyDenied;
    }
    return CameraPermissionStatus.denied;
  }
}

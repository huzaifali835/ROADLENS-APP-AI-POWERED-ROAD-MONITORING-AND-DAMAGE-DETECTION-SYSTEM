import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:streetlens/data/models/geo_location.dart';
import 'package:streetlens/data/services/camera_service.dart';
import 'package:streetlens/data/services/inference_service.dart';
import 'package:streetlens/data/services/location_service.dart';

class TestCameraService implements CameraService {
  TestCameraService({
    this.permission = CameraPermissionStatus.granted,
    CameraPermissionStatus? requestResult,
    this.initializeError,
  }) : requestResult = requestResult ?? permission;

  CameraPermissionStatus permission;
  CameraPermissionStatus requestResult;
  Object? initializeError;
  bool initialized = false;
  bool streaming = false;
  bool disposed = false;
  int startCount = 0;
  int stopCount = 0;
  CameraFrameCallback? _callback;

  @override
  CameraController? get controller => null;

  @override
  bool get isInitialized => initialized;

  @override
  Future<CameraPermissionStatus> checkPermission() async => permission;

  @override
  Future<CameraPermissionStatus> requestPermission() async {
    permission = requestResult;
    return requestResult;
  }

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<void> initialize() async {
    if (initializeError case final error?) throw error;
    initialized = true;
  }

  @override
  Future<void> startFrameStream(
    CameraFrameCallback onFrame, {
    Duration sampleInterval = const Duration(milliseconds: 333),
  }) async {
    if (!initialized) await initialize();
    startCount++;
    streaming = true;
    _callback = onFrame;
  }

  Future<void> emitFrame() async {
    final callback = _callback;
    if (!streaming || callback == null) return;
    await callback(testCameraFrame());
  }

  @override
  Future<void> stopFrameStream() async {
    stopCount++;
    streaming = false;
    _callback = null;
  }

  @override
  Future<void> pause() async {
    await stopFrameStream();
    initialized = false;
  }

  @override
  Future<void> resume() => initialize();

  @override
  Future<void> dispose() async {
    disposed = true;
    await pause();
  }
}

class TestLocationService implements LocationService {
  TestLocationService({
    this.enabled = true,
    this.permission = LocationPermissionStatus.granted,
    LocationPermissionStatus? requestResult,
    GeoLocation? current,
    this.getCurrentHandler,
  }) : requestResult = requestResult ?? permission,
       current = current ?? testLocation();

  bool enabled;
  LocationPermissionStatus permission;
  LocationPermissionStatus requestResult;
  GeoLocation current;
  Future<GeoLocation> Function()? getCurrentHandler;
  final StreamController<GeoLocation> updates =
      StreamController<GeoLocation>.broadcast();
  bool appSettingsOpened = false;
  bool locationSettingsOpened = false;

  @override
  Future<bool> isServiceEnabled() async => enabled;

  @override
  Future<LocationPermissionStatus> checkPermission() async => permission;

  @override
  Future<LocationPermissionStatus> requestPermission() async {
    permission = requestResult;
    return requestResult;
  }

  @override
  Future<GeoLocation> getCurrentLocation() {
    return getCurrentHandler?.call() ?? Future<GeoLocation>.value(current);
  }

  @override
  Stream<GeoLocation> watchLocation() => updates.stream;

  @override
  Future<bool> openAppSettings() async {
    appSettingsOpened = true;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    locationSettingsOpened = true;
    return true;
  }

  Future<void> close() => updates.close();
}

class TestInferenceService implements InferenceService {
  int processedFrames = 0;
  Object? error;

  @override
  Future<void> processFrame(CameraFrame frame) async {
    if (error case final value?) throw value;
    processedFrames++;
  }
}

GeoLocation testLocation({
  double latitude = 31.52037,
  double longitude = 74.35875,
  double accuracyMeters = 4.2,
}) {
  return GeoLocation(
    latitude: latitude,
    longitude: longitude,
    accuracyMeters: accuracyMeters,
    address: 'Current phone location',
    timestamp: DateTime(2026, 8, 27, 12),
  );
}

CameraFrame testCameraFrame() {
  return CameraFrame(
    width: 2,
    height: 2,
    format: 'yuv420',
    planes: [CameraPlaneData(bytes: Uint8List(4), bytesPerRow: 2)],
    capturedAt: DateTime(2026, 8, 27, 12),
  );
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repositories/detection_repository.dart';
import 'repositories/mock_detection_repository.dart';
import 'services/auth_service.dart';
import 'services/camera_service.dart';
import 'services/device_camera_service.dart';
import 'services/device_location_service.dart';
import 'services/inference_service.dart';
import 'services/location_service.dart';
import 'services/mock_services.dart';
import 'services/sync_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => MockAuthService());

final cameraServiceProvider = Provider.autoDispose<CameraService>((ref) {
  final service = DeviceCameraService();
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

final locationServiceProvider = Provider.autoDispose<LocationService>(
  (ref) => DeviceLocationService(),
);

final inferenceServiceProvider = Provider<InferenceService>(
  (ref) => const NoOpInferenceService(),
);

final detectionRepositoryProvider = Provider<DetectionRepository>(
  (ref) => MockDetectionRepository(),
);

final syncServiceProvider = Provider<SyncService>((ref) => MockSyncService());

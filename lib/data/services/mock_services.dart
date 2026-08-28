import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';

import '../models/app_user.dart';
import '../models/geo_location.dart';
import '../seed/seed_data.dart';
import 'auth_service.dart';
import 'camera_service.dart';
import 'inference_service.dart';
import 'location_service.dart';
import 'sync_service.dart';

class MockAuthService implements AuthService {
  AppUser? _currentUser;
  final StreamController<AppUser?> _changes = StreamController.broadcast();

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Stream<AppUser?> userChanges() async* {
    yield _currentUser;
    yield* _changes.stream;
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    if (!email.contains('@') || password.length < 6) {
      throw const FormatException('Enter a valid email and password.');
    }
    _currentUser = AppUser(
      id: SeedData.inspector.id,
      name: SeedData.inspector.name,
      email: email,
      role: SeedData.inspector.role,
      organization: SeedData.inspector.organization,
      providerIds: const ['password'],
      emailVerified: true,
    );
    _changes.add(_currentUser);
    return _currentUser!;
  }

  @override
  Future<AppUser> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    await signIn(email: email, password: password);
    _currentUser = _currentUser!.copyWith(name: fullName);
    _changes.add(_currentUser);
    return _currentUser!;
  }

  @override
  Future<AppUser?> signInWithGoogle() async {
    _currentUser = SeedData.inspector.copyWith(
      providerIds: const ['google.com'],
    );
    _changes.add(_currentUser);
    return _currentUser!;
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    if (!email.contains('@')) {
      throw const FormatException('Enter a valid email address.');
    }
  }

  @override
  Future<AppUser> retryProfileInitialization() async => _currentUser!;

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _changes.add(null);
  }

  Future<void> dispose() => _changes.close();
}

class MockCameraService implements CameraService {
  bool _initialized = false;

  @override
  CameraController? get controller => null;

  @override
  bool get isInitialized => _initialized;

  @override
  Future<CameraPermissionStatus> checkPermission() async =>
      CameraPermissionStatus.granted;

  @override
  Future<CameraPermissionStatus> requestPermission() async =>
      CameraPermissionStatus.granted;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<void> initialize() async => _initialized = true;

  @override
  Future<void> startFrameStream(
    CameraFrameCallback onFrame, {
    Duration sampleInterval = const Duration(milliseconds: 333),
  }) async {
    if (!_initialized) await initialize();
    await onFrame(
      CameraFrame(
        width: 2,
        height: 2,
        format: 'mock',
        planes: [CameraPlaneData(bytes: Uint8List(4), bytesPerRow: 2)],
        capturedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> stopFrameStream() async {}

  @override
  Future<void> pause() async {
    _initialized = false;
  }

  @override
  Future<void> resume() => initialize();

  @override
  Future<void> dispose() => pause();
}

class MockLocationService implements LocationService {
  @override
  Future<bool> isServiceEnabled() async => true;

  @override
  Future<LocationPermissionStatus> checkPermission() async =>
      LocationPermissionStatus.granted;

  @override
  Future<LocationPermissionStatus> requestPermission() async =>
      LocationPermissionStatus.granted;

  @override
  Future<GeoLocation> getCurrentLocation() async {
    return GeoLocation(
      latitude: 31.52037,
      longitude: 74.35875,
      accuracyMeters: 3.2,
      address: 'Current phone location',
      timestamp: DateTime.now(),
    );
  }

  @override
  Stream<GeoLocation> watchLocation() async* {
    yield await getCurrentLocation();
  }

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

class MockInferenceService implements InferenceService {
  @override
  Future<void> processFrame(CameraFrame frame) async {}
}

class MockSyncService implements SyncService {
  DateTime? _lastSyncAt = DateTime(2026, 8, 27, 9, 45);

  @override
  DateTime? get lastSyncAt => _lastSyncAt;

  @override
  Future<int> syncPendingDetections() async {
    _lastSyncAt = DateTime.now();
    return 2;
  }
}

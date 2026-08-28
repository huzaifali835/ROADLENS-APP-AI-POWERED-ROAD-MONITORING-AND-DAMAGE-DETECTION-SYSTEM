import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repositories/demo_detection_seeder.dart';
import 'repositories/demo_road_responsibility_repository.dart';
import 'repositories/detection_repository.dart';
import 'repositories/complaint_repository.dart';
import 'repositories/firestore_complaint_repository.dart';
import 'repositories/firestore_detection_repository.dart';
import 'repositories/firestore_user_profile_repository.dart';
import 'repositories/road_responsibility_repository.dart';
import 'repositories/user_profile_repository.dart';
import 'services/auth_service.dart';
import 'services/camera_service.dart';
import 'services/device_camera_service.dart';
import 'services/device_location_service.dart';
import 'services/firebase_auth_service.dart';
import 'services/inference_service.dart';
import 'services/location_service.dart';
import 'services/mock_services.dart';
import 'services/sync_service.dart';

final firebaseAuthProvider = Provider<firebase_auth.FirebaseAuth>(
  (ref) => firebase_auth.FirebaseAuth.instance,
);

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final authServiceProvider = Provider<AuthService>(
  (ref) => FirebaseAuthService(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
  ),
);

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

final detectionRepositoryProvider = Provider<DetectionRepository>((ref) {
  return FirestoreDetectionRepository(ref.watch(firestoreProvider));
});

final demoDetectionSeederProvider = Provider<DemoDetectionSeeder>((ref) {
  final repository = ref.watch(detectionRepositoryProvider);
  if (repository is FirestoreDetectionRepository) {
    return FirestoreDemoDetectionSeeder(
      ref.watch(firestoreProvider),
      repository,
    );
  }
  return const NoOpDemoDetectionSeeder();
});

final roadResponsibilityRepositoryProvider =
    Provider<RoadResponsibilityRepository>(
      (ref) => const DemoRoadResponsibilityRepository(),
    );

final complaintRepositoryProvider = Provider<ComplaintRepository>(
  (ref) => FirestoreComplaintRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
  ),
);

final userProfileRepositoryProvider = Provider<UserProfileRepository>(
  (ref) => FirestoreUserProfileRepository(ref.watch(firestoreProvider)),
);

final syncServiceProvider = Provider<SyncService>((ref) => MockSyncService());

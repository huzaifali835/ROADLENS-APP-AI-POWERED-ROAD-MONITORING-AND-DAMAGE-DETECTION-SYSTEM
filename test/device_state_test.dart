import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:streetlens/data/models/detection.dart';
import 'package:streetlens/data/models/geo_location.dart';
import 'package:streetlens/data/repositories/mock_detection_repository.dart';
import 'package:streetlens/data/services/camera_service.dart';
import 'package:streetlens/data/services/location_service.dart';
import 'package:streetlens/features/map/presentation/map_controller.dart';
import 'package:streetlens/features/monitor/presentation/monitor_controller.dart';

import 'helpers/mock_device_services.dart';

void main() {
  group('Monitor device states', () {
    test('camera permission is requested once and can become ready', () async {
      final camera = TestCameraService(
        permission: CameraPermissionStatus.denied,
        requestResult: CameraPermissionStatus.granted,
      );
      final location = TestLocationService(
        permission: LocationPermissionStatus.denied,
      );
      final controller = MonitorController(
        cameraService: camera,
        locationService: location,
        inferenceService: TestInferenceService(),
      );
      addTearDown(() async {
        controller.dispose();
        await location.close();
      });

      await _settleAsync();
      expect(
        controller.state.cameraStatus,
        CameraInitializationStatus.permissionRequired,
      );
      expect(camera.initialized, isFalse);

      await controller.requestCameraPermission();
      expect(controller.state.cameraStatus, CameraInitializationStatus.ready);
      expect(camera.initialized, isTrue);
    });

    test('permanently denied camera directs user to settings', () async {
      final camera = TestCameraService(
        permission: CameraPermissionStatus.permanentlyDenied,
      );
      final location = TestLocationService(
        permission: LocationPermissionStatus.denied,
      );
      final controller = MonitorController(
        cameraService: camera,
        locationService: location,
        inferenceService: TestInferenceService(),
      );
      addTearDown(() async {
        controller.dispose();
        await location.close();
      });

      await _settleAsync();
      expect(
        controller.state.cameraStatus,
        CameraInitializationStatus.permanentlyDenied,
      );
      await controller.openCameraSettings();
    });

    test(
      'camera initialization exposes unavailable error and retry state',
      () async {
        final camera = TestCameraService(
          initializeError: const CameraServiceException(
            CameraFailureReason.unavailable,
            'No rear camera found.',
          ),
        );
        final location = TestLocationService(
          permission: LocationPermissionStatus.denied,
        );
        final controller = MonitorController(
          cameraService: camera,
          locationService: location,
          inferenceService: TestInferenceService(),
        );
        addTearDown(() async {
          controller.dispose();
          await location.close();
        });

        await _settleAsync();
        expect(
          controller.state.cameraStatus,
          CameraInitializationStatus.unavailable,
        );
        expect(controller.state.cameraMessage, contains('No rear camera'));
      },
    );

    test('location moves through loading and success states', () async {
      final completer = Completer<GeoLocation>();
      final camera = TestCameraService(
        permission: CameraPermissionStatus.denied,
      );
      final location = TestLocationService(
        getCurrentHandler: () async => await completer.future,
      );
      final controller = MonitorController(
        cameraService: camera,
        locationService: location,
        inferenceService: TestInferenceService(),
      );
      addTearDown(() async {
        controller.dispose();
        await location.close();
      });

      await _settleAsync();
      expect(controller.state.locationStatus, MonitorLocationStatus.loading);

      completer.complete(testLocation(accuracyMeters: 2.8));
      await _settleAsync();
      expect(controller.state.locationStatus, MonitorLocationStatus.ready);
      expect(controller.state.location?.accuracyMeters, 2.8);
    });

    test('location error is represented without a platform channel', () async {
      final camera = TestCameraService(
        permission: CameraPermissionStatus.denied,
      );
      final location = TestLocationService(
        getCurrentHandler: () async => throw const LocationServiceException(
          LocationFailureReason.unavailable,
          'GPS fix timed out.',
        ),
      );
      final controller = MonitorController(
        cameraService: camera,
        locationService: location,
        inferenceService: TestInferenceService(),
      );
      addTearDown(() async {
        controller.dispose();
        await location.close();
      });

      await _settleAsync();
      expect(controller.state.locationStatus, MonitorLocationStatus.error);
      expect(controller.state.locationMessage, contains('timed out'));
    });
  });

  test('map severity filtering keeps the seeded repository records', () async {
    final location = TestLocationService(
      permission: LocationPermissionStatus.denied,
    );
    final controller = MapViewModel(MockDetectionRepository(), location);
    addTearDown(() async {
      controller.dispose();
      await location.close();
    });

    await _settleAsync();
    expect(controller.state.records, hasLength(6));

    controller.setFilter(DetectionSeverity.high);
    expect(controller.state.filteredRecords, hasLength(2));
    expect(
      controller.state.filteredRecords.every(
        (record) => record.severity == DetectionSeverity.high,
      ),
      isTrue,
    );

    controller.setFilter(DetectionSeverity.low);
    expect(controller.state.filteredRecords, hasLength(1));
    expect(controller.state.selectedDetection?.severity, DetectionSeverity.low);
  });
}

Future<void> _settleAsync() async {
  for (var index = 0; index < 5; index++) {
    await Future<void>.delayed(Duration.zero);
  }
}

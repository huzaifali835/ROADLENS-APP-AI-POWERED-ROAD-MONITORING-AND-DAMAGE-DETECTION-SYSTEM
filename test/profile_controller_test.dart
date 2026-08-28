import 'package:flutter_test/flutter_test.dart';
import 'package:streetlens/data/models/app_user.dart';
import 'package:streetlens/data/repositories/firestore_user_profile_repository.dart';
import 'package:streetlens/data/repositories/mock_detection_repository.dart';
import 'package:streetlens/data/seed/seed_data.dart';
import 'package:streetlens/data/services/location_service.dart';
import 'package:streetlens/data/services/mock_services.dart';
import 'package:streetlens/features/profile/presentation/profile_controller.dart';
import 'package:streetlens/features/profile/presentation/profile_screen.dart';

import 'helpers/mock_device_services.dart';

void main() {
  test(
    'Profile statistics and GPS come from shared repositories/services',
    () async {
      final detections = MockDetectionRepository();
      final location = TestLocationService(
        current: testLocation(
          latitude: 24.8607,
          longitude: 67.0011,
          accuracyMeters: 3.4,
        ),
      );
      final controller = ProfileController(
        detections,
        MemoryUserProfileRepository(),
        location,
        MockSyncService(),
        (_) {},
        user: SeedData.inspector,
      );
      addTearDown(() async {
        controller.dispose();
        await detections.dispose();
        await location.close();
      });
      await _settleAsync();

      expect(controller.state.statsStatus, ProfileStatsStatus.ready);
      expect(controller.state.statistics.total, 6);
      expect(controller.state.statistics.thisWeek, 6);
      expect(
        controller.state.statistics.averageConfidence,
        closeTo(0.8916, 0.001),
      );
      expect(controller.state.statistics.critical, 1);
      expect(controller.state.locationStatus, ProfileLocationStatus.ready);
      expect(controller.state.location?.latitude, 24.8607);
      expect(controller.state.location?.accuracyMeters, 3.4);
    },
  );

  test(
    'Profile exposes denied and permanently-denied location states',
    () async {
      final detections = MockDetectionRepository();
      final location = TestLocationService(
        permission: LocationPermissionStatus.denied,
        requestResult: LocationPermissionStatus.permanentlyDenied,
      );
      final controller = ProfileController(
        detections,
        MemoryUserProfileRepository(),
        location,
        MockSyncService(),
        (_) {},
        user: SeedData.inspector,
      );
      addTearDown(() async {
        controller.dispose();
        await detections.dispose();
        await location.close();
      });
      await _settleAsync();

      expect(
        controller.state.locationStatus,
        ProfileLocationStatus.permissionRequired,
      );
      await controller.requestLocationPermission();
      expect(
        controller.state.locationStatus,
        ProfileLocationStatus.permanentlyDenied,
      );
      await controller.openLocationSettings();
      expect(location.appSettingsOpened, isTrue);
    },
  );

  test(
    'Profile settings persist and update the app-facing preference',
    () async {
      final profileRepository = MemoryUserProfileRepository();
      final detections = MockDetectionRepository();
      final location = TestLocationService(
        permission: LocationPermissionStatus.denied,
      );
      var appDarkMode = false;
      final controller = ProfileController(
        detections,
        profileRepository,
        location,
        MockSyncService(),
        (preferences) => appDarkMode = preferences.darkModeEnabled,
        user: SeedData.inspector,
      );
      addTearDown(() async {
        controller.dispose();
        await detections.dispose();
        await location.close();
      });

      controller.setDarkMode(true);
      await _settleAsync();
      expect(controller.state.preferences.darkModeEnabled, isTrue);
      expect(profileRepository.lastPreferences?.darkModeEnabled, isTrue);
      expect(appDarkMode, isTrue);
    },
  );

  test('initials use the name and fall back safely to email', () {
    expect(profileInitials(SeedData.inspector), 'TI');
    expect(
      profileInitials(
        const AppUser(id: 'email-only', name: '', email: 'zara@example.com'),
      ),
      'Z',
    );
  });
}

Future<void> _settleAsync() async {
  for (var index = 0; index < 8; index++) {
    await Future<void>.delayed(Duration.zero);
  }
}

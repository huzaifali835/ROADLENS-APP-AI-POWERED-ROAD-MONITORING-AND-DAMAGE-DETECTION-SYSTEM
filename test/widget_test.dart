import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streetlens/app/street_lens_app.dart';
import 'package:streetlens/data/providers.dart';
import 'package:streetlens/data/repositories/firestore_complaint_repository.dart';
import 'package:streetlens/data/repositories/firestore_user_profile_repository.dart';
import 'package:streetlens/data/repositories/mock_detection_repository.dart';
import 'package:streetlens/data/services/mock_services.dart';
import 'package:streetlens/features/auth/presentation/auth_scaffold.dart';

import 'helpers/mock_device_services.dart';

void main() {
  testWidgets('auth scaffold tolerates transient zero-height constraints', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          height: 0,
          child: AuthScaffold(
            title: 'RoadLens',
            subtitle: 'Responsive authentication',
            child: Text('Form'),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('restored auth routing and fixed navigation reach every screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final camera = TestCameraService();
    final location = TestLocationService();
    final inference = TestInferenceService();
    final auth = MockAuthService();
    final detections = MockDetectionRepository();
    addTearDown(location.close);
    addTearDown(auth.dispose);
    addTearDown(detections.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          cameraServiceProvider.overrideWithValue(camera),
          locationServiceProvider.overrideWithValue(location),
          inferenceServiceProvider.overrideWithValue(inference),
          detectionRepositoryProvider.overrideWithValue(detections),
          complaintRepositoryProvider.overrideWithValue(
            MemoryComplaintRepository(),
          ),
          userProfileRepositoryProvider.overrideWithValue(
            MemoryUserProfileRepository(),
          ),
        ],
        child: const StreetLensApp(),
      ),
    );
    await tester.pumpAndSettle();
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.title, 'RoadLens');
    expect(find.text('RoadLens'), findsOneWidget);
    expect(find.textContaining('StreetLens'), findsNothing);
    expect(find.text('Welcome back'), findsOneWidget);

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Reset password'), findsOneWidget);
    await tester.tap(find.text('Back to Login'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('register-name-field')),
      'Test Inspector',
    );
    await tester.enterText(
      find.byKey(const Key('register-email-field')),
      'inspector@example.com',
    );
    final passwordFields = find.byType(TextFormField);
    await tester.enterText(passwordFields.at(2), 'securepass');
    await tester.enterText(passwordFields.at(3), 'securepass');
    await tester.tap(find.byKey(const Key('register-button')));
    await tester.pumpAndSettle();
    expect(find.text('Start AI Scan'), findsOneWidget);

    await tester.tap(find.text('Map'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Road Damage Map'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-history')));
    await tester.pumpAndSettle();
    expect(find.text('History'), findsWidgets);
    expect(find.text('6 Firebase demo detections'), findsOneWidget);
    expect(find.byKey(const Key('history-category-filters')), findsOneWidget);
    expect(find.byKey(const Key('history-search-field')), findsNothing);

    await tester.drag(
      find.byKey(const Key('history-category-filters')),
      const Offset(-300, 0),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('history-filter-broken_road')));
    await tester.pump();
    expect(find.text('Broken Road'), findsWidgets);
    expect(
      find.byKey(
        const Key('history-record-test-user-001_demo_pothole_shahrah_e_faisal'),
      ),
      findsNothing,
    );
    final complaintButton = find.byKey(
      const Key('complaint-button-test-user-001_demo_broken_road_korangi'),
    );
    await tester.scrollUntilVisible(
      complaintButton.first,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(complaintButton.first);
    await tester.pumpAndSettle();
    expect(find.text('Submit Road Complaint'), findsOneWidget);
    expect(find.text('Find road contractor'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-profile')));
    await tester.pumpAndSettle();
    expect(find.text('Profile & Settings'), findsOneWidget);
    expect(find.text('Test Inspector'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.byKey(const Key('profile-current-location')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('sign-out-button')),
      500,
    );
    await tester.tap(find.byKey(const Key('sign-out-button')));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });
}

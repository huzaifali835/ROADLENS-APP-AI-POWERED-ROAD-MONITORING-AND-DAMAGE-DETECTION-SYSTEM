import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streetlens/app/street_lens_app.dart';
import 'package:streetlens/data/providers.dart';
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
            title: 'StreetLens',
            subtitle: 'Responsive authentication',
            child: Text('Form'),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('auth routes and bottom navigation reach every Phase 1 screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final camera = TestCameraService();
    final location = TestLocationService();
    final inference = TestInferenceService();
    addTearDown(location.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cameraServiceProvider.overrideWithValue(camera),
          locationServiceProvider.overrideWithValue(location),
          inferenceServiceProvider.overrideWithValue(inference),
        ],
        child: const StreetLensApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Reset password'), findsOneWidget);

    await tester.tap(find.text('Back to Login'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);

    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);

    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);

    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();
    expect(find.text('Start AI Scan'), findsOneWidget);
    expect(find.byKey(const Key('nav-monitor')), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-map')));
    await tester.pumpAndSettle();
    expect(find.text('Road Damage Map'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-history')));
    await tester.pumpAndSettle();
    expect(find.text('Detection History'), findsOneWidget);
    expect(find.byKey(const Key('history-record-SL-2026-001')), findsOneWidget);

    await tester.tap(find.byKey(const Key('history-record-SL-2026-001')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('history-details-SL-2026-001')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('nav-profile')));
    await tester.pumpAndSettle();
    expect(find.text('Profile & Settings'), findsOneWidget);
    expect(find.text('Ayesha Khan'), findsOneWidget);
  });
}

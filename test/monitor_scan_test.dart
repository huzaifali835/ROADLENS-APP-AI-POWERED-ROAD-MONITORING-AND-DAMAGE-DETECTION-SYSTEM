import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streetlens/app/app_theme.dart';
import 'package:streetlens/data/providers.dart';
import 'package:streetlens/data/repositories/mock_detection_repository.dart';
import 'package:streetlens/features/monitor/presentation/monitor_controller.dart';
import 'package:streetlens/features/monitor/presentation/monitor_screen.dart';

import 'helpers/mock_device_services.dart';

void main() {
  testWidgets('start and stop scan streams real frames without detections', (
    tester,
  ) async {
    final camera = TestCameraService();
    final location = TestLocationService();
    final inference = TestInferenceService();
    final repository = MockDetectionRepository();
    addTearDown(location.close);

    await _pumpMonitor(
      tester,
      camera: camera,
      location: location,
      inference: inference,
      repository: repository,
    );

    expect(find.text('Start AI Scan'), findsOneWidget);
    expect(find.text('24'), findsOneWidget);
    expect(camera.initialized, isTrue);

    await tester.tap(find.byKey(const Key('scan-button')));
    await tester.pump();
    expect(find.text('Stop Scanning'), findsOneWidget);
    expect(find.text('SAMPLING CAMERA FRAMES'), findsOneWidget);
    expect(camera.streaming, isTrue);

    await camera.emitFrame();
    await camera.emitFrame();
    await tester.pump();

    expect(find.text('26'), findsOneWidget);
    expect(inference.processedFrames, 2);
    expect(find.byKey(const Key('phase3-model-card')), findsOneWidget);
    expect(find.text('AI model not connected — Phase 3'), findsOneWidget);
    expect((await repository.getAll()).length, 6);

    await tester.tap(find.byKey(const Key('scan-button')));
    await tester.pump();
    expect(find.text('Start AI Scan'), findsOneWidget);
    expect(camera.streaming, isFalse);
  });

  testWidgets('rapid stop cancels future camera samples safely', (
    tester,
  ) async {
    final camera = TestCameraService();
    final location = TestLocationService();
    final inference = TestInferenceService();
    addTearDown(location.close);

    await _pumpMonitor(
      tester,
      camera: camera,
      location: location,
      inference: inference,
      repository: MockDetectionRepository(),
    );

    await tester.tap(find.byKey(const Key('scan-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('scan-button')));
    await tester.pump();
    await camera.emitFrame();
    await tester.pump();

    expect(find.text('Start AI Scan'), findsOneWidget);
    expect(find.text('24'), findsOneWidget);
    expect(inference.processedFrames, 0);
    expect(camera.streaming, isFalse);
  });

  testWidgets(
    'general demo stops scan and releases camera before restoring Live',
    (tester) async {
      final camera = TestCameraService();
      final location = TestLocationService();
      final inference = TestInferenceService();
      addTearDown(location.close);
      late ProviderContainer container;
      var launchCount = 0;

      await _pumpMonitor(
        tester,
        camera: camera,
        location: location,
        inference: inference,
        repository: MockDetectionRepository(),
        generalObjectDemoLauncher: (context) async {
          launchCount++;
          expect(camera.streaming, isFalse);
          expect(camera.initialized, isFalse);
          expect(camera.events.last, 'pause:complete');
          expect(
            container.read(monitorControllerProvider).status,
            MonitorScanStatus.idle,
          );
        },
      );
      container = ProviderScope.containerOf(
        tester.element(find.byType(MonitorScreen)),
      );

      await tester.tap(find.byKey(const Key('scan-button')));
      await tester.pump();
      expect(camera.streaming, isTrue);
      camera.events.clear();
      final initializationsBeforeDemo = camera.initializeCount;

      final demoButton = find.byKey(const Key('general-object-demo-button'));
      await tester.ensureVisible(demoButton);
      await tester.tap(demoButton);
      await _pumpUntil(
        tester,
        () => launchCount == 1 && _demoButtonIsEnabled(tester),
      );

      expect(launchCount, 1);
      expect(
        camera.events,
        containsAllInOrder([
          'stopFrameStream',
          'pause:start',
          'pause:complete',
          'initialize',
        ]),
      );
      expect(camera.initializeCount, greaterThan(initializationsBeforeDemo));
      expect(camera.initialized, isTrue);
      expect(camera.streaming, isFalse);
      expect(
        container.read(monitorControllerProvider).status,
        MonitorScanStatus.idle,
      );
      expect(find.text('Start AI Scan'), findsOneWidget);
    },
  );

  testWidgets('general demo guard rejects duplicate taps', (tester) async {
    final camera = TestCameraService();
    final location = TestLocationService();
    final routeCompleter = Completer<void>();
    var launchCount = 0;
    addTearDown(location.close);

    await _pumpMonitor(
      tester,
      camera: camera,
      location: location,
      inference: TestInferenceService(),
      repository: MockDetectionRepository(),
      generalObjectDemoLauncher: (context) {
        launchCount++;
        return routeCompleter.future;
      },
    );

    final demoButton = find.byKey(const Key('general-object-demo-button'));
    await tester.ensureVisible(demoButton);
    await tester.tap(demoButton);
    await tester.tap(demoButton);
    await tester.pump();
    await tester.pump();

    expect(launchCount, 1);
    final button = tester.widget<OutlinedButton>(demoButton);
    expect(button.onPressed, isNull);

    routeCompleter.complete();
    await _pumpUntil(tester, () => _demoButtonIsEnabled(tester));
    expect(camera.initialized, isTrue);
  });

  testWidgets('Monitor camera restores after demo route failure', (
    tester,
  ) async {
    final camera = TestCameraService();
    final location = TestLocationService();
    addTearDown(location.close);

    await _pumpMonitor(
      tester,
      camera: camera,
      location: location,
      inference: TestInferenceService(),
      repository: MockDetectionRepository(),
      generalObjectDemoLauncher: (context) async {
        throw StateError('test route failure');
      },
    );

    final demoButton = find.byKey(const Key('general-object-demo-button'));
    await tester.ensureVisible(demoButton);
    await tester.tap(demoButton);
    await _pumpUntil(tester, () => _demoButtonIsEnabled(tester));

    expect(camera.initialized, isTrue);
    expect(camera.streaming, isFalse);
    expect(find.byKey(const Key('general-object-demo-error')), findsOneWidget);
    expect(find.text('Start AI Scan'), findsOneWidget);
  });
}

Future<void> _pumpMonitor(
  WidgetTester tester, {
  required TestCameraService camera,
  required TestLocationService location,
  required TestInferenceService inference,
  required MockDetectionRepository repository,
  GeneralObjectDemoLauncher? generalObjectDemoLauncher,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cameraServiceProvider.overrideWithValue(camera),
        locationServiceProvider.overrideWithValue(location),
        inferenceServiceProvider.overrideWithValue(inference),
        detectionRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: MonitorScreen(
            generalObjectDemoLauncher: generalObjectDemoLauncher,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (condition()) return;
  }
  expect(
    condition(),
    isTrue,
    reason:
        'The asynchronous camera transition timed out. Visible text: '
        '${tester.widgetList<Text>(find.byType(Text)).map((text) => text.data).whereType<String>().toList()}',
  );
}

bool _demoButtonIsEnabled(WidgetTester tester) {
  final finder = find.byKey(const Key('general-object-demo-button'));
  if (finder.evaluate().isEmpty) return false;
  return tester.widget<OutlinedButton>(finder).onPressed != null;
}

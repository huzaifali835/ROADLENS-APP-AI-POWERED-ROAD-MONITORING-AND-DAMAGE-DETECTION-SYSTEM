import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streetlens/app/app_theme.dart';
import 'package:streetlens/data/providers.dart';
import 'package:streetlens/data/repositories/mock_detection_repository.dart';
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
}

Future<void> _pumpMonitor(
  WidgetTester tester, {
  required TestCameraService camera,
  required TestLocationService location,
  required TestInferenceService inference,
  required MockDetectionRepository repository,
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
        home: const Scaffold(body: MonitorScreen()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

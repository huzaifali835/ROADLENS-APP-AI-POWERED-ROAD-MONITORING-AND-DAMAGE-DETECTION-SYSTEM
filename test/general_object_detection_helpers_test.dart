import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:streetlens/data/repositories/mock_detection_repository.dart';
import 'package:streetlens/features/monitor/presentation/general_object_detection_helpers.dart';

void main() {
  group('temporary object summary helpers', () {
    test('filters relevant classes case-insensitively', () {
      final filtered = filterRelevantObjectClasses([
        ' Person ',
        'CAR',
        'traffic_light',
        'chair',
        'dog',
      ]);

      expect(filtered, ['person', 'car', 'traffic light']);
    });

    test('keeps object count while formatting unique labels', () {
      final filtered = filterRelevantObjectClasses([
        'car',
        'person',
        'car',
        'bus',
      ]);

      expect(filtered, hasLength(4));
      expect(uniqueVisibleObjectClasses(filtered), ['person', 'car', 'bus']);
      expect(formatUniqueVisibleObjectClasses(filtered), 'person, car, bus');
    });

    test('formats an empty relevant-class set safely', () {
      expect(
        formatUniqueVisibleObjectClasses(['cat', 'chair']),
        'None visible',
      );
    });

    test('maps technical failures to human-readable messages', () {
      expect(
        friendlyGeneralDetectionError(
          Exception('Camera permission denied by platform'),
        ),
        'Camera permission is required for temporary object detection.',
      );
      expect(
        friendlyGeneralDetectionError(Exception('network download failed')),
        'The model could not be downloaded. Check the connection and retry.',
      );
    });

    test('temporary YOLO results never call DetectionRepository', () async {
      final repository = MockDetectionRepository();
      addTearDown(repository.dispose);
      final recordsBefore = await repository.getAll();

      final visible = filterRelevantObjectClasses(['person', 'car', 'chair']);

      expect(visible, ['person', 'car']);
      expect(await repository.getAll(), recordsBefore);
    });

    test(
      'exit coordinator releases once and prevents duplicate pops',
      () async {
        final coordinator = GeneralObjectDetectionExitCoordinator();
        final releaseCompleter = Completer<void>();
        var releaseCount = 0;
        var popCount = 0;

        Future<void> releaseCamera() async {
          releaseCount++;
          await releaseCompleter.future;
        }

        Future<void> popRoute() async {
          popCount++;
        }

        final first = coordinator.exit(
          releaseCamera: releaseCamera,
          popRoute: popRoute,
        );
        final second = coordinator.exit(
          releaseCamera: releaseCamera,
          popRoute: popRoute,
        );

        expect(coordinator.isExiting, isTrue);
        expect(releaseCount, 1);
        expect(identical(first, second), isTrue);
        releaseCompleter.complete();
        await Future.wait([first, second]);
        expect(popCount, 1);
      },
    );
  });
}

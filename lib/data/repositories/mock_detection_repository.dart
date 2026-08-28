import 'dart:async';

import '../models/app_user.dart';
import '../models/detection.dart';
import '../seed/seed_data.dart';
import 'detection_repository.dart';

class MockDetectionRepository implements DetectionRepository {
  MockDetectionRepository({List<Detection>? detections})
    : _detections = List.of(detections ?? SeedData.detections);

  final List<Detection> _detections;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Future<List<Detection>> getAll() async => _sorted(_detections);

  @override
  Future<List<Detection>> getForUser(String userId) async =>
      _sorted(_detections.where((item) => item.userId == userId));

  @override
  Stream<List<Detection>> watchForUser(String userId) async* {
    yield await getForUser(userId);
    await for (final _ in _changes.stream) {
      yield await getForUser(userId);
    }
  }

  @override
  Future<Detection?> getById(String id, {required String userId}) async {
    for (final detection in _detections) {
      if (detection.id == id && detection.userId == userId) return detection;
    }
    return null;
  }

  @override
  Future<void> save(Detection detection) async {
    final index = _detections.indexWhere((item) => item.id == detection.id);
    if (index == -1) {
      _detections.add(detection);
    } else if (_detections[index].userId == detection.userId) {
      _detections[index] = detection;
    } else {
      throw StateError('A detection cannot be reassigned to another user.');
    }
    _changes.add(null);
  }

  Future<void> seedFor(AppUser user) async {
    for (final detection in SeedData.detectionsFor(user)) {
      await save(detection);
    }
  }

  List<Detection> _sorted(Iterable<Detection> input) {
    final result = List<Detection>.of(input)
      ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return List.unmodifiable(result);
  }

  Future<void> dispose() => _changes.close();
}

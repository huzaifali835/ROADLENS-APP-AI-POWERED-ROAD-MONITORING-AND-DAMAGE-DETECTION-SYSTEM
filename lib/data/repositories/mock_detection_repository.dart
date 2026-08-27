import '../models/detection.dart';
import '../seed/seed_data.dart';
import 'detection_repository.dart';

class MockDetectionRepository implements DetectionRepository {
  MockDetectionRepository() : _detections = List.of(SeedData.detections);

  final List<Detection> _detections;

  @override
  Future<List<Detection>> getAll() async {
    final result = List<Detection>.of(_detections)
      ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return List.unmodifiable(result);
  }

  @override
  Future<Detection?> getById(String id) async {
    for (final detection in _detections) {
      if (detection.id == id) return detection;
    }
    return null;
  }

  @override
  Future<void> save(Detection detection) async {
    final index = _detections.indexWhere((item) => item.id == detection.id);
    if (index == -1) {
      _detections.add(detection);
    } else {
      _detections[index] = detection;
    }
  }
}

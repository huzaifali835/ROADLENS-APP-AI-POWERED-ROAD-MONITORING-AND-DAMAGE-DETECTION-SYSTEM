import '../models/detection.dart';

abstract interface class DetectionRepository {
  Future<List<Detection>> getAll();

  Future<Detection?> getById(String id);

  Future<void> save(Detection detection);
}

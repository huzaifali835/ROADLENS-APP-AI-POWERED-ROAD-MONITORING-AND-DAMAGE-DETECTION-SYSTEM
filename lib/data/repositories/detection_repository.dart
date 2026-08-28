import '../models/detection.dart';

abstract interface class DetectionRepository {
  Stream<List<Detection>> watchForUser(String userId);

  Future<List<Detection>> getForUser(String userId);

  Future<Detection?> getById(String id, {required String userId});

  Future<void> save(Detection detection);

  /// Test/demo convenience. Production UI always calls a user-scoped method.
  Future<List<Detection>> getAll();
}

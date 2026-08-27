import 'camera_service.dart';

abstract interface class InferenceService {
  Future<void> processFrame(CameraFrame frame);
}

class NoOpInferenceService implements InferenceService {
  const NoOpInferenceService();

  @override
  Future<void> processFrame(CameraFrame frame) async {
    // Phase 3 will adapt the throttled frame to the on-device model input.
  }
}

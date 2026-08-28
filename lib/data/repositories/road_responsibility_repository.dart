import '../models/detection.dart';
import '../models/road_responsibility.dart';

abstract interface class RoadResponsibilityRepository {
  Future<RoadResponsibilityResult> findForDetection(Detection detection);
}

import '../models/app_user.dart';
import '../models/bounding_box.dart';
import '../models/detection.dart';

abstract final class SeedData {
  static const inspector = AppUser(
    id: 'test-user-001',
    name: 'Test Inspector',
    email: 'inspector@example.com',
    role: 'user',
    organization: 'RoadLens Field Team',
    providerIds: ['password'],
    emailVerified: true,
  );

  static List<Detection> detectionsFor(AppUser user) {
    final now = DateTime.now();
    Detection item({
      required String suffix,
      required DamageType damageType,
      required DetectionSeverity severity,
      required double confidence,
      required double latitude,
      required double longitude,
      required String address,
      required String description,
      required Duration age,
      BoundingBox? boundingBox,
    }) {
      return Detection(
        id: '${user.id}_demo_$suffix',
        userId: user.id,
        userDisplayName: user.name,
        userEmail: user.email,
        damageType: damageType,
        severity: severity,
        confidence: confidence,
        latitude: latitude,
        longitude: longitude,
        gpsAccuracy: 4.2,
        address: address,
        description: description,
        localImagePath: null,
        imageUrl: null,
        capturedAt: now.subtract(age),
        synchronizationStatus: SynchronizationStatus.synchronized,
        modelVersion: 'demo-v1',
        source: 'demo',
        isSynthetic: true,
        boundingBox: boundingBox,
      );
    }

    return List.unmodifiable([
      item(
        suffix: 'pothole_shahrah_e_faisal',
        damageType: DamageType.pothole,
        severity: DetectionSeverity.critical,
        confidence: 0.96,
        latitude: 24.8607,
        longitude: 67.0561,
        address: 'Shahrah-e-Faisal, Karachi',
        description: 'Demo record: a deep pothole affecting the vehicle lane.',
        age: const Duration(hours: 2),
        boundingBox: const BoundingBox(
          left: 0.29,
          top: 0.48,
          width: 0.38,
          height: 0.29,
        ),
      ),
      item(
        suffix: 'crack_ii_chundrigar',
        damageType: DamageType.crack,
        severity: DetectionSeverity.high,
        confidence: 0.92,
        latitude: 24.8496,
        longitude: 66.9969,
        address: 'I. I. Chundrigar Road, Karachi',
        description:
            'Demo record: a longitudinal pavement crack in the traffic lane.',
        age: const Duration(hours: 6),
      ),
      item(
        suffix: 'broken_road_korangi',
        damageType: DamageType.brokenRoad,
        severity: DetectionSeverity.moderate,
        confidence: 0.88,
        latitude: 24.8275,
        longitude: 67.1208,
        address: 'Korangi Road, Karachi',
        description: 'Demo record: broken asphalt and loose surface material.',
        age: const Duration(days: 1, hours: 2),
      ),
      item(
        suffix: 'erosion_university',
        damageType: DamageType.surfaceErosion,
        severity: DetectionSeverity.high,
        confidence: 0.90,
        latitude: 24.9262,
        longitude: 67.0882,
        address: 'University Road, Karachi',
        description: 'Demo record: surface erosion along the outer wheel path.',
        age: const Duration(days: 1, hours: 5),
      ),
      item(
        suffix: 'pothole_clifton',
        damageType: DamageType.pothole,
        severity: DetectionSeverity.low,
        confidence: 0.83,
        latitude: 24.8138,
        longitude: 67.0305,
        address: 'Clifton Road, Karachi',
        description: 'Demo record: a shallow pothole near the road edge.',
        age: const Duration(days: 2),
      ),
      item(
        suffix: 'crack_ma_jinnah',
        damageType: DamageType.crack,
        severity: DetectionSeverity.moderate,
        confidence: 0.86,
        latitude: 24.8732,
        longitude: 67.0291,
        address: 'M. A. Jinnah Road, Karachi',
        description: 'Demo record: transverse cracking across one lane.',
        age: const Duration(days: 3),
      ),
    ]);
  }

  static List<Detection> get detections => detectionsFor(inspector);
}

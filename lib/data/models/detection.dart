import 'bounding_box.dart';

enum DamageType { pothole, crack, brokenRoad, surfaceErosion }

extension DamageTypeDetails on DamageType {
  String get id => switch (this) {
    DamageType.pothole => 'pothole',
    DamageType.crack => 'crack',
    DamageType.brokenRoad => 'broken_road',
    DamageType.surfaceErosion => 'surface_erosion',
  };

  String get label => switch (this) {
    DamageType.pothole => 'Pothole',
    DamageType.crack => 'Crack',
    DamageType.brokenRoad => 'Broken Road',
    DamageType.surfaceErosion => 'Surface Erosion',
  };

  static DamageType parse(Object? value) => switch (value?.toString()) {
    'crack' || 'Crack' => DamageType.crack,
    'broken_road' || 'Broken Road' || 'Broken Surface' => DamageType.brokenRoad,
    'surface_erosion' ||
    'Surface Erosion' ||
    'Edge Damage' ||
    'Road Subsidence' => DamageType.surfaceErosion,
    _ => DamageType.pothole,
  };
}

enum DetectionSeverity { critical, high, moderate, low }

extension DetectionSeverityLabel on DetectionSeverity {
  String get label => switch (this) {
    DetectionSeverity.critical => 'Critical',
    DetectionSeverity.high => 'High',
    DetectionSeverity.moderate => 'Moderate',
    DetectionSeverity.low => 'Low',
  };

  String get id => name;

  static DetectionSeverity parse(Object? value) => switch (value?.toString()) {
    'critical' || 'Critical' => DetectionSeverity.critical,
    'high' || 'High' => DetectionSeverity.high,
    'low' || 'Low' => DetectionSeverity.low,
    _ => DetectionSeverity.moderate,
  };
}

enum SynchronizationStatus { pending, synchronized, failed }

extension SynchronizationStatusValue on SynchronizationStatus {
  static SynchronizationStatus parse(Object? value) =>
      SynchronizationStatus.values.firstWhere(
        (item) => item.name == value,
        orElse: () => SynchronizationStatus.pending,
      );
}

class Detection {
  const Detection({
    required this.id,
    required this.userId,
    required this.userDisplayName,
    required this.userEmail,
    required this.damageType,
    required this.severity,
    required this.confidence,
    required this.latitude,
    required this.longitude,
    required this.gpsAccuracy,
    required this.address,
    required this.description,
    required this.localImagePath,
    required this.imageUrl,
    required this.capturedAt,
    required this.synchronizationStatus,
    required this.modelVersion,
    required this.source,
    required this.isSynthetic,
    this.boundingBox,
  });

  final String id;
  final String userId;
  final String userDisplayName;
  final String userEmail;
  final DamageType damageType;
  final DetectionSeverity severity;
  final double confidence;
  final double latitude;
  final double longitude;
  final double gpsAccuracy;
  final String address;
  final String description;
  final String? localImagePath;
  final String? imageUrl;
  final DateTime capturedAt;
  final SynchronizationStatus synchronizationStatus;
  final String modelVersion;
  final String source;
  final bool isSynthetic;
  final BoundingBox? boundingBox;

  String? get remoteImageUrl => imageUrl;

  Detection copyWith({
    String? userDisplayName,
    String? userEmail,
    DamageType? damageType,
    DetectionSeverity? severity,
    double? confidence,
    String? address,
    String? description,
    String? imageUrl,
    SynchronizationStatus? synchronizationStatus,
  }) {
    return Detection(
      id: id,
      userId: userId,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      userEmail: userEmail ?? this.userEmail,
      damageType: damageType ?? this.damageType,
      severity: severity ?? this.severity,
      confidence: confidence ?? this.confidence,
      latitude: latitude,
      longitude: longitude,
      gpsAccuracy: gpsAccuracy,
      address: address ?? this.address,
      description: description ?? this.description,
      localImagePath: localImagePath,
      imageUrl: imageUrl ?? this.imageUrl,
      capturedAt: capturedAt,
      synchronizationStatus:
          synchronizationStatus ?? this.synchronizationStatus,
      modelVersion: modelVersion,
      source: source,
      isSynthetic: isSynthetic,
      boundingBox: boundingBox,
    );
  }
}

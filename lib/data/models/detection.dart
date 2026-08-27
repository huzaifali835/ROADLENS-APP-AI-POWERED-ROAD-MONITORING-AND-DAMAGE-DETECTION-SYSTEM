import 'bounding_box.dart';

enum DetectionSeverity { critical, high, moderate, low }

extension DetectionSeverityLabel on DetectionSeverity {
  String get label => switch (this) {
    DetectionSeverity.critical => 'Critical',
    DetectionSeverity.high => 'High',
    DetectionSeverity.moderate => 'Moderate',
    DetectionSeverity.low => 'Low',
  };
}

enum SynchronizationStatus { pending, synchronized, failed }

class Detection {
  const Detection({
    required this.id,
    required this.userId,
    required this.damageType,
    required this.severity,
    required this.confidence,
    required this.latitude,
    required this.longitude,
    required this.gpsAccuracy,
    required this.address,
    required this.description,
    required this.localImagePath,
    required this.remoteImageUrl,
    required this.capturedAt,
    required this.synchronizationStatus,
    required this.modelVersion,
    this.boundingBox,
  });

  final String id;
  final String userId;
  final String damageType;
  final DetectionSeverity severity;
  final double confidence;
  final double latitude;
  final double longitude;
  final double gpsAccuracy;
  final String address;
  final String description;
  final String? localImagePath;
  final String? remoteImageUrl;
  final DateTime capturedAt;
  final SynchronizationStatus synchronizationStatus;
  final String modelVersion;
  final BoundingBox? boundingBox;

  Detection copyWith({
    String? id,
    String? userId,
    String? damageType,
    DetectionSeverity? severity,
    double? confidence,
    double? latitude,
    double? longitude,
    double? gpsAccuracy,
    String? address,
    String? description,
    String? localImagePath,
    String? remoteImageUrl,
    DateTime? capturedAt,
    SynchronizationStatus? synchronizationStatus,
    String? modelVersion,
    BoundingBox? boundingBox,
  }) {
    return Detection(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      damageType: damageType ?? this.damageType,
      severity: severity ?? this.severity,
      confidence: confidence ?? this.confidence,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      gpsAccuracy: gpsAccuracy ?? this.gpsAccuracy,
      address: address ?? this.address,
      description: description ?? this.description,
      localImagePath: localImagePath ?? this.localImagePath,
      remoteImageUrl: remoteImageUrl ?? this.remoteImageUrl,
      capturedAt: capturedAt ?? this.capturedAt,
      synchronizationStatus:
          synchronizationStatus ?? this.synchronizationStatus,
      modelVersion: modelVersion ?? this.modelVersion,
      boundingBox: boundingBox ?? this.boundingBox,
    );
  }
}

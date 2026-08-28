enum ComplaintStatus { recorded, cancelled }

enum ComplaintDeliveryStatus { deliveryUnavailable, sent }

class Complaint {
  const Complaint({
    required this.id,
    required this.userId,
    required this.userDisplayName,
    required this.userEmail,
    required this.detectionId,
    required this.status,
    required this.deliveryStatus,
    required this.recipientName,
    required this.recipientEmail,
    required this.subject,
    required this.body,
    required this.damageType,
    required this.severity,
    required this.confidence,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.gpsAccuracy,
    required this.source,
    required this.isDemo,
    required this.createdAt,
    required this.updatedAt,
    this.roadResponsibilityId,
    this.supervisingAuthorityName,
    this.recipientPhone,
    this.sourceTitle,
    this.sourceUrl,
    this.sourceSummary,
  });

  final String id;
  final String userId;
  final String userDisplayName;
  final String userEmail;
  final String detectionId;
  final ComplaintStatus status;
  final ComplaintDeliveryStatus deliveryStatus;
  final String recipientName;
  final String? recipientEmail;
  final String subject;
  final String body;
  final String damageType;
  final String severity;
  final double confidence;
  final String address;
  final double latitude;
  final double longitude;
  final double gpsAccuracy;
  final String source;
  final bool isDemo;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? roadResponsibilityId;
  final String? supervisingAuthorityName;
  final String? recipientPhone;
  final String? sourceTitle;
  final String? sourceUrl;
  final String? sourceSummary;

  Complaint copyWith({
    String? id,
    String? userId,
    String? detectionId,
    ComplaintStatus? status,
    ComplaintDeliveryStatus? deliveryStatus,
  }) {
    return Complaint(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userDisplayName: userDisplayName,
      userEmail: userEmail,
      detectionId: detectionId ?? this.detectionId,
      status: status ?? this.status,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      recipientName: recipientName,
      recipientEmail: recipientEmail,
      subject: subject,
      body: body,
      damageType: damageType,
      severity: severity,
      confidence: confidence,
      address: address,
      latitude: latitude,
      longitude: longitude,
      gpsAccuracy: gpsAccuracy,
      source: source,
      isDemo: isDemo,
      createdAt: createdAt,
      updatedAt: updatedAt,
      roadResponsibilityId: roadResponsibilityId,
      supervisingAuthorityName: supervisingAuthorityName,
      recipientPhone: recipientPhone,
      sourceTitle: sourceTitle,
      sourceUrl: sourceUrl,
      sourceSummary: sourceSummary,
    );
  }
}

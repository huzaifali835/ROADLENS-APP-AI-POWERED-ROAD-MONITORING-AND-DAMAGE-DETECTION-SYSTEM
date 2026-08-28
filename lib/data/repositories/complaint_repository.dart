import '../models/complaint.dart';

class ComplaintRepositoryException implements Exception {
  const ComplaintRepositoryException({
    required this.code,
    required this.message,
    this.technicalCode,
  });

  final String code;
  final String message;
  final String? technicalCode;

  @override
  String toString() => message;
}

abstract final class ComplaintWritePolicy {
  static String documentId({
    required String userId,
    required String detectionId,
  }) => 'complaint_${userId}_$detectionId';

  static void validate({
    required Complaint complaint,
    required String? authenticatedUserId,
  }) {
    if (authenticatedUserId == null || authenticatedUserId.isEmpty) {
      throw const ComplaintRepositoryException(
        code: 'unauthenticated',
        message: 'Sign in again before recording this complaint.',
      );
    }
    if (complaint.userId != authenticatedUserId) {
      throw const ComplaintRepositoryException(
        code: 'unauthorized-user',
        message: 'This complaint can only be recorded by its signed-in user.',
      );
    }
    if (complaint.detectionId.isEmpty) {
      throw const ComplaintRepositoryException(
        code: 'missing-detection',
        message: 'The selected detection is unavailable. Refresh History and try again.',
      );
    }
    final expectedId = documentId(
      userId: complaint.userId,
      detectionId: complaint.detectionId,
    );
    if (complaint.id != expectedId) {
      throw const ComplaintRepositoryException(
        code: 'invalid-document-id',
        message: 'The complaint reference is invalid. Refresh History and try again.',
      );
    }
    if (complaint.status != ComplaintStatus.recorded ||
        complaint.deliveryStatus !=
            ComplaintDeliveryStatus.deliveryUnavailable) {
      throw const ComplaintRepositoryException(
        code: 'invalid-phase-two-status',
        message: 'RoadLens can only record complaints locally during Phase 2.',
      );
    }
  }
}

abstract interface class ComplaintRepository {
  Future<Complaint?> getForDetection({
    required String userId,
    required String detectionId,
  });

  Future<Complaint> record(Complaint complaint);
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/complaint.dart';
import 'complaint_repository.dart';

class FirestoreComplaintRepository implements ComplaintRepository {
  FirestoreComplaintRepository(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('complaints');

  @override
  Future<Complaint?> getForDetection({
    required String userId,
    required String detectionId,
  }) async {
    _validateAuthenticatedUser(userId);
    final id = ComplaintWritePolicy.documentId(
      userId: userId,
      detectionId: detectionId,
    );
    try {
      final snapshot = await _collection.doc(id).get();
      if (!snapshot.exists || snapshot.data()?['userId'] != userId) return null;
      final complaint = _fromDocument(snapshot);
      ComplaintWritePolicy.validate(
        complaint: complaint,
        authenticatedUserId: _auth.currentUser?.uid,
      );
      return complaint;
    } on FirebaseException catch (error) {
      throw _mapAndLog(error);
    }
  }

  @override
  Future<Complaint> record(Complaint complaint) async {
    ComplaintWritePolicy.validate(
      complaint: complaint,
      authenticatedUserId: _auth.currentUser?.uid,
    );
    final reference = _collection.doc(complaint.id);
    try {
      return await _firestore.runTransaction<Complaint>((transaction) async {
        final existing = await transaction.get(reference);
        if (existing.exists) {
          final recorded = _fromDocument(existing);
          ComplaintWritePolicy.validate(
            complaint: recorded,
            authenticatedUserId: _auth.currentUser?.uid,
          );
          if (recorded.userId != complaint.userId ||
              recorded.detectionId != complaint.detectionId) {
            throw const ComplaintRepositoryException(
              code: 'ownership-mismatch',
              message: 'The existing complaint does not match this detection. Refresh History and try again.',
            );
          }
          return recorded;
        }
        transaction.set(reference, _toMap(complaint));
        return complaint;
      });
    } on FirebaseException catch (error) {
      throw _mapAndLog(error);
    }
  }

  void _validateAuthenticatedUser(String userId) {
    final authenticatedUserId = _auth.currentUser?.uid;
    if (authenticatedUserId == null || authenticatedUserId.isEmpty) {
      throw const ComplaintRepositoryException(
        code: 'unauthenticated',
        message: 'Sign in again before opening this complaint.',
      );
    }
    if (authenticatedUserId != userId) {
      throw const ComplaintRepositoryException(
        code: 'unauthorized-user',
        message: 'You can only open complaints recorded by your account.',
      );
    }
  }

  ComplaintRepositoryException _mapAndLog(FirebaseException error) {
    debugPrint(
      '[RoadLens complaint] ${error.plugin}/${error.code}: ${error.message}',
    );
    return mapComplaintFirebaseException(error);
  }

  Complaint _fromDocument(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data() ?? const <String, dynamic>{};
    return Complaint(
      id: document.id,
      userId: data['userId'] as String? ?? '',
      userDisplayName: data['userDisplayName'] as String? ?? '',
      userEmail: data['userEmail'] as String? ?? '',
      detectionId: data['detectionId'] as String? ?? '',
      status: _status(data['status']),
      deliveryStatus: _deliveryStatus(data['deliveryStatus']),
      recipientName: data['recipientName'] as String? ?? 'Road authority',
      recipientEmail: data['recipientEmail'] as String?,
      subject: data['subject'] as String? ?? '',
      body: data['body'] as String? ?? '',
      damageType: data['damageType'] as String? ?? '',
      severity: data['severity'] as String? ?? '',
      confidence: (data['confidence'] as num?)?.toDouble() ?? 0,
      address: data['roadLocation'] as String? ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
      gpsAccuracy: (data['gpsAccuracy'] as num?)?.toDouble() ?? 0,
      source: data['detectionSource'] as String? ?? 'streetlens',
      isDemo: data['isDemo'] as bool? ?? false,
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
      roadResponsibilityId: data['roadResponsibilityId'] as String?,
      supervisingAuthorityName: data['supervisingAuthorityName'] as String?,
      recipientPhone: data['recipientPhone'] as String?,
      sourceTitle: data['sourceTitle'] as String?,
      sourceUrl: data['sourceUrl'] as String?,
      sourceSummary: data['sourceSummary'] as String?,
    );
  }

  Map<String, Object?> _toMap(Complaint item) => {
    'id': item.id,
    'userId': item.userId,
    'userDisplayName': item.userDisplayName,
    'userEmail': item.userEmail,
    'detectionId': item.detectionId,
    'status': item.status.name,
    'deliveryStatus': item.deliveryStatus.name,
    'recipientName': item.recipientName,
    'recipientEmail': item.recipientEmail,
    'subject': item.subject,
    'body': item.body,
    'damageType': item.damageType,
    'severity': item.severity,
    'confidence': item.confidence,
    'roadLocation': item.address,
    'latitude': item.latitude,
    'longitude': item.longitude,
    'gpsAccuracy': item.gpsAccuracy,
    'detectionSource': item.source,
    'isDemo': item.isDemo,
    'roadResponsibilityId': item.roadResponsibilityId,
    'responsiblePartyId': item.roadResponsibilityId,
    'responsiblePartyName': item.recipientName,
    'supervisingAuthorityName': item.supervisingAuthorityName,
    'recipientPhone': item.recipientPhone,
    'sourceTitle': item.sourceTitle,
    'sourceUrl': item.sourceUrl,
    'sourceSummary': item.sourceSummary,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  DateTime _date(Object? value) =>
      value is Timestamp ? value.toDate() : DateTime(1970);

  ComplaintStatus _status(Object? value) {
    for (final status in ComplaintStatus.values) {
      if (status.name == value) return status;
    }
    throw const ComplaintRepositoryException(
      code: 'invalid-stored-status',
      message: 'This complaint record is invalid. Please contact support.',
    );
  }

  ComplaintDeliveryStatus _deliveryStatus(Object? value) {
    for (final status in ComplaintDeliveryStatus.values) {
      if (status.name == value) return status;
    }
    throw const ComplaintRepositoryException(
      code: 'invalid-stored-delivery-status',
      message: 'This complaint record is invalid. Please contact support.',
    );
  }
}

class MemoryComplaintRepository implements ComplaintRepository {
  MemoryComplaintRepository({this.authenticatedUserId});

  final String? authenticatedUserId;
  final Map<String, Complaint> _items = {};

  @override
  Future<Complaint?> getForDetection({
    required String userId,
    required String detectionId,
  }) async {
    if (authenticatedUserId != null && authenticatedUserId != userId) {
      throw const ComplaintRepositoryException(
        code: 'unauthorized-user',
        message: 'You can only open complaints recorded by your account.',
      );
    }
    for (final item in _items.values) {
      if (item.userId == userId && item.detectionId == detectionId) return item;
    }
    return null;
  }

  @override
  Future<Complaint> record(Complaint complaint) async {
    ComplaintWritePolicy.validate(
      complaint: complaint,
      authenticatedUserId: authenticatedUserId ?? complaint.userId,
    );
    final existing = _items[complaint.id];
    if (existing != null) {
      if (existing.userId != complaint.userId ||
          existing.detectionId != complaint.detectionId) {
        throw const ComplaintRepositoryException(
          code: 'ownership-mismatch',
          message: 'The existing complaint does not match this detection. Refresh History and try again.',
        );
      }
      return existing;
    }
    _items[complaint.id] = complaint;
    return complaint;
  }
}

ComplaintRepositoryException mapComplaintFirebaseException(
  FirebaseException error,
) {
  final technicalCode = '${error.plugin}/${error.code}';
  return switch (error.code) {
    'permission-denied' => ComplaintRepositoryException(
      code: 'permission-denied',
      technicalCode: technicalCode,
      message: 'Complaint forwarding is not connected in this demo.',
    ),
    'unavailable' || 'network-request-failed' => ComplaintRepositoryException(
      code: 'temporarily-unavailable',
      technicalCode: technicalCode,
      message: 'The complaint service is temporarily unavailable. Check your connection and try again.',
    ),
    _ => ComplaintRepositoryException(
      code: 'firestore-error',
      technicalCode: technicalCode,
      message:
          'The complaint could not be recorded right now. Please try again.',
    ),
  };
}

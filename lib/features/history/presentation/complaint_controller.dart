import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/app_user.dart';
import '../../../data/models/complaint.dart';
import '../../../data/models/detection.dart';
import '../../../data/models/road_responsibility.dart';
import '../../../data/repositories/complaint_repository.dart';
import '../../../data/repositories/road_responsibility_repository.dart';

enum ComplaintWorkflowState {
  introduction,
  searching,
  responsiblePartyFound,
  noResponsiblePartyFound,
  searchError,
  submitting,
  recorded,
  cancelled,
}

class ComplaintViewState {
  const ComplaintViewState({
    this.workflow = ComplaintWorkflowState.introduction,
    this.lookup,
    this.complaint,
    this.errorMessage,
  });

  final ComplaintWorkflowState workflow;
  final RoadResponsibilityResult? lookup;
  final Complaint? complaint;
  final String? errorMessage;
}

class ComplaintController extends StateNotifier<ComplaintViewState> {
  ComplaintController(
    this._responsibilityRepository,
    this._complaintRepository, {
    required this.user,
    required this.detection,
  }) : super(const ComplaintViewState()) {
    Future<void>.microtask(_loadExisting);
  }

  final AppUser user;
  final Detection detection;
  final RoadResponsibilityRepository _responsibilityRepository;
  final ComplaintRepository _complaintRepository;
  int _operation = 0;
  bool _disposed = false;

  Future<void> _loadExisting() async {
    try {
      final existing = await _complaintRepository.getForDetection(
        userId: user.id,
        detectionId: detection.id,
      );
      if (!_disposed && existing != null) {
        state = ComplaintViewState(
          workflow: ComplaintWorkflowState.recorded,
          complaint: existing,
        );
      }
    } on Object {
      // The introduction remains usable; lookup/record will surface errors.
    }
  }

  Future<void> findResponsibleParty() async {
    final operation = ++_operation;
    state = const ComplaintViewState(
      workflow: ComplaintWorkflowState.searching,
    );
    try {
      final result = await _responsibilityRepository.findForDetection(
        detection,
      );
      if (!_canApply(operation)) return;
      state = ComplaintViewState(
        workflow: result.found
            ? ComplaintWorkflowState.responsiblePartyFound
            : ComplaintWorkflowState.noResponsiblePartyFound,
        lookup: result,
      );
    } on Object catch (error) {
      if (!_canApply(operation)) return;
      state = ComplaintViewState(
        workflow: ComplaintWorkflowState.searchError,
        errorMessage: 'Responsibility lookup failed: $error',
      );
    }
  }

  void cancelSearch() {
    _operation++;
    state = const ComplaintViewState(
      workflow: ComplaintWorkflowState.cancelled,
    );
  }

  void restart() {
    _operation++;
    state = const ComplaintViewState();
  }

  Future<void> recordComplaint() async {
    if (state.workflow == ComplaintWorkflowState.submitting ||
        state.workflow == ComplaintWorkflowState.recorded) {
      return;
    }
    final operation = ++_operation;
    final lookup = state.lookup;
    final responsibility = lookup?.responsibility;
    final fallback = lookup?.fallbackAuthority;
    final recipientName = responsibility == null
        ? fallback ?? 'Relevant road authority'
        : '${responsibility.responsiblePartyName} (${responsibility.responsiblePartyAcronym})';
    final isDemo =
        detection.isSynthetic ||
        responsibility?.isDemo == true ||
        lookup?.found == false;
    state = ComplaintViewState(
      workflow: ComplaintWorkflowState.submitting,
      lookup: lookup,
    );
    try {
      final now = DateTime.now();
      final complaint = Complaint(
        id: ComplaintWritePolicy.documentId(
          userId: user.id,
          detectionId: detection.id,
        ),
        userId: user.id,
        userDisplayName: user.name,
        userEmail: user.email,
        detectionId: detection.id,
        status: ComplaintStatus.recorded,
        deliveryStatus: ComplaintDeliveryStatus.deliveryUnavailable,
        recipientName: recipientName,
        recipientEmail: responsibility?.publicEmail,
        subject: 'Road Damage Complaint - ${detection.address}',
        body: _buildBody(recipientName, isDemo: isDemo),
        damageType: detection.damageType.label,
        severity: detection.severity.label,
        confidence: detection.confidence,
        address: detection.address,
        latitude: detection.latitude,
        longitude: detection.longitude,
        gpsAccuracy: detection.gpsAccuracy,
        source: detection.source,
        isDemo: isDemo,
        createdAt: now,
        updatedAt: now,
        roadResponsibilityId: responsibility?.id,
        supervisingAuthorityName: responsibility?.supervisingAuthorityName,
        recipientPhone: responsibility?.publicPhone,
        sourceTitle: responsibility?.sourceTitle,
        sourceUrl: responsibility?.sourceUrl,
        sourceSummary: responsibility?.sourceSummary,
      );
      final recorded = await _complaintRepository.record(complaint);
      if (!_canApply(operation)) return;
      state = ComplaintViewState(
        workflow: ComplaintWorkflowState.recorded,
        lookup: lookup,
        complaint: recorded,
      );
    } on Object catch (error) {
      if (!_canApply(operation)) return;
      state = ComplaintViewState(
        workflow: ComplaintWorkflowState.searchError,
        lookup: lookup,
        errorMessage: _friendlyComplaintError(error),
      );
    }
  }

  Future<void> retryAfterError() {
    return state.lookup == null ? findResponsibleParty() : recordComplaint();
  }

  String _friendlyComplaintError(Object error) {
    if (error is ComplaintRepositoryException) return error.message;
    return 'RoadLens could not record this complaint right now. Please try again.';
  }

  String _buildBody(String recipientName, {required bool isDemo}) {
    final demoNotice = isDemo
        ? '\n\nDemo notice: this report uses seeded demonstration data and has not been sent by email.'
        : '';
    final confidenceLabel = detection.isSynthetic
        ? '${(detection.confidence * 100).round()}% (Demo Data)'
        : '${(detection.confidence * 100).round()}%';
    return '''To: $recipientName

Dear Sir/Madam,

RoadLens recorded a road-safety complaint with the following details:

Damage type: ${detection.damageType.label}
Severity: ${detection.severity.label}
AI confidence: $confidenceLabel
Location: ${detection.address}
GPS: ${detection.latitude.toStringAsFixed(6)}, ${detection.longitude.toStringAsFixed(6)}
GPS accuracy: +/-${detection.gpsAccuracy.toStringAsFixed(1)} m
Detection date/time: ${detection.capturedAt.toIso8601String()}
Observed condition: ${detection.description}

This road damage may create a safety hazard. Please inspect the location and arrange appropriate repair or mitigation.

Reported by: ${user.name}
Account email: ${user.email}$demoNotice''';
  }

  bool _canApply(int operation) => !_disposed && operation == _operation;

  @override
  void dispose() {
    _disposed = true;
    _operation++;
    super.dispose();
  }
}

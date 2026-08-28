import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streetlens/data/models/app_user.dart';
import 'package:streetlens/data/models/complaint.dart';
import 'package:streetlens/data/models/detection.dart';
import 'package:streetlens/data/models/road_responsibility.dart';
import 'package:streetlens/data/repositories/complaint_repository.dart';
import 'package:streetlens/data/repositories/demo_road_responsibility_repository.dart';
import 'package:streetlens/data/repositories/firestore_complaint_repository.dart';
import 'package:streetlens/data/repositories/mock_detection_repository.dart';
import 'package:streetlens/data/repositories/road_responsibility_repository.dart';
import 'package:streetlens/data/seed/seed_data.dart';
import 'package:streetlens/features/history/presentation/complaint_controller.dart';
import 'package:streetlens/features/history/presentation/history_controller.dart';

void main() {
  group('authenticated detection history', () {
    test(
      'is user scoped, newest first, and filters by stable category',
      () async {
        const secondUser = AppUser(
          id: 'other-user',
          name: 'Other User',
          email: 'other@example.com',
        );
        final repository = MockDetectionRepository(
          detections: [
            ...SeedData.detectionsFor(SeedData.inspector),
            ...SeedData.detectionsFor(secondUser),
          ],
        );
        final controller = HistoryController(repository, SeedData.inspector.id);
        addTearDown(() async {
          controller.dispose();
          await repository.dispose();
        });
        await _settleAsync();

        expect(controller.state.records, hasLength(6));
        expect(
          controller.state.records.every(
            (item) => item.userId == SeedData.inspector.id,
          ),
          isTrue,
        );
        expect(
          controller.state.records.first.capturedAt.isAfter(
            controller.state.records.last.capturedAt,
          ),
          isTrue,
        );

        controller.setFilter(DamageType.crack);
        expect(controller.state.visibleRecords, hasLength(2));
        expect(
          controller.state.visibleRecords.every(
            (item) => item.damageType == DamageType.crack,
          ),
          isTrue,
        );
      },
    );

    test('demo seeding is deterministic and idempotent', () async {
      final repository = MockDetectionRepository(detections: const []);
      addTearDown(repository.dispose);

      await repository.seedFor(SeedData.inspector);
      await repository.seedFor(SeedData.inspector);
      final records = await repository.getForUser(SeedData.inspector.id);

      expect(records, hasLength(6));
      expect(records.map((item) => item.id).toSet(), hasLength(6));
      expect(records.every((item) => item.isSynthetic), isTrue);
      expect(records.every((item) => item.source == 'demo'), isTrue);
    });
  });

  group('complaint state machine', () {
    test('creates an own KMC demo complaint but never sends it', () async {
      final repository = MemoryComplaintRepository(
        authenticatedUserId: SeedData.inspector.id,
      );
      final detection = SeedData.detections.firstWhere(
        (item) => item.address.contains('Korangi'),
      );
      final controller = ComplaintController(
        const DemoRoadResponsibilityRepository(searchDelay: Duration.zero),
        repository,
        user: SeedData.inspector,
        detection: detection,
      );
      addTearDown(controller.dispose);
      await _settleAsync();

      final lookup = controller.findResponsibleParty();
      expect(controller.state.workflow, ComplaintWorkflowState.searching);
      await lookup;
      expect(
        controller.state.workflow,
        ComplaintWorkflowState.responsiblePartyFound,
      );
      expect(
        controller.state.lookup?.responsibility?.responsiblePartyAcronym,
        'KMC',
      );
      expect(controller.state.lookup?.responsibility?.isDemo, isTrue);

      final submission = controller.recordComplaint();
      expect(controller.state.workflow, ComplaintWorkflowState.submitting);
      await submission;
      expect(controller.state.workflow, ComplaintWorkflowState.recorded);
      final complaint = controller.state.complaint!;
      expect(complaint.userId, SeedData.inspector.id);
      expect(complaint.detectionId, detection.id);
      expect(
        complaint.id,
        ComplaintWritePolicy.documentId(
          userId: SeedData.inspector.id,
          detectionId: detection.id,
        ),
      );
      expect(complaint.deliveryStatus.name, 'deliveryUnavailable');
      expect(complaint.status.name, 'recorded');
      expect(complaint.subject, 'Road Damage Complaint - ${detection.address}');
      expect(complaint.body, contains('Dear Sir/Madam,'));
      expect(complaint.body, contains('RoadLens recorded'));
      expect(complaint.body, isNot(contains('StreetLens')));
      expect(complaint.body, contains('Demo Data'));
      expect(complaint.body, isNot(contains('email was sent')));
    });

    test('finds the FWO mapping with KMC supervision', () async {
      final detection = SeedData.detections.firstWhere(
        (item) => item.address.contains('University'),
      );
      final controller = ComplaintController(
        const DemoRoadResponsibilityRepository(searchDelay: Duration.zero),
        MemoryComplaintRepository(),
        user: SeedData.inspector,
        detection: detection,
      );
      addTearDown(controller.dispose);
      await _settleAsync();
      await controller.findResponsibleParty();

      final result = controller.state.lookup!.responsibility!;
      expect(result.responsiblePartyAcronym, 'FWO');
      expect(result.supervisingAuthorityName, contains('KMC'));
    });

    test('records Shahrah-e-Faisal and II Chundrigar KMC fallbacks', () async {
      for (final roadName in ['Shahrah-e-Faisal', 'Chundrigar']) {
        final repository = MemoryComplaintRepository(
          authenticatedUserId: SeedData.inspector.id,
        );
        final detection = SeedData.detections.firstWhere(
          (item) => item.address.contains(roadName),
        );
        final controller = ComplaintController(
          const DemoRoadResponsibilityRepository(searchDelay: Duration.zero),
          repository,
          user: SeedData.inspector,
          detection: detection,
        );
        await _settleAsync();
        await controller.findResponsibleParty();

        expect(
          controller.state.workflow,
          ComplaintWorkflowState.noResponsiblePartyFound,
        );
        expect(controller.state.lookup?.responsibility, isNull);
        expect(controller.state.lookup?.fallbackAuthority, contains('KMC'));
        await controller.recordComplaint();

        expect(controller.state.workflow, ComplaintWorkflowState.recorded);
        expect(controller.state.complaint?.recipientName, contains('KMC'));
        expect(controller.state.complaint?.isDemo, isTrue);
        expect(
          controller.state.complaint?.deliveryStatus,
          ComplaintDeliveryStatus.deliveryUnavailable,
        );
        controller.dispose();
      }
    });

    test('supports cancellation and lookup retry after an error', () async {
      final controller = ComplaintController(
        _FailingResponsibilityRepository(),
        MemoryComplaintRepository(),
        user: SeedData.inspector,
        detection: SeedData.detections.first,
      );
      addTearDown(controller.dispose);
      await _settleAsync();

      await controller.findResponsibleParty();
      expect(controller.state.workflow, ComplaintWorkflowState.searchError);
      expect(controller.state.errorMessage, contains('offline'));
      controller.cancelSearch();
      expect(controller.state.workflow, ComplaintWorkflowState.cancelled);
      controller.restart();
      expect(controller.state.workflow, ComplaintWorkflowState.introduction);
    });

    test('reopening uses the same record and enforces user access', () async {
      final repository = MemoryComplaintRepository();
      final detection = SeedData.detections.firstWhere(
        (item) => item.address.contains('Korangi'),
      );
      final first = ComplaintController(
        const DemoRoadResponsibilityRepository(searchDelay: Duration.zero),
        repository,
        user: SeedData.inspector,
        detection: detection,
      );
      await _settleAsync();
      await first.findResponsibleParty();
      await first.recordComplaint();
      final originalId = first.state.complaint!.id;
      first.dispose();

      final reopened = ComplaintController(
        const DemoRoadResponsibilityRepository(searchDelay: Duration.zero),
        repository,
        user: SeedData.inspector,
        detection: detection,
      );
      addTearDown(reopened.dispose);
      await _settleAsync();

      expect(reopened.state.workflow, ComplaintWorkflowState.recorded);
      expect(reopened.state.complaint?.id, originalId);
      expect(
        reopened.state.complaint?.id,
        ComplaintWritePolicy.documentId(
          userId: SeedData.inspector.id,
          detectionId: detection.id,
        ),
      );
      expect(
        await repository.getForDetection(
          userId: 'another-user',
          detectionId: detection.id,
        ),
        isNull,
      );
    });

    test('rejects a complaint for a different authenticated user', () async {
      final complaint = await _recordDemoComplaint();
      final repository = MemoryComplaintRepository(
        authenticatedUserId: 'another-user',
      );

      await expectLater(
        repository.record(complaint),
        throwsA(
          isA<ComplaintRepositoryException>().having(
            (error) => error.code,
            'code',
            'unauthorized-user',
          ),
        ),
      );
    });

    test('prevents sent and non-recorded Phase 2 states', () async {
      final complaint = await _recordDemoComplaint();
      final repository = MemoryComplaintRepository(
        authenticatedUserId: complaint.userId,
      );

      for (final invalid in [
        complaint.copyWith(deliveryStatus: ComplaintDeliveryStatus.sent),
        complaint.copyWith(status: ComplaintStatus.cancelled),
      ]) {
        await expectLater(
          repository.record(invalid),
          throwsA(
            isA<ComplaintRepositoryException>().having(
              (error) => error.code,
              'code',
              'invalid-phase-two-status',
            ),
          ),
        );
      }
    });

    test('maps Firestore permission errors to safe RoadLens copy', () {
      final error = mapComplaintFirebaseException(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'PERMISSION_DENIED: Missing or insufficient permissions.',
        ),
      );

      expect(error.technicalCode, 'cloud_firestore/permission-denied');
      expect(
        error.message,
        'Complaint forwarding is not connected in this demo.',
      );
      expect(error.message, isNot(contains('PERMISSION_DENIED')));
    });

    test(
      'presents a friendly repository failure and retries recording',
      () async {
        final repository = _RecoveringComplaintRepository();
        final controller = ComplaintController(
          const DemoRoadResponsibilityRepository(searchDelay: Duration.zero),
          repository,
          user: SeedData.inspector,
          detection: SeedData.detections.first,
        );
        addTearDown(controller.dispose);
        await _settleAsync();
        await controller.findResponsibleParty();
        await controller.recordComplaint();

        expect(controller.state.workflow, ComplaintWorkflowState.searchError);
        expect(
          controller.state.errorMessage,
          contains('RoadLens could not record'),
        );
        expect(
          controller.state.errorMessage,
          isNot(contains('permission-denied')),
        );

        await controller.retryAfterError();
        expect(controller.state.workflow, ComplaintWorkflowState.recorded);
        expect(repository.recordAttempts, 2);
      },
    );
  });
}

class _FailingResponsibilityRepository implements RoadResponsibilityRepository {
  @override
  Future<RoadResponsibilityResult> findForDetection(Detection detection) async {
    throw Exception('offline');
  }
}

class _RecoveringComplaintRepository implements ComplaintRepository {
  int recordAttempts = 0;

  @override
  Future<Complaint?> getForDetection({
    required String userId,
    required String detectionId,
  }) async => null;

  @override
  Future<Complaint> record(Complaint complaint) async {
    recordAttempts++;
    if (recordAttempts == 1) {
      throw const ComplaintRepositoryException(
        code: 'permission-denied',
        technicalCode: 'cloud_firestore/permission-denied',
        message: 'RoadLens could not record this complaint. Refresh History and try again.',
      );
    }
    return complaint;
  }
}

Future<Complaint> _recordDemoComplaint() async {
  final controller = ComplaintController(
    const DemoRoadResponsibilityRepository(searchDelay: Duration.zero),
    MemoryComplaintRepository(authenticatedUserId: SeedData.inspector.id),
    user: SeedData.inspector,
    detection: SeedData.detections.firstWhere(
      (item) => item.address.contains('Korangi'),
    ),
  );
  await _settleAsync();
  await controller.findResponsibleParty();
  await controller.recordComplaint();
  final complaint = controller.state.complaint!;
  controller.dispose();
  return complaint;
}

Future<void> _settleAsync() async {
  for (var index = 0; index < 8; index++) {
    await Future<void>.delayed(Duration.zero);
  }
}

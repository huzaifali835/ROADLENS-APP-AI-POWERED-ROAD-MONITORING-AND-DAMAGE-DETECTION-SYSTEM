import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../seed/seed_data.dart';
import 'firestore_detection_repository.dart';

abstract interface class DemoDetectionSeeder {
  Future<void> seedOnce(AppUser user);
}

class FirestoreDemoDetectionSeeder implements DemoDetectionSeeder {
  FirestoreDemoDetectionSeeder(this._firestore, this._repository);

  final FirebaseFirestore _firestore;
  final FirestoreDetectionRepository _repository;

  @override
  Future<void> seedOnce(AppUser user) async {
    if (!kDebugMode || user.id.isEmpty) return;
    final userReference = _firestore.collection('users').doc(user.id);
    final batch = _firestore.batch();
    for (final detection in SeedData.detectionsFor(user)) {
      batch.set(
        _firestore.collection('detections').doc(detection.id),
        _repository.toFirestore(detection),
        SetOptions(merge: true),
      );
    }
    batch.set(userReference, {
      'demoDetectionsSeeded': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }
}

class NoOpDemoDetectionSeeder implements DemoDetectionSeeder {
  const NoOpDemoDetectionSeeder();

  @override
  Future<void> seedOnce(AppUser user) async {}
}

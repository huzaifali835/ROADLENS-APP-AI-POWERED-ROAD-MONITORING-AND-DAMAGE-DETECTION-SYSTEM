import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/bounding_box.dart';
import '../models/detection.dart';
import 'detection_repository.dart';

class FirestoreDetectionRepository implements DetectionRepository {
  FirestoreDetectionRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('detections');

  @override
  Stream<List<Detection>> watchForUser(String userId) {
    if (userId.isEmpty) return Stream.value(const []);
    return _collection
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) =>
              _sorted(snapshot.docs.map((document) => _fromDocument(document))),
        );
  }

  @override
  Future<List<Detection>> getForUser(String userId) async {
    if (userId.isEmpty) return const [];
    final snapshot = await _collection.where('userId', isEqualTo: userId).get();
    return _sorted(snapshot.docs.map(_fromDocument));
  }

  @override
  Future<List<Detection>> getAll() {
    throw UnsupportedError('Use getForUser so detections remain user-scoped.');
  }

  @override
  Future<Detection?> getById(String id, {required String userId}) async {
    final snapshot = await _collection.doc(id).get();
    if (!snapshot.exists || snapshot.data()?['userId'] != userId) return null;
    return _fromDocument(snapshot);
  }

  @override
  Future<void> save(Detection detection) async {
    final existing = await _collection.doc(detection.id).get();
    if (existing.exists && existing.data()?['userId'] != detection.userId) {
      throw StateError('A detection cannot be reassigned to another user.');
    }
    await _collection.doc(detection.id).set(_toMap(detection));
  }

  Map<String, Object?> toFirestore(Detection detection) => _toMap(detection);

  Detection _fromDocument(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data() ?? const <String, dynamic>{};
    final box = data['boundingBox'];
    final timestamp = data['capturedAt'];
    return Detection(
      id: document.id,
      userId: data['userId'] as String? ?? '',
      userDisplayName: data['userDisplayName'] as String? ?? '',
      userEmail: data['userEmail'] as String? ?? '',
      damageType: DamageTypeDetails.parse(data['damageType']),
      severity: DetectionSeverityLabel.parse(data['severity']),
      confidence: (data['confidence'] as num?)?.toDouble() ?? 0,
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
      gpsAccuracy: (data['gpsAccuracy'] as num?)?.toDouble() ?? 0,
      address: data['address'] as String? ?? 'Unknown location',
      description: data['description'] as String? ?? '',
      localImagePath: data['localImagePath'] as String?,
      imageUrl: data['imageUrl'] as String?,
      capturedAt: timestamp is Timestamp
          ? timestamp.toDate()
          : DateTime.tryParse(timestamp?.toString() ?? '') ?? DateTime(1970),
      synchronizationStatus: SynchronizationStatusValue.parse(
        data['syncStatus'],
      ),
      modelVersion: data['modelVersion'] as String? ?? 'unknown',
      source: data['source'] as String? ?? 'unknown',
      isSynthetic: data['isSynthetic'] as bool? ?? false,
      boundingBox: box is Map
          ? BoundingBox(
              left: (box['left'] as num?)?.toDouble() ?? 0,
              top: (box['top'] as num?)?.toDouble() ?? 0,
              width: (box['width'] as num?)?.toDouble() ?? 0,
              height: (box['height'] as num?)?.toDouble() ?? 0,
            )
          : null,
    );
  }

  Map<String, Object?> _toMap(Detection item) => {
    'id': item.id,
    'userId': item.userId,
    'userDisplayName': item.userDisplayName,
    'userEmail': item.userEmail,
    'damageType': item.damageType.id,
    'severity': item.severity.id,
    'confidence': item.confidence,
    'latitude': item.latitude,
    'longitude': item.longitude,
    'gpsAccuracy': item.gpsAccuracy,
    'address': item.address,
    'description': item.description,
    'localImagePath': item.localImagePath,
    'imageUrl': item.imageUrl,
    'capturedAt': Timestamp.fromDate(item.capturedAt),
    'syncStatus': item.synchronizationStatus.name,
    'modelVersion': item.modelVersion,
    'source': item.source,
    'isSynthetic': item.isSynthetic,
    'boundingBox': item.boundingBox == null
        ? null
        : {
            'left': item.boundingBox!.left,
            'top': item.boundingBox!.top,
            'width': item.boundingBox!.width,
            'height': item.boundingBox!.height,
          },
  };

  List<Detection> _sorted(Iterable<Detection> items) {
    final result = List<Detection>.of(items)
      ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return List.unmodifiable(result);
  }
}

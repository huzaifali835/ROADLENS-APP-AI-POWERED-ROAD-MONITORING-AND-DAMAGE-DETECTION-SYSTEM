abstract interface class SyncService {
  DateTime? get lastSyncAt;

  Future<int> syncPendingDetections();
}

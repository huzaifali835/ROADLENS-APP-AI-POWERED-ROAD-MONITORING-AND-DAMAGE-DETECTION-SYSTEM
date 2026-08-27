import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/detection.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/detection_repository.dart';

enum HistoryLoadStatus { loading, ready, error }

class HistoryViewState {
  const HistoryViewState({
    this.status = HistoryLoadStatus.loading,
    this.records = const [],
    this.query = '',
    this.expandedIds = const {},
    this.errorMessage,
  });

  final HistoryLoadStatus status;
  final List<Detection> records;
  final String query;
  final Set<String> expandedIds;
  final String? errorMessage;

  List<Detection> get visibleRecords {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return records;
    return records
        .where((record) {
          return record.id.toLowerCase().contains(normalized) ||
              record.damageType.toLowerCase().contains(normalized) ||
              record.address.toLowerCase().contains(normalized) ||
              record.severity.label.toLowerCase().contains(normalized);
        })
        .toList(growable: false);
  }

  HistoryViewState copyWith({
    HistoryLoadStatus? status,
    List<Detection>? records,
    String? query,
    Set<String>? expandedIds,
    String? errorMessage,
    bool clearError = false,
  }) {
    return HistoryViewState(
      status: status ?? this.status,
      records: records ?? this.records,
      query: query ?? this.query,
      expandedIds: expandedIds ?? this.expandedIds,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class HistoryController extends StateNotifier<HistoryViewState> {
  HistoryController(this._repository) : super(const HistoryViewState()) {
    Future<void>.microtask(load);
  }

  final DetectionRepository _repository;

  Future<void> load() async {
    state = state.copyWith(status: HistoryLoadStatus.loading, clearError: true);
    try {
      final records = await _repository.getAll();
      state = HistoryViewState(
        status: HistoryLoadStatus.ready,
        records: records,
        query: state.query,
      );
    } on Object catch (error) {
      state = HistoryViewState(
        status: HistoryLoadStatus.error,
        errorMessage: 'Unable to load detection history: $error',
      );
    }
  }

  void search(String query) => state = state.copyWith(query: query);

  void toggleExpanded(String id) {
    final updated = Set<String>.of(state.expandedIds);
    updated.contains(id) ? updated.remove(id) : updated.add(id);
    state = state.copyWith(expandedIds: Set.unmodifiable(updated));
  }
}

final historyControllerProvider =
    StateNotifierProvider.autoDispose<HistoryController, HistoryViewState>((
      ref,
    ) {
      return HistoryController(ref.watch(detectionRepositoryProvider));
    });

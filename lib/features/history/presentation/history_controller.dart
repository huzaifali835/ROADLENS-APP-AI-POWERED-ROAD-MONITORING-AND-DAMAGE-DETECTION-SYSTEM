import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/detection.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/detection_repository.dart';
import '../../auth/presentation/auth_controller.dart';

enum HistoryLoadStatus { loading, ready, error }

class HistoryViewState {
  const HistoryViewState({
    this.status = HistoryLoadStatus.loading,
    this.records = const [],
    this.filter,
    this.errorMessage,
  });

  final HistoryLoadStatus status;
  final List<Detection> records;
  final DamageType? filter;
  final String? errorMessage;

  List<Detection> get visibleRecords => filter == null
      ? records
      : records
            .where((item) => item.damageType == filter)
            .toList(growable: false);

  HistoryViewState copyWith({
    HistoryLoadStatus? status,
    List<Detection>? records,
    DamageType? filter,
    bool clearFilter = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return HistoryViewState(
      status: status ?? this.status,
      records: records ?? this.records,
      filter: clearFilter ? null : filter ?? this.filter,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class HistoryController extends StateNotifier<HistoryViewState> {
  HistoryController(this._repository, this._userId)
    : super(const HistoryViewState()) {
    Future<void>.microtask(load);
  }

  final DetectionRepository _repository;
  final String _userId;
  StreamSubscription<List<Detection>>? _subscription;
  bool _disposed = false;

  Future<void> load() async {
    await _subscription?.cancel();
    if (_disposed) return;
    if (_userId.isEmpty) {
      state = const HistoryViewState(
        status: HistoryLoadStatus.error,
        errorMessage: 'Sign in to view your detection history.',
      );
      return;
    }
    state = state.copyWith(status: HistoryLoadStatus.loading, clearError: true);
    _subscription = _repository
        .watchForUser(_userId)
        .listen(
          (records) {
            if (_disposed) return;
            final sorted = List<Detection>.of(records)
              ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
            state = HistoryViewState(
              status: HistoryLoadStatus.ready,
              records: List.unmodifiable(sorted),
              filter: state.filter,
            );
          },
          onError: (Object error) {
            if (_disposed) return;
            state = HistoryViewState(
              status: HistoryLoadStatus.error,
              records: state.records,
              filter: state.filter,
              errorMessage: 'Unable to load your detection history: $error',
            );
          },
        );
  }

  void setFilter(DamageType? filter) {
    state = filter == null
        ? state.copyWith(clearFilter: true)
        : state.copyWith(filter: filter);
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

final historyControllerProvider =
    StateNotifierProvider.autoDispose<HistoryController, HistoryViewState>((
      ref,
    ) {
      final userId = ref.watch(
        authControllerProvider.select((state) => state.user?.id ?? ''),
      );
      return HistoryController(ref.watch(detectionRepositoryProvider), userId);
    });

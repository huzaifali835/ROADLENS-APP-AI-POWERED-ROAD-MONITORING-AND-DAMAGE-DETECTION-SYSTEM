import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/detection.dart';
import '../../../data/models/geo_location.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/detection_repository.dart';
import '../../../data/services/location_service.dart';

enum MapLoadStatus { loading, ready, error }

enum MapLocationStatus {
  checking,
  permissionRequired,
  requestingPermission,
  loading,
  ready,
  serviceDisabled,
  permanentlyDenied,
  error,
}

const _unchangedFilter = Object();
const _unchangedSelection = Object();

class MapViewState {
  const MapViewState({
    this.status = MapLoadStatus.loading,
    this.locationStatus = MapLocationStatus.checking,
    this.records = const [],
    this.filter,
    this.selectedId,
    this.currentLocation,
    this.errorMessage,
    this.locationMessage,
  });

  final MapLoadStatus status;
  final MapLocationStatus locationStatus;
  final List<Detection> records;
  final DetectionSeverity? filter;
  final String? selectedId;
  final GeoLocation? currentLocation;
  final String? errorMessage;
  final String? locationMessage;

  List<Detection> get filteredRecords => filter == null
      ? records
      : records
            .where((item) => item.severity == filter)
            .toList(growable: false);

  Detection? get selectedDetection {
    for (final detection in filteredRecords) {
      if (detection.id == selectedId) return detection;
    }
    return filteredRecords.isEmpty ? null : filteredRecords.first;
  }

  MapViewState copyWith({
    MapLoadStatus? status,
    MapLocationStatus? locationStatus,
    List<Detection>? records,
    Object? filter = _unchangedFilter,
    Object? selectedId = _unchangedSelection,
    GeoLocation? currentLocation,
    String? errorMessage,
    String? locationMessage,
    bool clearError = false,
    bool clearLocationMessage = false,
  }) {
    return MapViewState(
      status: status ?? this.status,
      locationStatus: locationStatus ?? this.locationStatus,
      records: records ?? this.records,
      filter: identical(filter, _unchangedFilter)
          ? this.filter
          : filter as DetectionSeverity?,
      selectedId: identical(selectedId, _unchangedSelection)
          ? this.selectedId
          : selectedId as String?,
      currentLocation: currentLocation ?? this.currentLocation,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      locationMessage: clearLocationMessage
          ? null
          : locationMessage ?? this.locationMessage,
    );
  }
}

class MapViewModel extends StateNotifier<MapViewState> {
  MapViewModel(this._repository, this._locationService)
    : super(const MapViewState()) {
    Future<void>.microtask(load);
    Future<void>.microtask(refreshLocation);
  }

  final DetectionRepository _repository;
  final LocationService _locationService;
  StreamSubscription<GeoLocation>? _locationSubscription;
  bool _disposed = false;
  bool _active = true;

  Future<void> load() async {
    if (_disposed) return;
    state = state.copyWith(status: MapLoadStatus.loading, clearError: true);
    try {
      final records = await _repository.getAll();
      if (_disposed) return;
      state = state.copyWith(
        status: MapLoadStatus.ready,
        records: records,
        selectedId: records.isEmpty ? null : records.first.id,
        clearError: true,
      );
    } on Object catch (error) {
      if (_disposed) return;
      state = state.copyWith(
        status: MapLoadStatus.error,
        errorMessage: 'Unable to load detection records: $error',
      );
    }
  }

  Future<void> refreshLocation() async {
    if (_disposed || !_active) return;
    await _stopLocationUpdates();
    state = state.copyWith(
      locationStatus: MapLocationStatus.checking,
      clearLocationMessage: true,
    );
    try {
      if (!await _locationService.isServiceEnabled()) {
        if (!_canUpdate) return;
        state = state.copyWith(
          locationStatus: MapLocationStatus.serviceDisabled,
          locationMessage: 'Phone Location services are turned off.',
        );
        return;
      }
      final permission = await _locationService.checkPermission();
      if (!_canUpdate) return;
      switch (permission) {
        case LocationPermissionStatus.granted:
          await _loadCurrentLocation();
          return;
        case LocationPermissionStatus.denied ||
            LocationPermissionStatus.unknown:
          state = state.copyWith(
            locationStatus: MapLocationStatus.permissionRequired,
            locationMessage: 'Allow location while using StreetLens to center the map on this phone.',
          );
          return;
        case LocationPermissionStatus.permanentlyDenied:
          state = state.copyWith(
            locationStatus: MapLocationStatus.permanentlyDenied,
            locationMessage:
                'Location access is disabled in Android app settings.',
          );
          return;
      }
    } on Object catch (error) {
      _setLocationError(error);
    }
  }

  Future<void> requestLocationPermission() async {
    if (!_canUpdate) return;
    state = state.copyWith(
      locationStatus: MapLocationStatus.requestingPermission,
      clearLocationMessage: true,
    );
    try {
      final permission = await _locationService.requestPermission();
      if (!_canUpdate) return;
      if (permission == LocationPermissionStatus.granted) {
        await _loadCurrentLocation();
      } else if (permission == LocationPermissionStatus.permanentlyDenied) {
        state = state.copyWith(
          locationStatus: MapLocationStatus.permanentlyDenied,
          locationMessage:
              'Location access is disabled in Android app settings.',
        );
      } else {
        state = state.copyWith(
          locationStatus: MapLocationStatus.permissionRequired,
          locationMessage:
              'Location permission was denied. You can grant it when ready.',
        );
      }
    } on Object catch (error) {
      _setLocationError(error);
    }
  }

  Future<void> _loadCurrentLocation() async {
    state = state.copyWith(
      locationStatus: MapLocationStatus.loading,
      clearLocationMessage: true,
    );
    try {
      final location = await _locationService.getCurrentLocation();
      if (!_canUpdate) return;
      state = state.copyWith(
        locationStatus: MapLocationStatus.ready,
        currentLocation: location,
        clearLocationMessage: true,
      );
      _locationSubscription = _locationService.watchLocation().listen((
        location,
      ) {
        if (!_canUpdate) return;
        state = state.copyWith(
          locationStatus: MapLocationStatus.ready,
          currentLocation: location,
          clearLocationMessage: true,
        );
      }, onError: (Object error) => _setLocationError(error));
    } on Object catch (error) {
      _setLocationError(error);
    }
  }

  void _setLocationError(Object error) {
    if (!_canUpdate) return;
    final status = error is LocationServiceException
        ? switch (error.reason) {
            LocationFailureReason.serviceDisabled =>
              MapLocationStatus.serviceDisabled,
            LocationFailureReason.permissionPermanentlyDenied =>
              MapLocationStatus.permanentlyDenied,
            LocationFailureReason.permissionDenied =>
              MapLocationStatus.permissionRequired,
            LocationFailureReason.unavailable => MapLocationStatus.error,
          }
        : MapLocationStatus.error;
    state = state.copyWith(
      locationStatus: status,
      locationMessage: error.toString(),
    );
  }

  Future<void> openLocationSettings() async {
    if (state.locationStatus == MapLocationStatus.serviceDisabled) {
      await _locationService.openLocationSettings();
    } else {
      await _locationService.openAppSettings();
    }
  }

  void setFilter(DetectionSeverity? severity) {
    final filtered = severity == null
        ? state.records
        : state.records.where((item) => item.severity == severity).toList();
    state = state.copyWith(
      filter: severity,
      selectedId: filtered.isEmpty ? null : filtered.first.id,
    );
  }

  void select(String detectionId) {
    state = state.copyWith(selectedId: detectionId);
  }

  Future<void> onAppInactive() async {
    if (_disposed || !_active) return;
    _active = false;
    await _stopLocationUpdates();
  }

  Future<void> onAppResumed() async {
    if (_disposed) return;
    _active = true;
    await refreshLocation();
  }

  Future<void> _stopLocationUpdates() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  bool get _canUpdate => !_disposed && _active;

  @override
  void dispose() {
    _disposed = true;
    _active = false;
    unawaited(_locationSubscription?.cancel());
    super.dispose();
  }
}

final mapControllerProvider =
    StateNotifierProvider.autoDispose<MapViewModel, MapViewState>((ref) {
      return MapViewModel(
        ref.watch(detectionRepositoryProvider),
        ref.watch(locationServiceProvider),
      );
    });

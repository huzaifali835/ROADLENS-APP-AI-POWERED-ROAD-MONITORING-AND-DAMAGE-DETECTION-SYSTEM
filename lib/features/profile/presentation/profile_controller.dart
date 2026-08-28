import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/app_user.dart';
import '../../../data/models/detection.dart';
import '../../../data/models/geo_location.dart';
import '../../../data/models/user_preferences.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/detection_repository.dart';
import '../../../data/repositories/user_profile_repository.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/sync_service.dart';
import '../../auth/presentation/auth_controller.dart';

enum ProfileSyncStatus { idle, syncing, success, error }

enum ProfileStatsStatus { loading, ready, empty, error }

enum ProfileLocationStatus {
  checking,
  permissionRequired,
  requestingPermission,
  loading,
  ready,
  serviceDisabled,
  permanentlyDenied,
  error,
}

class ProfileStatistics {
  const ProfileStatistics({
    this.total = 0,
    this.thisWeek = 0,
    this.averageConfidence = 0,
    this.critical = 0,
  });

  final int total;
  final int thisWeek;
  final double averageConfidence;
  final int critical;
}

class ProfileViewState {
  const ProfileViewState({
    required this.user,
    required this.preferences,
    this.statsStatus = ProfileStatsStatus.loading,
    this.statistics = const ProfileStatistics(),
    this.locationStatus = ProfileLocationStatus.checking,
    this.location,
    this.locationMessage,
    this.syncStatus = ProfileSyncStatus.idle,
    this.lastSyncAt,
    this.syncMessage,
  });

  final AppUser user;
  final UserPreferences preferences;
  final ProfileStatsStatus statsStatus;
  final ProfileStatistics statistics;
  final ProfileLocationStatus locationStatus;
  final GeoLocation? location;
  final String? locationMessage;
  final ProfileSyncStatus syncStatus;
  final DateTime? lastSyncAt;
  final String? syncMessage;

  ProfileViewState copyWith({
    AppUser? user,
    UserPreferences? preferences,
    ProfileStatsStatus? statsStatus,
    ProfileStatistics? statistics,
    ProfileLocationStatus? locationStatus,
    GeoLocation? location,
    String? locationMessage,
    bool clearLocationMessage = false,
    ProfileSyncStatus? syncStatus,
    DateTime? lastSyncAt,
    String? syncMessage,
    bool clearSyncMessage = false,
  }) {
    return ProfileViewState(
      user: user ?? this.user,
      preferences: preferences ?? this.preferences,
      statsStatus: statsStatus ?? this.statsStatus,
      statistics: statistics ?? this.statistics,
      locationStatus: locationStatus ?? this.locationStatus,
      location: location ?? this.location,
      locationMessage: clearLocationMessage
          ? null
          : locationMessage ?? this.locationMessage,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      syncMessage: clearSyncMessage ? null : syncMessage ?? this.syncMessage,
    );
  }
}

class ProfileController extends StateNotifier<ProfileViewState> {
  ProfileController(
    this._detectionRepository,
    this._profileRepository,
    this._locationService,
    this._syncService,
    this._onPreferencesChanged, {
    required AppUser user,
  }) : super(
         ProfileViewState(
           user: user,
           preferences: user.preferences,
           lastSyncAt: _syncService.lastSyncAt,
         ),
       ) {
    Future<void>.microtask(loadStatistics);
    Future<void>.microtask(refreshLocation);
  }

  final DetectionRepository _detectionRepository;
  final UserProfileRepository _profileRepository;
  final LocationService _locationService;
  final SyncService _syncService;
  final void Function(UserPreferences) _onPreferencesChanged;
  StreamSubscription<List<Detection>>? _detectionSubscription;
  StreamSubscription<GeoLocation>? _locationSubscription;
  bool _disposed = false;
  bool _active = true;

  Future<void> loadStatistics() async {
    await _detectionSubscription?.cancel();
    if (_disposed) return;
    state = state.copyWith(statsStatus: ProfileStatsStatus.loading);
    _detectionSubscription = _detectionRepository
        .watchForUser(state.user.id)
        .listen(
          (records) {
            if (_disposed) return;
            if (records.isEmpty) {
              state = state.copyWith(
                statsStatus: ProfileStatsStatus.empty,
                statistics: const ProfileStatistics(),
              );
              return;
            }
            final weekAgo = DateTime.now().subtract(const Duration(days: 7));
            final confidence = records.fold<double>(
              0,
              (sum, item) => sum + item.confidence,
            );
            state = state.copyWith(
              statsStatus: ProfileStatsStatus.ready,
              statistics: ProfileStatistics(
                total: records.length,
                thisWeek: records
                    .where((item) => item.capturedAt.isAfter(weekAgo))
                    .length,
                averageConfidence: confidence / records.length,
                critical: records
                    .where(
                      (item) => item.severity == DetectionSeverity.critical,
                    )
                    .length,
              ),
            );
          },
          onError: (Object error) {
            if (_disposed) return;
            state = state.copyWith(
              statsStatus: ProfileStatsStatus.error,
              syncMessage: 'Detection statistics are unavailable: $error',
              syncStatus: ProfileSyncStatus.error,
            );
          },
        );
  }

  Future<void> refreshLocation() async {
    if (_disposed || !_active) return;
    await _stopLocation();
    state = state.copyWith(
      locationStatus: ProfileLocationStatus.checking,
      clearLocationMessage: true,
    );
    try {
      if (!await _locationService.isServiceEnabled()) {
        if (!_canUpdate) return;
        state = state.copyWith(
          locationStatus: ProfileLocationStatus.serviceDisabled,
          locationMessage: 'Phone location services are turned off.',
        );
        return;
      }
      final permission = await _locationService.checkPermission();
      if (!_canUpdate) return;
      if (permission == LocationPermissionStatus.granted) {
        await _loadLocation();
      } else if (permission == LocationPermissionStatus.permanentlyDenied) {
        state = state.copyWith(
          locationStatus: ProfileLocationStatus.permanentlyDenied,
          locationMessage: 'Location access is disabled in Android settings.',
        );
      } else {
        state = state.copyWith(
          locationStatus: ProfileLocationStatus.permissionRequired,
          locationMessage: 'Allow location while using RoadLens to show your current coordinates.',
        );
      }
    } on Object catch (error) {
      _setLocationError(error);
    }
  }

  Future<void> requestLocationPermission() async {
    if (!_canUpdate) return;
    state = state.copyWith(
      locationStatus: ProfileLocationStatus.requestingPermission,
      clearLocationMessage: true,
    );
    try {
      final permission = await _locationService.requestPermission();
      if (!_canUpdate) return;
      if (permission == LocationPermissionStatus.granted) {
        await _loadLocation();
      } else if (permission == LocationPermissionStatus.permanentlyDenied) {
        state = state.copyWith(
          locationStatus: ProfileLocationStatus.permanentlyDenied,
          locationMessage: 'Location access is disabled in Android settings.',
        );
      } else {
        state = state.copyWith(
          locationStatus: ProfileLocationStatus.permissionRequired,
          locationMessage:
              'Location permission was denied. You can grant it when ready.',
        );
      }
    } on Object catch (error) {
      _setLocationError(error);
    }
  }

  Future<void> _loadLocation() async {
    state = state.copyWith(
      locationStatus: ProfileLocationStatus.loading,
      clearLocationMessage: true,
    );
    try {
      _setLocation(await _locationService.getCurrentLocation());
      if (!_canUpdate) return;
      _locationSubscription = _locationService.watchLocation().listen(
        _setLocation,
        onError: _setLocationError,
      );
    } on Object catch (error) {
      _setLocationError(error);
    }
  }

  void _setLocation(GeoLocation location) {
    if (!_canUpdate) return;
    state = state.copyWith(
      locationStatus: ProfileLocationStatus.ready,
      location: location,
      clearLocationMessage: true,
    );
  }

  void _setLocationError(Object error) {
    if (!_canUpdate) return;
    final status = error is LocationServiceException
        ? switch (error.reason) {
            LocationFailureReason.serviceDisabled =>
              ProfileLocationStatus.serviceDisabled,
            LocationFailureReason.permissionPermanentlyDenied =>
              ProfileLocationStatus.permanentlyDenied,
            LocationFailureReason.permissionDenied =>
              ProfileLocationStatus.permissionRequired,
            LocationFailureReason.unavailable => ProfileLocationStatus.error,
          }
        : ProfileLocationStatus.error;
    state = state.copyWith(
      locationStatus: status,
      locationMessage: error.toString(),
    );
  }

  Future<void> openLocationSettings() async {
    if (state.locationStatus == ProfileLocationStatus.serviceDisabled) {
      await _locationService.openLocationSettings();
    } else {
      await _locationService.openAppSettings();
    }
  }

  void setNotifications(bool value) => _updatePreferences(
    state.preferences.copyWith(notificationsEnabled: value),
  );
  void setAutoSave(bool value) =>
      _updatePreferences(state.preferences.copyWith(autoSaveEnabled: value));
  void setGpsTracking(bool value) =>
      _updatePreferences(state.preferences.copyWith(gpsTrackingEnabled: value));
  void setDarkMode(bool value) =>
      _updatePreferences(state.preferences.copyWith(darkModeEnabled: value));
  void setHighAccuracy(bool value) => _updatePreferences(
    state.preferences.copyWith(highAccuracyEnabled: value),
  );

  void _updatePreferences(UserPreferences preferences) {
    state = state.copyWith(
      preferences: preferences,
      user: state.user.copyWith(preferences: preferences),
      clearSyncMessage: true,
    );
    _onPreferencesChanged(preferences);
    unawaited(_persistPreferences(preferences));
  }

  Future<void> _persistPreferences(UserPreferences preferences) async {
    try {
      await _profileRepository.updateSettings(state.user.id, preferences);
    } on Object catch (error) {
      if (_disposed) return;
      state = state.copyWith(
        syncStatus: ProfileSyncStatus.error,
        syncMessage: 'Settings will retry when online: $error',
      );
    }
  }

  Future<void> syncNow() async {
    if (state.syncStatus == ProfileSyncStatus.syncing) return;
    state = state.copyWith(
      syncStatus: ProfileSyncStatus.syncing,
      clearSyncMessage: true,
    );
    try {
      final count = await _syncService.syncPendingDetections();
      if (_disposed) return;
      state = state.copyWith(
        syncStatus: ProfileSyncStatus.success,
        lastSyncAt: _syncService.lastSyncAt,
        syncMessage: '$count pending detection records processed.',
      );
    } on Object catch (error) {
      if (_disposed) return;
      state = state.copyWith(
        syncStatus: ProfileSyncStatus.error,
        syncMessage: 'Synchronization failed: $error',
      );
    }
  }

  Future<void> onAppInactive() async {
    if (_disposed || !_active) return;
    _active = false;
    await _stopLocation();
  }

  Future<void> onAppResumed() async {
    if (_disposed) return;
    _active = true;
    await refreshLocation();
  }

  Future<void> _stopLocation() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  bool get _canUpdate => !_disposed && _active;

  @override
  void dispose() {
    _disposed = true;
    _active = false;
    unawaited(_locationSubscription?.cancel());
    unawaited(_detectionSubscription?.cancel());
    super.dispose();
  }
}

final profileControllerProvider =
    StateNotifierProvider.autoDispose<ProfileController, ProfileViewState>((
      ref,
    ) {
      final user = ref.watch(
        authControllerProvider.select((state) => state.user),
      );
      final safeUser =
          user ?? const AppUser(id: '', name: '', email: '', role: 'user');
      return ProfileController(
        ref.watch(detectionRepositoryProvider),
        ref.watch(userProfileRepositoryProvider),
        ref.watch(locationServiceProvider),
        ref.watch(syncServiceProvider),
        ref.read(authControllerProvider.notifier).updatePreferences,
        user: safeUser,
      );
    });

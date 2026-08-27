import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/app_user.dart';
import '../../../data/models/user_preferences.dart';
import '../../../data/providers.dart';
import '../../../data/seed/seed_data.dart';
import '../../../data/services/sync_service.dart';

enum ProfileSyncStatus { idle, syncing, success, error }

class ProfileViewState {
  const ProfileViewState({
    required this.user,
    this.preferences = const UserPreferences.defaults(),
    this.syncStatus = ProfileSyncStatus.idle,
    this.lastSyncAt,
    this.syncMessage,
  });

  final AppUser user;
  final UserPreferences preferences;
  final ProfileSyncStatus syncStatus;
  final DateTime? lastSyncAt;
  final String? syncMessage;

  ProfileViewState copyWith({
    AppUser? user,
    UserPreferences? preferences,
    ProfileSyncStatus? syncStatus,
    DateTime? lastSyncAt,
    String? syncMessage,
    bool clearMessage = false,
  }) {
    return ProfileViewState(
      user: user ?? this.user,
      preferences: preferences ?? this.preferences,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      syncMessage: clearMessage ? null : syncMessage ?? this.syncMessage,
    );
  }
}

class ProfileController extends StateNotifier<ProfileViewState> {
  ProfileController({required AppUser user, required SyncService syncService})
    : _syncService = syncService,
      super(ProfileViewState(user: user, lastSyncAt: syncService.lastSyncAt));

  final SyncService _syncService;

  void setNotifications(bool value) {
    _updatePreferences(state.preferences.copyWith(notificationsEnabled: value));
  }

  void setAutoSave(bool value) {
    _updatePreferences(state.preferences.copyWith(autoSaveEnabled: value));
  }

  void setGpsTracking(bool value) {
    _updatePreferences(state.preferences.copyWith(gpsTrackingEnabled: value));
  }

  void setDarkMode(bool value) {
    _updatePreferences(state.preferences.copyWith(darkModeEnabled: value));
  }

  void setHighAccuracy(bool value) {
    _updatePreferences(state.preferences.copyWith(highAccuracyEnabled: value));
  }

  void _updatePreferences(UserPreferences preferences) {
    state = state.copyWith(preferences: preferences, clearMessage: true);
  }

  Future<void> syncNow() async {
    if (state.syncStatus == ProfileSyncStatus.syncing) return;
    state = state.copyWith(
      syncStatus: ProfileSyncStatus.syncing,
      clearMessage: true,
    );
    try {
      final count = await _syncService.syncPendingDetections();
      state = state.copyWith(
        syncStatus: ProfileSyncStatus.success,
        lastSyncAt: _syncService.lastSyncAt,
        syncMessage: '$count mock records synchronized locally.',
      );
    } on Object catch (error) {
      state = state.copyWith(
        syncStatus: ProfileSyncStatus.error,
        syncMessage: 'Mock synchronization failed: $error',
      );
    }
  }
}

final profileControllerProvider =
    StateNotifierProvider<ProfileController, ProfileViewState>((ref) {
      final authUser = ref.watch(authServiceProvider).currentUser;
      return ProfileController(
        user: authUser ?? SeedData.inspector,
        syncService: ref.watch(syncServiceProvider),
      );
    });

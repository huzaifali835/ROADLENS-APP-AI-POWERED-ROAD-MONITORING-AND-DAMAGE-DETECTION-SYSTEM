class UserPreferences {
  const UserPreferences({
    required this.notificationsEnabled,
    required this.autoSaveEnabled,
    required this.gpsTrackingEnabled,
    required this.darkModeEnabled,
    required this.highAccuracyEnabled,
  });

  const UserPreferences.defaults()
    : notificationsEnabled = true,
      autoSaveEnabled = true,
      gpsTrackingEnabled = true,
      darkModeEnabled = false,
      highAccuracyEnabled = true;

  final bool notificationsEnabled;
  final bool autoSaveEnabled;
  final bool gpsTrackingEnabled;
  final bool darkModeEnabled;
  final bool highAccuracyEnabled;

  factory UserPreferences.fromMap(Object? value) {
    final map = value is Map ? value : const <String, Object?>{};
    return UserPreferences(
      notificationsEnabled: map['notificationsEnabled'] as bool? ?? true,
      autoSaveEnabled: map['autoSaveEnabled'] as bool? ?? true,
      gpsTrackingEnabled: map['gpsTrackingEnabled'] as bool? ?? true,
      darkModeEnabled: map['darkModeEnabled'] as bool? ?? false,
      highAccuracyEnabled: map['highAccuracyEnabled'] as bool? ?? true,
    );
  }

  Map<String, Object?> toMap() => {
    'notificationsEnabled': notificationsEnabled,
    'autoSaveEnabled': autoSaveEnabled,
    'gpsTrackingEnabled': gpsTrackingEnabled,
    'darkModeEnabled': darkModeEnabled,
    'highAccuracyEnabled': highAccuracyEnabled,
  };

  UserPreferences copyWith({
    bool? notificationsEnabled,
    bool? autoSaveEnabled,
    bool? gpsTrackingEnabled,
    bool? darkModeEnabled,
    bool? highAccuracyEnabled,
  }) {
    return UserPreferences(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      autoSaveEnabled: autoSaveEnabled ?? this.autoSaveEnabled,
      gpsTrackingEnabled: gpsTrackingEnabled ?? this.gpsTrackingEnabled,
      darkModeEnabled: darkModeEnabled ?? this.darkModeEnabled,
      highAccuracyEnabled: highAccuracyEnabled ?? this.highAccuracyEnabled,
    );
  }
}

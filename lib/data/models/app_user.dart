import 'user_preferences.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.role = 'user',
    this.organization = '',
    this.avatarUrl,
    this.providerIds = const [],
    this.emailVerified = false,
    this.createdAt,
    this.updatedAt,
    this.lastLoginAt,
    this.preferences = const UserPreferences.defaults(),
    this.profileSyncPending = false,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String organization;
  final String? avatarUrl;
  final List<String> providerIds;
  final bool emailVerified;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLoginAt;
  final UserPreferences preferences;
  final bool profileSyncPending;

  String get providerLabel => providerIds.contains('google.com')
      ? 'Google'
      : providerIds.contains('password')
      ? 'Password'
      : 'Firebase';

  AppUser copyWith({
    String? name,
    String? email,
    String? role,
    String? organization,
    String? avatarUrl,
    List<String>? providerIds,
    bool? emailVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
    UserPreferences? preferences,
    bool? profileSyncPending,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      organization: organization ?? this.organization,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      providerIds: providerIds ?? this.providerIds,
      emailVerified: emailVerified ?? this.emailVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      preferences: preferences ?? this.preferences,
      profileSyncPending: profileSyncPending ?? this.profileSyncPending,
    );
  }
}

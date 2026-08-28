import '../models/user_preferences.dart';

abstract interface class UserProfileRepository {
  Future<void> updateSettings(String userId, UserPreferences preferences);
}

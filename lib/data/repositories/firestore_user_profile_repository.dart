import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_preferences.dart';
import 'user_profile_repository.dart';

class FirestoreUserProfileRepository implements UserProfileRepository {
  FirestoreUserProfileRepository(this._firestore);
  final FirebaseFirestore _firestore;

  @override
  Future<void> updateSettings(String userId, UserPreferences preferences) {
    return _firestore.collection('users').doc(userId).set({
      'settings': preferences.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

class MemoryUserProfileRepository implements UserProfileRepository {
  UserPreferences? lastPreferences;

  @override
  Future<void> updateSettings(
    String userId,
    UserPreferences preferences,
  ) async {
    lastPreferences = preferences;
  }
}

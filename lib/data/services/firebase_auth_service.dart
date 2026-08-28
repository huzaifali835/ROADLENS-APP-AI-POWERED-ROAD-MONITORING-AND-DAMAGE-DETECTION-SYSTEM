import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';

import '../models/app_user.dart';
import '../models/user_preferences.dart';
import 'auth_service.dart';

class FirebaseAuthService implements AuthService {
  FirebaseAuthService(this._auth, this._firestore, {GoogleSignIn? googleSignIn})
    : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final firebase_auth.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;
  Future<void>? _googleInitialization;
  AppUser? _currentUser;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Stream<AppUser?> userChanges() {
    return _auth.userChanges().asyncMap((user) async {
      if (user == null) {
        _currentUser = null;
        return null;
      }
      _currentUser = await _resolveUser(user);
      return _currentUser;
    });
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user!;
      var profilePending = false;
      try {
        await _mergeProfile(user, isLogin: true);
      } on Object {
        profilePending = true;
      }
      _currentUser = (await _resolveUser(user))
          .copyWith(profileSyncPending: profilePending);
      return _currentUser!;
    } on firebase_auth.FirebaseAuthException catch (error) {
      throw _mapFirebaseError(error);
    }
  }

  @override
  Future<AppUser> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    late firebase_auth.User user;
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      user = credential.user!;
    } on firebase_auth.FirebaseAuthException catch (error) {
      throw _mapFirebaseError(error);
    }

    var profilePending = false;
    try {
      await user.updateDisplayName(fullName.trim());
      await user.reload();
    } on Object {
      profilePending = true;
    }
    final refreshed = _auth.currentUser ?? user;
    try {
      await refreshed.sendEmailVerification();
    } on Object {
      // Verification can be retried later; it must not invalidate the account.
    }
    try {
      await _mergeProfile(
        refreshed,
        isLogin: true,
        displayNameOverride: fullName.trim(),
      );
    } on Object {
      profilePending = true;
    }
    _currentUser = (await _resolveUser(refreshed))
        .copyWith(name: fullName.trim(), profileSyncPending: profilePending);
    return _currentUser!;
  }

  @override
  Future<AppUser?> signInWithGoogle() async {
    try {
      _googleInitialization ??= _googleSignIn.initialize();
      await _googleInitialization;
      final googleUser = await _googleSignIn.authenticate();
      final googleAuthentication = googleUser.authentication;
      final credential = firebase_auth.GoogleAuthProvider.credential(
        idToken: googleAuthentication.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      final user = result.user!;
      var profilePending = false;
      try {
        await _mergeProfile(user, isLogin: true);
      } on Object {
        profilePending = true;
      }
      _currentUser = (await _resolveUser(user))
          .copyWith(profileSyncPending: profilePending);
      return _currentUser;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      throw AuthServiceException(
        AuthFailure.unknown,
        error.description ?? 'Google sign-in could not be completed.',
      );
    } on firebase_auth.FirebaseAuthException catch (error) {
      throw _mapFirebaseError(error);
    }
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on firebase_auth.FirebaseAuthException catch (error) {
      throw _mapFirebaseError(error);
    }
  }

  @override
  Future<AppUser> retryProfileInitialization() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthServiceException(
        AuthFailure.profileSync,
        'Sign in again before retrying profile setup.',
      );
    }
    try {
      await _mergeProfile(user, isLogin: false);
      _currentUser = await _resolveUser(user);
      return _currentUser!;
    } on Object {
      throw const AuthServiceException(
        AuthFailure.profileSync,
        'Your account is active, but the profile could not be saved. Retry when online.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      _googleInitialization ??= _googleSignIn.initialize();
      await _googleInitialization;
      await _googleSignIn.signOut();
    } on Object {
      // Firebase sign-out remains authoritative if Google has no local session.
    }
    await _auth.signOut();
    _currentUser = null;
  }

  Future<void> _mergeProfile(
    firebase_auth.User user, {
    required bool isLogin,
    String? displayNameOverride,
  }) async {
    final reference = _firestore.collection('users').doc(user.uid);
    final existing = await reference.get();
    final data = <String, Object?>{
      'uid': user.uid,
      'displayName': displayNameOverride ?? _bestDisplayName(user),
      'email': _bestEmail(user),
      'photoUrl': _bestPhoto(user),
      'providerIds': user.providerData
          .map((provider) => provider.providerId)
          .toSet()
          .toList(growable: false),
      'emailVerified': user.emailVerified,
      'updatedAt': FieldValue.serverTimestamp(),
      if (isLogin) 'lastLoginAt': FieldValue.serverTimestamp(),
      if (!existing.exists) ...{
        'createdAt': FieldValue.serverTimestamp(),
        'role': 'user',
        'settings': const UserPreferences.defaults().toMap(),
      },
    };
    await reference.set(data, SetOptions(merge: true));
  }

  Future<AppUser> _resolveUser(firebase_auth.User user) async {
    Map<String, dynamic>? profile;
    var profilePending = false;
    try {
      profile = (await _firestore.collection('users').doc(user.uid).get())
          .data();
    } on Object {
      profilePending = true;
    }
    String pick(String field, String fallback) {
      final value = profile?[field];
      return value is String && value.trim().isNotEmpty
          ? value.trim()
          : fallback;
    }

    final providerIds = profile?['providerIds'];
    return AppUser(
      id: user.uid,
      name: pick('displayName', _bestDisplayName(user)),
      email: pick('email', _bestEmail(user)),
      role: pick('role', 'user'),
      organization: pick('organization', 'RoadLens Field Team'),
      avatarUrl: pick('photoUrl', _bestPhoto(user) ?? '').isEmpty
          ? null
          : pick('photoUrl', _bestPhoto(user) ?? ''),
      providerIds: providerIds is List
          ? providerIds.whereType<String>().toList(growable: false)
          : user.providerData
                .map((provider) => provider.providerId)
                .toList(growable: false),
      emailVerified: profile?['emailVerified'] as bool? ?? user.emailVerified,
      createdAt: _date(profile?['createdAt']),
      updatedAt: _date(profile?['updatedAt']),
      lastLoginAt: _date(profile?['lastLoginAt']),
      preferences: UserPreferences.fromMap(profile?['settings']),
      profileSyncPending: profilePending,
    );
  }

  String _bestDisplayName(firebase_auth.User user) {
    final direct = user.displayName?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    for (final provider in user.providerData) {
      final value = provider.displayName?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    final email = _bestEmail(user);
    return email.contains('@') ? email.split('@').first : 'RoadLens User';
  }

  String _bestEmail(firebase_auth.User user) {
    final direct = user.email?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    for (final provider in user.providerData) {
      final value = provider.email?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return '';
  }

  String? _bestPhoto(firebase_auth.User user) {
    final direct = user.photoURL?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    for (final provider in user.providerData) {
      final value = provider.photoURL?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  DateTime? _date(Object? value) => value is Timestamp ? value.toDate() : null;

  AuthServiceException _mapFirebaseError(
    firebase_auth.FirebaseAuthException error,
  ) {
    return switch (error.code) {
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => const AuthServiceException(
        AuthFailure.invalidCredentials,
        'The email or password is incorrect.',
      ),
      'email-already-in-use' => const AuthServiceException(
        AuthFailure.emailInUse,
        'An account already exists for this email.',
      ),
      'weak-password' => const AuthServiceException(
        AuthFailure.weakPassword,
        'Choose a stronger password with at least 8 characters.',
      ),
      'invalid-email' => const AuthServiceException(
        AuthFailure.invalidEmail,
        'Enter a valid email address.',
      ),
      'user-disabled' => const AuthServiceException(
        AuthFailure.userDisabled,
        'This account has been disabled.',
      ),
      'network-request-failed' => const AuthServiceException(
        AuthFailure.network,
        'Check your internet connection and try again.',
      ),
      'account-exists-with-different-credential' => const AuthServiceException(
        AuthFailure.accountExistsWithDifferentCredential,
        'This email already uses a different sign-in method.',
      ),
      _ => AuthServiceException(
        AuthFailure.unknown,
        error.message ?? 'Authentication could not be completed.',
      ),
    };
  }
}

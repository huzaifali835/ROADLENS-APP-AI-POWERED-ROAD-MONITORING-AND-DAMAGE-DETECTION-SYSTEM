import '../models/app_user.dart';

enum AuthFailure {
  invalidCredentials,
  emailInUse,
  weakPassword,
  invalidEmail,
  userDisabled,
  network,
  cancelled,
  accountExistsWithDifferentCredential,
  profileSync,
  unknown,
}

class AuthServiceException implements Exception {
  const AuthServiceException(this.failure, this.message);

  final AuthFailure failure;
  final String message;

  @override
  String toString() => message;
}

abstract interface class AuthService {
  AppUser? get currentUser;

  Stream<AppUser?> userChanges();

  Future<AppUser> signIn({required String email, required String password});

  Future<AppUser> register({
    required String fullName,
    required String email,
    required String password,
  });

  /// Returns null only when the account chooser is cancelled.
  Future<AppUser?> signInWithGoogle();

  Future<void> requestPasswordReset(String email);

  Future<AppUser> retryProfileInitialization();

  Future<void> signOut();
}

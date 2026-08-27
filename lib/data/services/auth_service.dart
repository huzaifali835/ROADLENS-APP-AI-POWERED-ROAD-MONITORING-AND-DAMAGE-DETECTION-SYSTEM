import '../models/app_user.dart';

abstract interface class AuthService {
  AppUser? get currentUser;

  Future<AppUser> signIn({required String email, required String password});

  Future<AppUser> register({required String email, required String password});

  Future<AppUser> signInWithGoogle();

  Future<void> requestPasswordReset(String email);

  Future<void> signOut();
}

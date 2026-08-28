import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/app_user.dart';
import '../../../data/models/user_preferences.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/demo_detection_seeder.dart';
import '../../../data/services/auth_service.dart';

enum AuthSessionStatus { restoring, signedOut, signedIn }

enum AuthActionStatus { idle, loading, error }

class AuthViewState {
  const AuthViewState({
    this.sessionStatus = AuthSessionStatus.restoring,
    this.status = AuthActionStatus.idle,
    this.user,
    this.errorMessage,
    this.infoMessage,
  });

  final AuthSessionStatus sessionStatus;
  final AuthActionStatus status;
  final AppUser? user;
  final String? errorMessage;
  final String? infoMessage;

  bool get isBusy => status == AuthActionStatus.loading;

  AuthViewState copyWith({
    AuthSessionStatus? sessionStatus,
    AuthActionStatus? status,
    AppUser? user,
    String? errorMessage,
    String? infoMessage,
    bool clearUser = false,
    bool clearError = false,
    bool clearInfo = false,
  }) {
    return AuthViewState(
      sessionStatus: sessionStatus ?? this.sessionStatus,
      status: status ?? this.status,
      user: clearUser ? null : user ?? this.user,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      infoMessage: clearInfo ? null : infoMessage ?? this.infoMessage,
    );
  }
}

class AuthController extends StateNotifier<AuthViewState> {
  AuthController(this._authService, this._seeder)
    : super(const AuthViewState()) {
    _subscription = _authService.userChanges().listen(
      _onUserChanged,
      onError: _onSessionError,
    );
  }

  final AuthService _authService;
  final DemoDetectionSeeder _seeder;
  late final StreamSubscription<AppUser?> _subscription;
  bool _disposed = false;

  Future<bool> signIn(String email, String password) =>
      _run(() => _authService.signIn(email: email.trim(), password: password));

  Future<bool> register(String fullName, String email, String password) => _run(
    () => _authService.register(
      fullName: fullName.trim(),
      email: email.trim(),
      password: password,
    ),
  );

  Future<bool> signInWithGoogle() async {
    if (state.isBusy) return false;
    state = state.copyWith(
      status: AuthActionStatus.loading,
      clearError: true,
      clearInfo: true,
    );
    try {
      final user = await _authService.signInWithGoogle();
      if (_disposed) return false;
      if (user == null) {
        state = state.copyWith(
          status: AuthActionStatus.idle,
          infoMessage: 'Google sign-in was cancelled.',
        );
        return false;
      }
      await _acceptUser(user);
      return true;
    } on Object catch (error) {
      _setActionError(error);
      return false;
    }
  }

  Future<bool> requestPasswordReset(String email) async {
    if (state.isBusy) return false;
    state = state.copyWith(
      status: AuthActionStatus.loading,
      clearError: true,
      clearInfo: true,
    );
    try {
      await _authService.requestPasswordReset(email.trim());
      if (_disposed) return false;
      state = state.copyWith(
        status: AuthActionStatus.idle,
        infoMessage: 'Password reset email requested.',
      );
      return true;
    } on Object catch (error) {
      _setActionError(error);
      return false;
    }
  }

  Future<void> retryProfileInitialization() async {
    if (state.isBusy) return;
    state = state.copyWith(
      status: AuthActionStatus.loading,
      clearError: true,
      clearInfo: true,
    );
    try {
      await _acceptUser(await _authService.retryProfileInitialization());
      if (!_disposed) {
        state = state.copyWith(infoMessage: 'Profile setup completed.');
      }
    } on Object catch (error) {
      _setActionError(error);
    }
  }

  Future<void> signOut() async {
    if (state.isBusy) return;
    state = state.copyWith(status: AuthActionStatus.loading, clearError: true);
    try {
      await _authService.signOut();
      if (_disposed) return;
      state = const AuthViewState(sessionStatus: AuthSessionStatus.signedOut);
    } on Object catch (error) {
      _setActionError(error);
    }
  }

  void clearMessages() => state = state.copyWith(
    clearError: true,
    clearInfo: true,
    status: AuthActionStatus.idle,
  );

  void updatePreferences(UserPreferences preferences) {
    final user = state.user;
    if (user == null) return;
    state = state.copyWith(user: user.copyWith(preferences: preferences));
  }

  void _onUserChanged(AppUser? user) {
    if (_disposed) return;
    if (user == null) {
      state = const AuthViewState(sessionStatus: AuthSessionStatus.signedOut);
      return;
    }
    unawaited(_acceptUser(user));
  }

  Future<void> _acceptUser(AppUser user) async {
    if (_disposed) return;
    state = AuthViewState(
      sessionStatus: AuthSessionStatus.signedIn,
      user: user,
      infoMessage: user.profileSyncPending
          ? 'Your account is active. Profile setup will retry when online.'
          : null,
    );
    try {
      await _seeder.seedOnce(user);
    } on Object {
      // Demo records are optional and must never block a real account session.
    }
  }

  void _onSessionError(Object error, StackTrace stackTrace) {
    if (_disposed) return;
    state = AuthViewState(
      sessionStatus: AuthSessionStatus.signedOut,
      status: AuthActionStatus.error,
      errorMessage: _message(error),
    );
  }

  Future<bool> _run(Future<AppUser> Function() action) async {
    if (state.isBusy) return false;
    state = state.copyWith(
      status: AuthActionStatus.loading,
      clearError: true,
      clearInfo: true,
    );
    try {
      await _acceptUser(await action());
      return true;
    } on Object catch (error) {
      _setActionError(error);
      return false;
    }
  }

  void _setActionError(Object error) {
    if (_disposed) return;
    state = state.copyWith(
      status: AuthActionStatus.error,
      errorMessage: _message(error),
    );
  }

  String _message(Object error) => error
      .toString()
      .replaceFirst('AuthServiceException: ', '')
      .replaceFirst('FormatException: ', '')
      .replaceFirst('Exception: ', '');

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthViewState>((ref) {
      return AuthController(
        ref.watch(authServiceProvider),
        ref.watch(demoDetectionSeederProvider),
      );
    });

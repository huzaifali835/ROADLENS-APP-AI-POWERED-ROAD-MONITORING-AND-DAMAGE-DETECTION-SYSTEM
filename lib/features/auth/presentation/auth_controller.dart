import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/app_user.dart';
import '../../../data/providers.dart';
import '../../../data/services/auth_service.dart';

enum AuthActionStatus { idle, loading, error }

class AuthViewState {
  const AuthViewState({
    this.status = AuthActionStatus.idle,
    this.user,
    this.errorMessage,
  });

  final AuthActionStatus status;
  final AppUser? user;
  final String? errorMessage;

  AuthViewState copyWith({
    AuthActionStatus? status,
    AppUser? user,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthViewState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class AuthController extends StateNotifier<AuthViewState> {
  AuthController(this._authService) : super(const AuthViewState());

  final AuthService _authService;

  Future<bool> signIn(String email, String password) async {
    return _run(
      () => _authService.signIn(email: email.trim(), password: password),
    );
  }

  Future<bool> register(String email, String password) async {
    return _run(
      () => _authService.register(email: email.trim(), password: password),
    );
  }

  Future<bool> requestPasswordReset(String email) async {
    state = state.copyWith(status: AuthActionStatus.loading, clearError: true);
    try {
      await _authService.requestPasswordReset(email.trim());
      state = const AuthViewState();
      return true;
    } on Object catch (error) {
      state = AuthViewState(
        status: AuthActionStatus.error,
        errorMessage: error
            .toString()
            .replaceFirst('FormatException: ', '')
            .replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    state = const AuthViewState();
  }

  void clearError() => state = state.copyWith(clearError: true);

  Future<bool> _run(Future<AppUser> Function() action) async {
    state = state.copyWith(status: AuthActionStatus.loading, clearError: true);
    try {
      final user = await action();
      state = AuthViewState(user: user);
      return true;
    } on Object catch (error) {
      final message = error
          .toString()
          .replaceFirst('FormatException: ', '')
          .replaceFirst('Exception: ', '');
      state = AuthViewState(
        status: AuthActionStatus.error,
        errorMessage: message,
      );
      return false;
    }
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthViewState>((ref) {
      return AuthController(ref.watch(authServiceProvider));
    });

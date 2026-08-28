import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:streetlens/data/models/app_user.dart';
import 'package:streetlens/data/repositories/demo_detection_seeder.dart';
import 'package:streetlens/data/services/auth_service.dart';
import 'package:streetlens/features/auth/presentation/auth_controller.dart';

void main() {
  group('AuthController', () {
    test(
      'starts restoring and resolves a signed-out persisted session',
      () async {
        final service = TestAuthService();
        final controller = AuthController(
          service,
          const NoOpDemoDetectionSeeder(),
        );
        addTearDown(() async {
          controller.dispose();
          await service.dispose();
        });

        expect(controller.state.sessionStatus, AuthSessionStatus.restoring);
        await _settleAsync();
        expect(controller.state.sessionStatus, AuthSessionStatus.signedOut);
      },
    );

    test('restores a persisted user and signs out cleanly', () async {
      final service = TestAuthService(initialUser: testUser);
      final controller = AuthController(
        service,
        const NoOpDemoDetectionSeeder(),
      );
      addTearDown(() async {
        controller.dispose();
        await service.dispose();
      });

      await _settleAsync();
      expect(controller.state.sessionStatus, AuthSessionStatus.signedIn);
      expect(controller.state.user?.id, testUser.id);

      await controller.signOut();
      expect(controller.state.sessionStatus, AuthSessionStatus.signedOut);
      expect(controller.state.user, isNull);
    });

    test('maps credential errors without authenticating', () async {
      final service = TestAuthService(
        signInError: const AuthServiceException(
          AuthFailure.invalidCredentials,
          'The email or password is incorrect.',
        ),
      );
      final controller = AuthController(
        service,
        const NoOpDemoDetectionSeeder(),
      );
      addTearDown(() async {
        controller.dispose();
        await service.dispose();
      });
      await _settleAsync();

      expect(await controller.signIn('bad@example.com', 'badpass'), isFalse);
      expect(controller.state.sessionStatus, AuthSessionStatus.signedOut);
      expect(controller.state.errorMessage, contains('incorrect'));
    });

    test('Google cancellation is non-destructive and not an error', () async {
      final service = TestAuthService(cancelGoogle: true);
      final controller = AuthController(
        service,
        const NoOpDemoDetectionSeeder(),
      );
      addTearDown(() async {
        controller.dispose();
        await service.dispose();
      });
      await _settleAsync();

      expect(await controller.signInWithGoogle(), isFalse);
      expect(controller.state.errorMessage, isNull);
      expect(controller.state.infoMessage, contains('cancelled'));
    });

    test('registration carries the full name into the user session', () async {
      final service = TestAuthService();
      final controller = AuthController(
        service,
        const NoOpDemoDetectionSeeder(),
      );
      addTearDown(() async {
        controller.dispose();
        await service.dispose();
      });
      await _settleAsync();

      expect(
        await controller.register('Sam Field', 'sam@example.com', 'securepass'),
        isTrue,
      );
      expect(controller.state.user?.name, 'Sam Field');
      expect(controller.state.user?.providerLabel, 'Password');
    });
  });
}

const testUser = AppUser(
  id: 'user-a',
  name: 'Test Inspector',
  email: 'inspector@example.com',
  providerIds: ['password'],
  emailVerified: true,
);

class TestAuthService implements AuthService {
  TestAuthService({
    AppUser? initialUser,
    this.signInError,
    this.cancelGoogle = false,
  }) : _currentUser = initialUser;

  final Object? signInError;
  final bool cancelGoogle;
  final StreamController<AppUser?> _changes = StreamController.broadcast();
  AppUser? _currentUser;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Stream<AppUser?> userChanges() async* {
    yield _currentUser;
    yield* _changes.stream;
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    if (signInError case final error?) throw error;
    _currentUser = testUser.copyWith(email: email);
    _changes.add(_currentUser);
    return _currentUser!;
  }

  @override
  Future<AppUser> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    _currentUser = testUser.copyWith(name: fullName, email: email);
    _changes.add(_currentUser);
    return _currentUser!;
  }

  @override
  Future<AppUser?> signInWithGoogle() async {
    if (cancelGoogle) return null;
    _currentUser = testUser.copyWith(providerIds: const ['google.com']);
    _changes.add(_currentUser);
    return _currentUser;
  }

  @override
  Future<void> requestPasswordReset(String email) async {}

  @override
  Future<AppUser> retryProfileInitialization() async => _currentUser!;

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _changes.add(null);
  }

  Future<void> dispose() => _changes.close();
}

Future<void> _settleAsync() async {
  for (var index = 0; index < 5; index++) {
    await Future<void>.delayed(Duration.zero);
  }
}

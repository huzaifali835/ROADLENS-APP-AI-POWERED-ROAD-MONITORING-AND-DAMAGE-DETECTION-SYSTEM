import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/map/presentation/map_screen.dart';
import '../features/monitor/presentation/monitor_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import 'main_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen<AuthViewState>(authControllerProvider, (previous, next) {
    refresh.value++;
  });
  final router = GoRouter(
    initialLocation: '/session',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(authControllerProvider);
      final path = state.uri.path;
      final isAuthRoute =
          path == '/login' || path == '/register' || path == '/forgot-password';
      if (session.sessionStatus == AuthSessionStatus.restoring) {
        return path == '/session' ? null : '/session';
      }
      if (session.sessionStatus == AuthSessionStatus.signedOut) {
        return isAuthRoute ? null : '/login';
      }
      if (isAuthRoute || path == '/session' || path == '/') return '/monitor';
      return null;
    },
    routes: [
      GoRoute(
        path: '/session',
        builder: (context, state) => const _SessionRestoreScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return MainShell(location: state.uri.path, child: child);
        },
        routes: [
          GoRoute(
            path: '/monitor',
            pageBuilder: (context, state) {
              return const NoTransitionPage(child: MonitorScreen());
            },
          ),
          GoRoute(
            path: '/map',
            pageBuilder: (context, state) {
              return const NoTransitionPage(child: MapScreen());
            },
          ),
          GoRoute(
            path: '/history',
            pageBuilder: (context, state) {
              return const NoTransitionPage(child: HistoryScreen());
            },
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) {
              return const NoTransitionPage(child: ProfileScreen());
            },
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.route_outlined, size: 44),
                  const SizedBox(height: 12),
                  Text(
                    'This RoadLens page is unavailable.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Return to Login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

class _SessionRestoreScreen extends StatelessWidget {
  const _SessionRestoreScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Restoring your secure session...'),
            ],
          ),
        ),
      ),
    );
  }
}

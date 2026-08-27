import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/map/presentation/map_screen.dart';
import '../features/monitor/presentation/monitor_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import 'main_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
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
                    'This StreetLens page is unavailable.',
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
  ref.onDispose(router.dispose);
  return router;
});

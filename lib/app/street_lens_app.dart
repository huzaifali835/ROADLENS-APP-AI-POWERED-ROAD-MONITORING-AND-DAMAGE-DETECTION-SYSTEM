import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../features/auth/presentation/auth_controller.dart';
import 'app_router.dart';
import 'app_theme.dart';

class StreetLensApp extends ConsumerWidget {
  const StreetLensApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final darkMode = ref.watch(
      authControllerProvider.select(
        (state) => state.user?.preferences.darkModeEnabled ?? false,
      ),
    );
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }
}

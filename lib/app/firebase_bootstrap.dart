import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../firebase_options.dart';
import 'street_lens_app.dart';

class FirebaseBootstrapper {
  Future<void>? _initialization;

  Future<void> start({bool retry = false}) {
    if (retry) _initialization = null;
    return _initialization ??= Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

final firebaseBootstrapperProvider = Provider<FirebaseBootstrapper>(
  (ref) => FirebaseBootstrapper(),
);

final firebaseInitializationProvider = FutureProvider<void>(
  (ref) => ref.watch(firebaseBootstrapperProvider).start(),
);

class FirebaseBootstrap extends ConsumerWidget {
  const FirebaseBootstrap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initialization = ref.watch(firebaseInitializationProvider);
    return initialization.when(
      data: (_) => const StreetLensApp(),
      loading: () =>
          const _BootstrapMaterial(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _BootstrapMaterial(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'RoadLens could not start securely.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Check your connection and Firebase configuration, then retry.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('firebase-retry-button'),
              onPressed: () {
                ref.read(firebaseBootstrapperProvider).start(retry: true);
                ref.invalidate(firebaseInitializationProvider);
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BootstrapMaterial extends StatelessWidget {
  const _BootstrapMaterial({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, fontFamily: 'Poppins'),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(padding: const EdgeInsets.all(28), child: child),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/firebase_bootstrap.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final bootstrapper = FirebaseBootstrapper();
  bootstrapper.start();
  runApp(
    ProviderScope(
      overrides: [firebaseBootstrapperProvider.overrideWithValue(bootstrapper)],
      child: const FirebaseBootstrap(),
    ),
  );
}

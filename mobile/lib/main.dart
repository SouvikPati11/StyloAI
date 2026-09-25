import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'core/firebase_bootstrap.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Bounded internally so a slow/failed Firebase init can never block startup.
  await FirebaseBootstrap.init();

  final container = ProviderContainer();
  // Start session restoration WITHOUT blocking the first frame. The splash
  // shows while phase == loading; the router redirects to onboarding or home
  // as soon as bootstrap resolves, so the app can never hang on the splash.
  container.read(authControllerProvider.notifier).bootstrap();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const StyloApp(),
    ),
  );
}

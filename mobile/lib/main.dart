import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'core/firebase_bootstrap.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.init();

  final container = ProviderContainer();
  // Kick off session bootstrap (loads tokens, fetches profile if signed in).
  await container.read(authControllerProvider.notifier).bootstrap();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const StyloApp(),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'router.dart';
import 'theme.dart';

class StyloApp extends ConsumerStatefulWidget {
  const StyloApp({super.key});
  @override
  ConsumerState<StyloApp> createState() => _StyloAppState();
}

class _StyloAppState extends ConsumerState<StyloApp> {
  late final GoRouter _router = buildRouter(ref);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'StyloAI',
      debugShowCheckedModeBanner: false,
      // StyloAI's identity is the deep-navy / champagne-gold canvas (it matches
      // the launcher icon, native splash, and the admin Studio). Lock to dark so
      // the premium look is consistent on every device, regardless of the OS
      // light/dark setting. Both themes are retained for future use.
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      routerConfig: _router,
    );
  }
}

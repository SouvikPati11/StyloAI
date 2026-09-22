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
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: _router,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../state/providers.dart';

final _savedLooksProvider =
    FutureProvider.autoDispose<List<SavedLook>>((ref) async {
  return ref.read(looksRepoProvider).list();
});
final _historyProvider =
    FutureProvider.autoDispose<List<GenerationSummary>>((ref) async {
  return ref.read(generationRepoProvider).history();
});

class LooksScreen extends ConsumerWidget {
  const LooksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.gutter, AppSpace.md, AppSpace.gutter, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('My looks',
                      style: Theme.of(context).textTheme.headlineMedium),
                ),
              ),
              const TabBar(tabs: [Tab(text: 'Saved'), Tab(text: 'History')]),
              Expanded(
                child: TabBarView(
                  children: [
                    _SavedTab(),
                    _HistoryTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_savedLooksProvider);
    return async.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorStateView(
          message: '$e', onRetry: () => ref.invalidate(_savedLooksProvider)),
      data: (looks) {
        if (looks.isEmpty) {
          return EmptyState(
            icon: Icons.bookmark_border,
            title: 'No saved looks',
            subtitle: 'Save looks you love and they’ll appear here.',
            actionLabel: 'Create a look',
            onAction: () => context.push('/create/outfit'),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_savedLooksProvider),
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter, AppSpace.md, AppSpace.gutter, 90),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppSpace.md,
              mainAxisSpacing: AppSpace.md,
              childAspectRatio: 0.75,
            ),
            itemCount: looks.length,
            itemBuilder: (_, i) {
              final l = looks[i];
              return GestureDetector(
                onLongPress: () async {
                  await ref.read(looksRepoProvider).delete(l.id);
                  ref.invalidate(_savedLooksProvider);
                },
                child: RemoteImage(l.imageUrl, width: double.infinity),
              );
            },
          ),
        );
      },
    );
  }
}

class _HistoryTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_historyProvider);
    return async.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorStateView(
          message: '$e', onRetry: () => ref.invalidate(_historyProvider)),
      data: (items) {
        if (items.isEmpty) {
          return EmptyState(
            icon: Icons.history,
            title: 'No history yet',
            subtitle: 'Your generated looks will be listed here.',
            actionLabel: 'Create a look',
            onAction: () => context.push('/create/outfit'),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_historyProvider),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter, AppSpace.md, AppSpace.gutter, 90),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpace.md),
            itemBuilder: (_, i) {
              final g = items[i];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => context.push('/result/${g.id}'),
                leading: g.thumbnailUrl != null
                    ? RemoteImage(g.thumbnailUrl!,
                        width: 54, height: 54, radius: AppRadii.sm)
                    : Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                          border:
                              Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: const Icon(Icons.image_outlined,
                            color: AppColors.muted),
                      ),
                title: Text(_titleCase(g.type),
                    style: Theme.of(context).textTheme.titleMedium),
                subtitle: Text(_statusLabel(g.status)),
                trailing:
                    const Icon(Icons.chevron_right, color: AppColors.muted),
              );
            },
          ),
        );
      },
    );
  }

  String _titleCase(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');
  String _statusLabel(GenStatus s) {
    switch (s) {
      case GenStatus.succeeded:
        return 'Completed';
      case GenStatus.processing:
      case GenStatus.queued:
        return 'In progress';
      case GenStatus.refunded:
        return 'Failed — refunded';
      case GenStatus.failed:
        return 'Failed';
      default:
        return '—';
    }
  }
}

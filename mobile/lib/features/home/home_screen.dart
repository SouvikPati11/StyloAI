import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../state/providers.dart';
import '../create/create_types.dart';

final _homeTrendingProvider =
    FutureProvider.autoDispose<List<TrendingItem>>((ref) async {
  return ref.read(contentRepoProvider).trending();
});
final _homeRecentProvider =
    FutureProvider.autoDispose<List<GenerationSummary>>((ref) async {
  return ref.read(generationRepoProvider).history();
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final me = auth.me;
    final t = Theme.of(context).textTheme;
    final greeting = _greeting();
    final name = (me?.displayName ?? '').split(' ').first;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(_homeTrendingProvider);
            ref.invalidate(_homeRecentProvider);
            await ref.read(authControllerProvider.notifier).refreshMe();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter, AppSpace.md, AppSpace.gutter, 90),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(greeting, style: t.bodySmall),
                        Text(name.isEmpty ? 'Welcome' : name,
                            style: t.headlineMedium),
                      ],
                    ),
                  ),
                  CreditChip(
                      balance: me?.balance,
                      onTap: () => context.push('/credits')),
                ],
              ),
              const SizedBox(height: AppSpace.xl),
              _ImproveCta(onTap: () => _openCreate(context)),
              const SizedBox(height: AppSpace.xl),
              Text('Quick create', style: t.titleLarge),
              const SizedBox(height: AppSpace.md),
              _QuickCreateRow(),
              const SizedBox(height: AppSpace.xl),
              const SectionHeader(title: 'Trending now'),
              _TrendingStrip(),
              const SizedBox(height: AppSpace.xl),
              const SectionHeader(title: 'Your recent looks'),
              _RecentStrip(),
            ],
          ),
        ),
      ),
    );
  }

  void _openCreate(BuildContext context) => context.push('/create/outfit');

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _ImproveCta extends StatelessWidget {
  final VoidCallback onTap;
  const _ImproveCta({required this.onTap});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.lg),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.xl),
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Improve my look',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('Upload your photo and try a new style in seconds.',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13.5)),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.md),
            const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.arrow_forward, color: AppColors.accent),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickCreateRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final quick = kCreateTypes.take(4).toList();
    return SizedBox(
      height: 96,
      child: Row(
        children: [
          for (final c in quick) ...[
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadii.md),
                onTap: () => context.push('/create/${c.type}'),
                child: Card(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(c.icon,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 6),
                        Text(c.label,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (c != quick.last) const SizedBox(width: AppSpace.sm),
          ]
        ],
      ),
    );
  }
}

class _TrendingStrip extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_homeTrendingProvider);
    return SizedBox(
      height: 190,
      child: async.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorStateView(
            message: '$e',
            onRetry: () => ref.invalidate(_homeTrendingProvider)),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.trending_up,
              title: 'No trending styles yet',
              subtitle: 'New looks are curated regularly — check back soon.',
            );
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpace.md),
            itemBuilder: (_, i) {
              final item = items[i];
              return GestureDetector(
                onTap: () => context.push('/create/${item.section}'),
                child: SizedBox(
                  width: 140,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RemoteImage(item.imageUrl, width: 140, height: 150),
                      const SizedBox(height: 6),
                      Text(item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _RecentStrip extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_homeRecentProvider);
    return SizedBox(
      height: 150,
      child: async.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorStateView(
            message: '$e', onRetry: () => ref.invalidate(_homeRecentProvider)),
        data: (items) {
          final done = items.where((g) => g.thumbnailUrl != null).toList();
          if (done.isEmpty) {
            return EmptyState(
              icon: Icons.auto_awesome_outlined,
              title: 'No looks yet',
              subtitle: 'Create your first look to see it here.',
              actionLabel: 'Create a look',
              onAction: () => context.push('/create/outfit'),
            );
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: done.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpace.md),
            itemBuilder: (_, i) {
              final g = done[i];
              return GestureDetector(
                onTap: () => context.push('/result/${g.id}'),
                child: RemoteImage(g.thumbnailUrl!, width: 120, height: 150),
              );
            },
          );
        },
      ),
    );
  }
}

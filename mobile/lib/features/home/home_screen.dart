import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../state/providers.dart';
import '../create/create_types.dart';

/// The five user-facing style categories, in display order. Labels are the
/// canonical app-side names; content itself comes entirely from the backend.
const _kCategories = <(String, String)>[
  ('outfit', 'Trending Outfit'),
  ('hair', 'Trending Hair'),
  ('glasses', 'Trending Glasses'),
  ('accessories', 'Trending Accessories'),
  ('ai_edit', 'AI Edit'),
];

/// All active trending styles, grouped by category. One fetch drives every Home
/// section, so the sections are always exactly the backend's categories.
final _homeTrendingProvider =
    FutureProvider.autoDispose<Map<String, List<TrendingItem>>>((ref) async {
  final items = await ref.read(contentRepoProvider).trending();
  final grouped = <String, List<TrendingItem>>{};
  for (final it in items) {
    (grouped[it.section] ??= []).add(it);
  }
  return grouped;
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
    // Robust name: first name from the profile, else derived from the email
    // local-part, else a friendly fallback — never null/empty/incorrect.
    final name = _displayName(me);

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
                  const StyloWordmark(size: 22),
                  const Spacer(),
                  CreditChip(
                      balance: me?.balance,
                      onTap: () => context.push('/credits')),
                ],
              ),
              const SizedBox(height: AppSpace.xl),
              Text(greeting, style: t.bodySmall),
              Text(name, style: t.headlineMedium),
              const SizedBox(height: AppSpace.xl),
              _ImproveCta(onTap: () => _openCreate(context)),
              const SizedBox(height: AppSpace.xl),
              Text('Quick create', style: t.titleLarge),
              const SizedBox(height: AppSpace.md),
              _QuickCreateRow(),
              const SizedBox(height: AppSpace.xl),
              // One section per backend category; empty categories are hidden.
              const _TrendingSections(),
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

  /// Resolves a friendly first name: the profile display name, else a name
  /// derived from the email local-part, else "Welcome back" (loading/unknown).
  static String _displayName(Me? me) {
    final dn = (me?.displayName ?? '').trim();
    if (dn.isNotEmpty) return dn.split(RegExp(r'\s+')).first;
    final email = (me?.email ?? '').trim();
    if (email.contains('@')) {
      final local = email.split('@').first.replaceAll(RegExp(r'[._-]+'), ' ').trim();
      if (local.isNotEmpty) {
        final w = local.split(' ').first;
        return w[0].toUpperCase() + w.substring(1);
      }
    }
    return 'Welcome back';
  }
}

class _ImproveCta extends StatelessWidget {
  final VoidCallback onTap;
  const _ImproveCta({required this.onTap});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onPrimary = scheme.onPrimary;
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
                  Text('PREMIUM STYLING',
                      style: TextStyle(
                          color: onPrimary.withValues(alpha: 0.65),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4)),
                  const SizedBox(height: 8),
                  Text('Improve my look',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: onPrimary)),
                  const SizedBox(height: 4),
                  Text('Upload your photo and try a new style in seconds.',
                      style: TextStyle(
                          color: onPrimary.withValues(alpha: 0.82),
                          fontSize: 13.5)),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.md),
            CircleAvatar(
              backgroundColor: onPrimary,
              child: Icon(Icons.arrow_forward, color: scheme.primary),
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

/// One horizontal strip per backend category (Outfit/Hair/Glasses/…). Empty
/// categories are hidden; when nothing is published at all, a single polished
/// empty state is shown instead of broken sections.
class _TrendingSections extends ConsumerWidget {
  const _TrendingSections();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_homeTrendingProvider);
    return async.when(
      loading: () => const SizedBox(height: 190, child: LoadingState()),
      error: (e, _) => SizedBox(
        height: 190,
        child: ErrorStateView(
            message: '$e', onRetry: () => ref.invalidate(_homeTrendingProvider)),
      ),
      data: (grouped) {
        final nonEmpty =
            _kCategories.where((c) => (grouped[c.$1] ?? const []).isNotEmpty).toList();
        if (nonEmpty.isEmpty) {
          return const SizedBox(
            height: 170,
            child: EmptyState(
              icon: Icons.trending_up,
              title: 'No trending styles yet',
              subtitle: 'Curated styles will appear here across categories soon.',
            ),
          );
        }
        // Featured "Trending" slider: admin-flagged items across categories.
        final featured = [
          for (final c in _kCategories) ...(grouped[c.$1] ?? const <TrendingItem>[])
        ].where((t) => t.isTrending).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (featured.isNotEmpty) ...[
              const SectionHeader(title: 'Trending'),
              _CategoryStrip(items: featured),
              const SizedBox(height: AppSpace.xl),
            ],
            for (final c in nonEmpty) ...[
              SectionHeader(title: c.$2),
              _CategoryStrip(items: grouped[c.$1]!),
              const SizedBox(height: AppSpace.xl),
            ],
          ],
        );
      },
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  final List<TrendingItem> items;
  const _CategoryStrip({required this.items});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 196,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpace.md),
        itemBuilder: (_, i) => _TrendingCard(item: items[i]),
      ),
    );
  }
}

/// A trending style card — image, title, an optional tag, and the credit price
/// (from the backend). Tapping opens the create flow bound to this style id so
/// the backend prices it authoritatively.
class _TrendingCard extends StatelessWidget {
  final TrendingItem item;
  const _TrendingCard({required this.item});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: () {
        final q = <String, String>{
          'styleId': item.id,
          if (item.presetKey != null) 'preset': item.presetKey!,
          if (item.creditPrice != null) 'price': '${item.creditPrice}',
        };
        final qs = q.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
        context.push('/create/${item.section}?$qs');
      },
      child: SizedBox(
        width: 144,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                RemoteImage(item.imageUrl, width: 144, height: 150),
                if (item.creditPrice != null)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: item.creditPrice == 0
                        ? const _MiniBadge(label: 'Free')
                        : _MiniBadge(label: '${item.creditPrice}', icon: Icons.auto_awesome),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(item.title,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
            if (item.tags.isNotEmpty)
              Text(item.tags.first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodySmall?.copyWith(color: AppColors.mutedDark, fontSize: 11.5)),
          ],
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  const _MiniBadge({required this.label, this.icon});
  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 11, color: gold), const SizedBox(width: 3)],
        Text(label,
            style: TextStyle(color: gold, fontWeight: FontWeight.w700, fontSize: 11)),
      ]),
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

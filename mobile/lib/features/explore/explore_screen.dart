import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../state/providers.dart';

// The five style categories plus the separate, free Poses tab. "Inspiration"
// is retired. Content and prices come entirely from the backend.
const _sections = [
  ('outfit', 'Outfits'),
  ('hair', 'Hair'),
  ('glasses', 'Glasses'),
  ('accessories', 'Accessories'),
  ('ai_edit', 'AI Edits'),
  ('poses', 'Poses'),
];

final _exploreProvider = FutureProvider.autoDispose
    .family<List<TrendingItem>, String>((ref, section) async {
  return ref.read(contentRepoProvider).trending(section: section);
});

final _posesProvider =
    FutureProvider.autoDispose<List<Pose>>((ref) async {
  return ref.read(contentRepoProvider).poses();
});

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});
  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  String _section = 'outfit';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.gutter, AppSpace.md, AppSpace.gutter, AppSpace.sm),
              child: Text('Explore',
                  style: Theme.of(context).textTheme.headlineMedium),
            ),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
                itemCount: _sections.length,
                separatorBuilder: (_, __) => const SizedBox(width: AppSpace.sm),
                itemBuilder: (_, i) {
                  final s = _sections[i];
                  return CategoryChip(
                    label: s.$2,
                    selected: _section == s.$1,
                    onTap: () => setState(() => _section = s.$1),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpace.md),
            Expanded(
              child: _section == 'poses' ? _posesBody() : _stylesBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stylesBody() {
    final async = ref.watch(_exploreProvider(_section));
    return async.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorStateView(
          message: '$e',
          onRetry: () => ref.invalidate(_exploreProvider(_section))),
      data: (items) {
        if (items.isEmpty) {
          return EmptyState(
            icon: Icons.explore_outlined,
            title: 'Nothing here yet',
            subtitle: 'Trending ${_labelFor(_section)} will appear here soon.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_exploreProvider(_section)),
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter, 0, AppSpace.gutter, 90),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppSpace.md,
              mainAxisSpacing: AppSpace.md,
              childAspectRatio: 0.72,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) => _ExploreCard(item: items[i]),
          ),
        );
      },
    );
  }

  Widget _posesBody() {
    final async = ref.watch(_posesProvider);
    return async.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorStateView(
          message: '$e', onRetry: () => ref.invalidate(_posesProvider)),
      data: (poses) {
        if (poses.isEmpty) {
          return const EmptyState(
            icon: Icons.accessibility_new_outlined,
            title: 'No poses yet',
            subtitle: 'Free pose ideas will appear here soon.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_posesProvider),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter, 0, AppSpace.gutter, 90),
            itemCount: poses.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpace.md),
            itemBuilder: (_, i) => _PoseCard(pose: poses[i]),
          ),
        );
      },
    );
  }

  String _labelFor(String s) =>
      _sections.firstWhere((e) => e.$1 == s, orElse: () => (s, s)).$2.toLowerCase();
}

class _ExploreCard extends StatelessWidget {
  final TrendingItem item;
  const _ExploreCard({required this.item});
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
        final qs =
            q.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
        context.push('/create/${item.section}?$qs');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                    child: RemoteImage(item.imageUrl, width: double.infinity)),
                if (item.creditPrice != null)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _PriceTag(price: item.creditPrice!),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.titleMedium),
          if (item.tags.isNotEmpty)
            Text(item.tags.take(2).join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.bodySmall)
          else if (item.subtitle != null)
            Text(item.subtitle!,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
        ],
      ),
    );
  }
}

class _PriceTag extends StatelessWidget {
  final int price;
  const _PriceTag({required this.price});
  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: price == 0
          ? Text('Free',
              style:
                  TextStyle(color: gold, fontWeight: FontWeight.w700, fontSize: 11))
          : Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.auto_awesome, size: 11, color: gold),
              const SizedBox(width: 3),
              Text('$price',
                  style: TextStyle(
                      color: gold, fontWeight: FontWeight.w700, fontSize: 11)),
            ]),
    );
  }
}

/// A free pose card — image + name + short instruction so the user understands
/// the pose before selecting it. Never shows a credit price.
class _PoseCard extends StatelessWidget {
  final Pose pose;
  const _PoseCard({required this.pose});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: () {
        final q = <String, String>{
          'poseId': pose.id,
          if (pose.creditPrice != null) 'price': '${pose.creditPrice}',
        };
        final qs = q.entries
            .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
            .join('&');
        context.push('/create/pose?$qs');
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RemoteImage(pose.imageUrl, width: 92, height: 92),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(pose.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.titleMedium),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .secondary
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                          // Free by default; shows the credit price if the admin set one.
                          child: Text(
                              (pose.creditPrice == null || pose.creditPrice == 0)
                                  ? 'Free'
                                  : '${pose.creditPrice} cr',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.secondary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11)),
                        ),
                      ],
                    ),
                    if (pose.description != null) ...[
                      const SizedBox(height: 4),
                      Text(pose.description!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodySmall),
                    ],
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

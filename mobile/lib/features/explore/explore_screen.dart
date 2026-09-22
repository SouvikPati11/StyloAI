import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../state/providers.dart';

const _sections = [
  ('outfit', 'Outfits'),
  ('hair', 'Hair'),
  ('glasses', 'Glasses'),
  ('ai_edit', 'AI Edits'),
  ('pose', 'Poses'),
  ('inspiration', 'Inspiration'),
];

final _exploreProvider = FutureProvider.autoDispose
    .family<List<TrendingItem>, String>((ref, section) async {
  return ref.read(contentRepoProvider).trending(section: section);
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
    final async = ref.watch(_exploreProvider(_section));
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
              child: async.when(
                loading: () => const LoadingState(),
                error: (e, _) => ErrorStateView(
                    message: '$e',
                    onRetry: () => ref.invalidate(_exploreProvider(_section))),
                data: (items) {
                  if (items.isEmpty) {
                    return EmptyState(
                      icon: Icons.explore_outlined,
                      title: 'Nothing here yet',
                      subtitle:
                          'Trending ${_labelFor(_section)} will appear here soon.',
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(_exploreProvider(_section)),
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpace.gutter, 0, AppSpace.gutter, 90),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _labelFor(String s) =>
      _sections.firstWhere((e) => e.$1 == s).$2.toLowerCase();
}

class _ExploreCard extends StatelessWidget {
  final TrendingItem item;
  const _ExploreCard({required this.item});
  @override
  Widget build(BuildContext context) {
    final canTry = item.section != 'inspiration';
    return GestureDetector(
      onTap: canTry ? () => context.push('/create/${item.section}') : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: RemoteImage(item.imageUrl, width: double.infinity)),
          const SizedBox(height: 6),
          Text(item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium),
          if (item.subtitle != null)
            Text(item.subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

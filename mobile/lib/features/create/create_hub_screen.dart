import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../state/providers.dart';
import 'create_types.dart';

class CreateHubScreen extends ConsumerWidget {
  const CreateHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.gutter, AppSpace.md, AppSpace.gutter, 90),
          children: [
            Text('Create', style: t.headlineMedium),
            const SizedBox(height: 4),
            Text(
                'Upload your photo, choose what to change, and generate a new look.',
                style: t.bodyMedium?.copyWith(color: AppColors.inkSoft)),
            const SizedBox(height: AppSpace.xl),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: AppSpace.md,
              mainAxisSpacing: AppSpace.md,
              childAspectRatio: 1.15,
              children: [
                for (final c in kCreateTypes)
                  _CreateTile(
                    type: c,
                    enabled: config.maybeWhen(
                      data: (cfg) => cfg.isEnabled(c.type),
                      orElse: () => true,
                    ),
                    cost: config.maybeWhen(
                        data: (cfg) => cfg.costFor(c.type), orElse: () => null),
                    onTap: () => context.push('/create/${c.type}'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateTile extends StatelessWidget {
  final CreateType type;
  final bool enabled;
  final int? cost;
  final VoidCallback onTap;
  const _CreateTile(
      {required this.type,
      required this.enabled,
      required this.cost,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: enabled ? onTap : null,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(type.icon, size: 28, color: scheme.primary),
                const Spacer(),
                Text(type.label,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(type.tagline,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: AppSpace.sm),
                Row(
                  children: [
                    if (cost != null) CostBadge(cost: cost!),
                    const Spacer(),
                    if (type.supportsReference)
                      const Icon(Icons.upload_outlined,
                          size: 16, color: AppColors.muted),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

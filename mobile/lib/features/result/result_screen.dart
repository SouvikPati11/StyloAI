import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../state/providers.dart';

final _generationProvider =
    FutureProvider.autoDispose.family<Generation, String>((ref, id) async {
  return ref.read(generationRepoProvider).get(id);
});

/// Result of a generation — the new look, with save/regenerate/download actions.
class ResultScreen extends ConsumerStatefulWidget {
  final String generationId;
  const ResultScreen({super.key, required this.generationId});
  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  bool _saving = false;
  bool _saved = false;

  Future<void> _save(String imageId) async {
    setState(() => _saving = true);
    try {
      await ref.read(looksRepoProvider).save(imageId);
      setState(() => _saved = true);
      if (mounted) showSnack(context, 'Saved to your looks');
    } catch (_) {
      if (mounted) showSnack(context, 'Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_generationProvider(widget.generationId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your new look'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () => context.go('/home'),
          ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingState(message: 'Loading your look…'),
        error: (e, _) => ErrorStateView(
            message: '$e',
            onRetry: () =>
                ref.invalidate(_generationProvider(widget.generationId))),
        data: (gen) {
          if (gen.images.isEmpty) {
            return EmptyState(
              icon: Icons.image_outlined,
              title: 'No image available',
              subtitle: gen.status == GenStatus.refunded
                  ? 'This generation failed and your credits were refunded.'
                  : 'This look has no image.',
              actionLabel: 'Back to create',
              onAction: () => context.go('/home'),
            );
          }
          final image = gen.images.first;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter, AppSpace.md, AppSpace.gutter, 40),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.md),
                child:
                    RemoteImage(image.url, width: double.infinity, height: 460),
              ),
              const SizedBox(height: AppSpace.lg),
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      label: _saved ? 'Saved' : 'Save look',
                      icon: _saved ? Icons.check : Icons.bookmark_border,
                      loading: _saving,
                      onPressed: _saved ? null : () => _save(image.id),
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: SecondaryButton(
                      label: 'New look',
                      icon: Icons.refresh,
                      onPressed: () =>
                          context.pushReplacement('/create/${gen.type}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.xl),
              Container(
                padding: const EdgeInsets.all(AppSpace.md),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_outlined,
                        size: 18, color: AppColors.muted),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Text(
                        'We aim to keep your identity as accurate as the technology allows and only change your ${gen.type}.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../state/providers.dart';

final _styleProfileProvider =
    FutureProvider.autoDispose<StyleProfile>((ref) async {
  return ref.read(styleProfileRepoProvider).get();
});

const _styleOptions = [
  'casual',
  'formal',
  'smart casual',
  'streetwear',
  'minimal',
  'luxury',
  'traditional'
];
const _colorOptions = [
  'black',
  'white',
  'neutral',
  'earth tones',
  'bold',
  'pastel',
  'monochrome'
];
const _occasionOptions = [
  'everyday',
  'work',
  'party',
  'travel',
  'date',
  'formal event'
];

/// Personal Style Profile (§5). User-provided preferences drive recommendations.
class StyleProfileScreen extends ConsumerStatefulWidget {
  const StyleProfileScreen({super.key});
  @override
  ConsumerState<StyleProfileScreen> createState() => _StyleProfileScreenState();
}

class _StyleProfileScreenState extends ConsumerState<StyleProfileScreen> {
  final _styles = <String>{};
  final _colors = <String>{};
  final _occasions = <String>{};
  bool _loaded = false;
  bool _saving = false;

  void _hydrate(StyleProfile p) {
    if (_loaded) return;
    _styles.addAll(p.preferredStyles);
    _colors.addAll(p.favoriteColors);
    _occasions.addAll(p.occasionPreferences);
    _loaded = true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(styleProfileRepoProvider).put(StyleProfile(
            preferredStyles: _styles.toList(),
            favoriteColors: _colors.toList(),
            styleInterests: const [],
            hairPreferences: const [],
            glassesPreferences: const [],
            occasionPreferences: _occasions.toList(),
          ));
      if (mounted) showSnack(context, 'Preferences saved');
    } catch (_) {
      if (mounted) showSnack(context, 'Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_styleProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Style preferences')),
      body: async.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorStateView(
            message: '$e',
            onRetry: () => ref.invalidate(_styleProfileProvider)),
        data: (p) {
          _hydrate(p);
          return ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter, AppSpace.md, AppSpace.gutter, 40),
            children: [
              Text(
                  'Tell us what you like and we’ll personalize your recommendations.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.inkSoft)),
              const SizedBox(height: AppSpace.xl),
              _ChipGroup(
                  title: 'Preferred styles',
                  options: _styleOptions,
                  selected: _styles,
                  onChanged: () => setState(() {})),
              _ChipGroup(
                  title: 'Favorite colors',
                  options: _colorOptions,
                  selected: _colors,
                  onChanged: () => setState(() {})),
              _ChipGroup(
                  title: 'Occasions',
                  options: _occasionOptions,
                  selected: _occasions,
                  onChanged: () => setState(() {})),
              const SizedBox(height: AppSpace.xl),
              PrimaryButton(
                  label: 'Save preferences',
                  loading: _saving,
                  onPressed: _save),
            ],
          );
        },
      ),
    );
  }
}

class _ChipGroup extends StatelessWidget {
  final String title;
  final List<String> options;
  final Set<String> selected;
  final VoidCallback onChanged;
  const _ChipGroup(
      {required this.title,
      required this.options,
      required this.selected,
      required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.sm, top: AppSpace.sm),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            for (final o in options)
              CategoryChip(
                label: o,
                selected: selected.contains(o),
                onTap: () {
                  selected.contains(o) ? selected.remove(o) : selected.add(o);
                  onChanged();
                },
              ),
          ],
        ),
        const SizedBox(height: AppSpace.lg),
      ],
    );
  }
}

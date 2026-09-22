import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../core/api_exception.dart';
import '../../data/models.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../state/providers.dart';
import 'create_types.dart';

/// The generation flow for one Create type. Steps: choose your photo → choose a
/// style (explore preset) or upload a reference → review cost → generate. On
/// submit it uploads inputs, calls the backend, and polls until the async job
/// finishes, then opens the result. All states are handled explicitly.
class CreateFlowScreen extends ConsumerStatefulWidget {
  final String type;
  const CreateFlowScreen({super.key, required this.type});
  @override
  ConsumerState<CreateFlowScreen> createState() => _CreateFlowScreenState();
}

enum _Mode { explore, upload }

class _CreateFlowScreenState extends ConsumerState<CreateFlowScreen> {
  late final CreateType _ct = createTypeByKey(widget.type);
  final _picker = ImagePicker();

  File? _userPhoto;
  File? _referenceImage;
  _Mode _mode = _Mode.explore;
  String? _presetKey;

  bool _submitting = false;
  String _progressMessage = '';

  @override
  void initState() {
    super.initState();
    if (!_ct.supportsReference) _mode = _Mode.explore;
  }

  Future<File?> _pick(ImageSource source) async {
    final x = await _picker.pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 92,
    );
    return x == null ? null : File(x.path);
  }

  Future<void> _pickUserPhoto() async {
    final f = await _showSourceSheet();
    if (f != null) setState(() => _userPhoto = f);
  }

  Future<void> _pickReference() async {
    final f = await _showSourceSheet();
    if (f != null) setState(() => _referenceImage = f);
  }

  Future<File?> _showSourceSheet() async {
    return showModalBottomSheet<File?>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () async {
                final f = await _pick(ImageSource.gallery);
                if (ctx.mounted) Navigator.pop(ctx, f);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () async {
                final f = await _pick(ImageSource.camera);
                if (ctx.mounted) Navigator.pop(ctx, f);
              },
            ),
          ],
        ),
      ),
    );
  }

  bool get _canGenerate {
    if (_userPhoto == null) return false;
    if (_mode == _Mode.upload) return _referenceImage != null;
    return _presetKey != null;
  }

  Future<void> _generate(int? cost) async {
    final balance = ref.read(authControllerProvider).me?.balance ?? 0;
    if (cost != null && balance < cost) {
      _showInsufficient(cost, balance);
      return;
    }
    setState(() {
      _submitting = true;
      _progressMessage = 'Uploading your photo…';
    });
    try {
      final uploads = ref.read(uploadRepoProvider);
      final userKey = await uploads.uploadImage(_userPhoto!, 'user_photo');

      String? referenceKey;
      if (_mode == _Mode.upload && _referenceImage != null) {
        setState(() => _progressMessage = 'Uploading your reference…');
        referenceKey =
            await uploads.uploadImage(_referenceImage!, _ct.referencePurpose);
      }

      setState(() => _progressMessage = 'Creating your look…');
      final gen = await ref.read(generationRepoProvider).submit(
            type: _ct.type,
            mode: _mode == _Mode.upload ? 'reference_upload' : 'explore',
            userPhotoKey: userKey,
            presetKey: _mode == _Mode.explore ? _presetKey : null,
            referenceKey: referenceKey,
            idempotencyKey: const Uuid().v4(),
          );

      final finished = await _poll(gen.id);
      await ref.read(authControllerProvider.notifier).refreshMe();

      if (!mounted) return;
      if (finished.status == GenStatus.succeeded) {
        context.pushReplacement('/result/${finished.id}');
      } else {
        setState(() => _submitting = false);
        _showFailed(finished);
      }
    } on ApiException catch (e) {
      setState(() => _submitting = false);
      if (e.isInsufficientCredits) {
        _showInsufficient(
          (e.details?['required'] as int?) ?? (cost ?? 0),
          (e.details?['balance'] as int?) ?? balance,
        );
      } else if (e.isRateLimited) {
        showSnack(context,
            'You’re creating looks quickly. Please wait a moment and try again.');
      } else {
        showSnack(context, e.message);
      }
    } catch (_) {
      setState(() => _submitting = false);
      showSnack(context, 'Something went wrong. Please try again.');
    }
  }

  /// Polls the generation until it reaches a terminal state (or times out).
  Future<Generation> _poll(String id) async {
    final repo = ref.read(generationRepoProvider);
    const maxAttempts = 40; // ~100s at 2.5s
    final messages = [
      'Analysing your photo…',
      'Preserving your identity…',
      'Styling your new look…',
      'Adding the finishing touches…',
    ];
    for (var i = 0; i < maxAttempts; i++) {
      await Future.delayed(const Duration(milliseconds: 2500));
      if (!mounted) return repo.get(id);
      setState(() => _progressMessage = messages[i % messages.length]);
      final g = await repo.get(id);
      if (g.isTerminal) return g;
    }
    return repo.get(id);
  }

  void _showInsufficient(int required, int balance) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Not enough credits',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpace.sm),
            Text(
                'This needs $required credits and you have $balance. Top up to keep creating.',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpace.xl),
            PrimaryButton(
              label: 'Get credits',
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/credits');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFailed(Generation g) {
    final refunded = g.status == GenStatus.refunded;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 36),
            const SizedBox(height: AppSpace.md),
            Text('We couldn’t create that look',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpace.sm),
            Text(
              refunded
                  ? 'Your credits were refunded. Try again with a clear, well-lit photo.'
                  : 'Please try a different photo.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpace.xl),
            PrimaryButton(
                label: 'Try again', onPressed: () => Navigator.pop(ctx)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final cost =
        config.maybeWhen(data: (c) => c.costFor(_ct.type), orElse: () => null);
    final categories = config.maybeWhen(
      data: (c) => c.sections[_ct.type] ?? const <Category>[],
      orElse: () => const <Category>[],
    );

    return Scaffold(
      appBar: AppBar(title: Text(_ct.label)),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter, AppSpace.sm, AppSpace.gutter, 120),
            children: [
              const _StepLabel(number: 1, text: 'Your photo'),
              const SizedBox(height: AppSpace.sm),
              _PhotoPicker(file: _userPhoto, onTap: _pickUserPhoto),
              const SizedBox(height: AppSpace.xl),
              const _StepLabel(number: 2, text: 'Choose a style'),
              const SizedBox(height: AppSpace.sm),
              if (_ct.supportsReference) _modeToggle(),
              const SizedBox(height: AppSpace.md),
              if (_mode == _Mode.explore)
                _presetGrid(categories)
              else
                _referencePicker(),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _bottomBar(cost),
          ),
          if (_submitting) _processingOverlay(),
        ],
      ),
    );
  }

  Widget _modeToggle() {
    return Row(
      children: [
        Expanded(
          child: _ToggleButton(
            label: _ct.exploreTitle,
            icon: Icons.grid_view,
            selected: _mode == _Mode.explore,
            onTap: () => setState(() => _mode = _Mode.explore),
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: _ToggleButton(
            label: _ct.uploadTitle,
            icon: Icons.upload_outlined,
            selected: _mode == _Mode.upload,
            onTap: () => setState(() => _mode = _Mode.upload),
          ),
        ),
      ],
    );
  }

  Widget _presetGrid(List<Category> categories) {
    if (categories.isEmpty) {
      return const EmptyState(
        icon: Icons.style_outlined,
        title: 'No styles available',
        subtitle: 'Styles are managed by our team and will appear here soon.',
      );
    }
    return Wrap(
      spacing: AppSpace.sm,
      runSpacing: AppSpace.sm,
      children: [
        for (final c in categories)
          CategoryChip(
            label: c.label,
            selected: _presetKey == c.key,
            onTap: () => setState(() => _presetKey = c.key),
          ),
      ],
    );
  }

  Widget _referencePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Upload a reference image and we’ll apply its style to you.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpace.md),
        _PhotoPicker(
          file: _referenceImage,
          onTap: _pickReference,
          hint: 'Add reference',
          icon: Icons.add_photo_alternate_outlined,
          height: 200,
        ),
      ],
    );
  }

  Widget _bottomBar(int? cost) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.gutter, AppSpace.md, AppSpace.gutter, AppSpace.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (cost != null) ...[
              CostBadge(cost: cost),
              const SizedBox(width: AppSpace.md),
            ],
            Expanded(
              child: PrimaryButton(
                label: 'Generate',
                icon: Icons.auto_awesome,
                onPressed: _canGenerate ? () => _generate(cost) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _processingOverlay() {
    return Positioned.fill(
      child: Container(
        color:
            Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.96),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _PulseIcon(),
                const SizedBox(height: AppSpace.xl),
                Text('Creating your look',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpace.sm),
                Text(_progressMessage,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: AppSpace.lg),
                Text('Keeping you recognizably you.',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  final int number;
  final String text;
  const _StepLabel({required this.number, required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text('$number',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
        ),
        const SizedBox(width: AppSpace.sm),
        Text(text, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  final File? file;
  final VoidCallback onTap;
  final String hint;
  final IconData icon;
  final double height;
  const _PhotoPicker({
    required this.file,
    required this.onTap,
    this.hint = 'Add your photo',
    this.icon = Icons.add_a_photo_outlined,
    this.height = 320,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: file != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(file!, fit: BoxFit.cover),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      radius: 18,
                      child: IconButton(
                        icon: const Icon(Icons.edit,
                            size: 16, color: Colors.white),
                        onPressed: onTap,
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 36, color: AppColors.muted),
                  const SizedBox(height: AppSpace.sm),
                  Text(hint, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleButton(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.08)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(
              color:
                  selected ? scheme.primary : Theme.of(context).dividerColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18, color: selected ? scheme.primary : AppColors.muted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: selected ? scheme.primary : scheme.onSurface)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulseIcon extends StatefulWidget {
  const _PulseIcon();
  @override
  State<_PulseIcon> createState() => _PulseIconState();
}

class _PulseIconState extends State<_PulseIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))
        ..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ScaleTransition(
      scale: Tween(begin: 0.9, end: 1.1)
          .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle),
        child: Icon(Icons.auto_awesome, size: 38, color: scheme.primary),
      ),
    );
  }
}

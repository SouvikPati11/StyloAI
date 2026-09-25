import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';

/// One editorial onboarding slide: an eyebrow, a two-part headline (the accent
/// line is emphasised in gold), a supporting line, a central icon and a set of
/// pill tags. Copy and structure are deliberate — this is the first premium
/// impression of StyloAI.
class _Slide {
  final String eyebrow;
  final String headline;
  final String accent;
  final String body;
  final IconData icon;
  final List<String> tags;
  const _Slide({
    required this.eyebrow,
    required this.headline,
    required this.accent,
    required this.body,
    required this.icon,
    required this.tags,
  });
}

const _slides = <_Slide>[
  _Slide(
    eyebrow: 'YOUR PERSONAL STYLE STUDIO',
    headline: 'Discover your style.',
    accent: 'Styled around you.',
    body:
        'Upload one photo and explore polished looks that keep you recognizably you.',
    icon: Icons.auto_awesome_outlined,
    tags: ['Outfits', 'Hair', 'Glasses'],
  ),
  _Slide(
    eyebrow: 'EDIT WITH INTENTION',
    headline: 'Try the look.',
    accent: 'Keep what feels right.',
    body:
        'Experiment with outfits, hairstyles, glasses and accessories without changing your identity.',
    icon: Icons.checkroom_outlined,
    tags: ['Outfit', 'Hair', 'Accessories'],
  ),
  _Slide(
    eyebrow: 'AI CREATION',
    headline: 'Create something new.',
    accent: 'In seconds.',
    body:
        'Turn your photo into refined AI looks with a premium, editorial finish.',
    icon: Icons.camera_alt_outlined,
    tags: ['Editorial', 'Studio', 'Cinematic'],
  ),
  _Slide(
    eyebrow: 'THE STYLE FEED',
    headline: 'Stay ahead of trends.',
    accent: 'Your next look is waiting.',
    body:
        'Discover curated styles and fresh inspiration as the StyloAI library grows.',
    icon: Icons.trending_up_outlined,
    tags: ['Trending', 'Inspiration', 'New looks'],
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goToSignIn() => context.go('/sign-in');

  void _next() {
    if (_page >= _slides.length - 1) {
      _goToSignIn();
    } else {
      _controller.nextPage(
          duration: AppDurations.med, curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
          child: Column(
            children: [
              const SizedBox(height: AppSpace.sm),
              // Brand lockup + always-visible, subdued Skip.
              Row(
                children: [
                  const BrandLogo(size: 30, radius: 9),
                  const SizedBox(width: AppSpace.sm),
                  const StyloWordmark(size: 18),
                  const Spacer(),
                  TextButton(
                    onPressed: _goToSignIn,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.mutedDark,
                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Skip'),
                  ),
                ],
              ),
              // The slides. A LayoutBuilder + scroll view keeps every element
              // visible from small phones to tall aspect ratios (no overflow).
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              _ProgressBar(count: _slides.length, index: _page),
              const SizedBox(height: AppSpace.xl),
              _OnboardingCta(
                label: isLast ? 'Get started' : 'Continue',
                onPressed: _next,
              ),
              const SizedBox(height: AppSpace.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  final _Slide slide;
  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, c) {
        // Scale the hero to the available space so it never crowds the copy.
        final visual =
            (c.maxHeight * 0.34).clamp(150.0, 260.0).toDouble();
        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: visual, child: _Hero(icon: slide.icon)),
                const SizedBox(height: AppSpace.xxl),
                Text(slide.eyebrow,
                    textAlign: TextAlign.center,
                    style: t.bodySmall?.copyWith(
                      color: scheme.secondary,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: AppSpace.md),
                // Headline in ivory, accent line in gold — gold is emphasis only.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Column(
                    children: [
                      Text(slide.headline,
                          textAlign: TextAlign.center,
                          style: t.displaySmall ?? t.headlineMedium),
                      Text(slide.accent,
                          textAlign: TextAlign.center,
                          style: (t.displaySmall ?? t.headlineMedium)
                              ?.copyWith(color: scheme.secondary)),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Text(slide.body,
                      textAlign: TextAlign.center,
                      style: t.bodyLarge
                          ?.copyWith(color: AppColors.inkSoftDark, height: 1.55)),
                ),
                const SizedBox(height: AppSpace.xl),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.sm,
                  children:
                      slide.tags.map((tag) => _TagChip(label: tag)).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Large premium visual container — a soft navy ground, a stronger inner ring,
/// a central style icon, and subtle decorative sparkles. Editorial, not
/// illustrative.
class _Hero extends StatelessWidget {
  final IconData icon;
  const _Hero({required this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final gold = scheme.secondary;
    return LayoutBuilder(builder: (context, c) {
      final side = c.maxHeight.clamp(150.0, 260.0).toDouble();
      final ring = side * 0.62;
      final disc = side * 0.42;
      return Center(
        child: SizedBox(
          width: side,
          height: side,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer soft ground with a hairline gold border.
              Container(
                width: side,
                height: side,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: gold.withValues(alpha: 0.05),
                  border: Border.all(color: gold.withValues(alpha: 0.14)),
                ),
              ),
              Container(
                width: ring,
                height: ring,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: gold.withValues(alpha: 0.08),
                ),
              ),
              Container(
                width: disc,
                height: disc,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: gold.withValues(alpha: 0.16),
                ),
                child: Icon(icon, size: disc * 0.5, color: gold),
              ),
              // Subtle decorative sparkles.
              Positioned(
                  top: side * 0.14,
                  right: side * 0.2,
                  child: Icon(Icons.auto_awesome,
                      size: 16, color: gold.withValues(alpha: 0.7))),
              Positioned(
                  bottom: side * 0.18,
                  left: side * 0.16,
                  child: Icon(Icons.auto_awesome,
                      size: 11, color: gold.withValues(alpha: 0.5))),
              Positioned(
                  bottom: side * 0.3,
                  right: side * 0.14,
                  child: Icon(Icons.star,
                      size: 8, color: gold.withValues(alpha: 0.45))),
            ],
          ),
        ),
      );
    });
  }
}

/// Small pill chip — dark navy surface, thin gold border, muted ivory text.
class _TagChip extends StatelessWidget {
  final String label;
  const _TagChip({required this.label});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: scheme.secondary.withValues(alpha: 0.35)),
      ),
      child: Text(label,
          style: const TextStyle(
              color: AppColors.inkSoftDark,
              fontSize: 12.5,
              fontWeight: FontWeight.w600)),
    );
  }
}

/// Animated progress indicator — the active segment grows and fills gold.
class _ProgressBar extends StatelessWidget {
  final int count;
  final int index;
  const _ProgressBar({required this.count, required this.index});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: AppDurations.med,
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 26 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: active
                ? scheme.secondary
                : scheme.secondary.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
        );
      }),
    );
  }
}

/// Full-width primary CTA with a trailing arrow (Continue → / Get started →).
class _OnboardingCta extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _OnboardingCta({required this.label, required this.onPressed});
  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward, size: 20),
        ],
      ),
    );
  }
}

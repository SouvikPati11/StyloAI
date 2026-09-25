import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';

class _Slide {
  final IconData icon;
  final String title;
  final String body;
  const _Slide(this.icon, this.title, this.body);
}

const _slides = [
  _Slide(Icons.auto_awesome, 'Discover your style',
      'Upload a photo and explore new looks made just for you — while you stay recognizably you.'),
  _Slide(Icons.checkroom, 'Try outfits, hair & glasses',
      'Browse curated styles or upload a reference image, and preview it on yourself in seconds.'),
  _Slide(Icons.camera_alt_outlined, 'Create trending AI looks',
      'Turn your photo into cinematic, editorial and studio-quality styles.'),
  _Slide(Icons.trending_up, 'Stay ahead of the trends',
      'Explore what’s trending in fashion and AI photo styling, refreshed for you.'),
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

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isLast = _page == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.xl, vertical: AppSpace.sm),
          child: Column(
            children: [
              // Skip stays consistent with the app's accent text buttons.
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.go('/sign-in'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                  child: const Text('Skip'),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) {
                    final s = _slides[i];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Layered accent disc — soft ground with a stronger
                        // inner ring, echoing the brand mark on splash/sign-in.
                        Container(
                          width: 116,
                          height: 116,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.06),
                            shape: BoxShape.circle,
                          ),
                          child: Container(
                            width: 84,
                            height: 84,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child:
                                Icon(s.icon, size: 38, color: scheme.primary),
                          ),
                        ),
                        const SizedBox(height: AppSpace.xxl),
                        // Fraunces display face (headlineMedium) — consistent
                        // with the rest of the app's editorial headings.
                        Text(s.title,
                            textAlign: TextAlign.center,
                            style: t.headlineMedium),
                        const SizedBox(height: AppSpace.md),
                        Text(s.body,
                            textAlign: TextAlign.center,
                            style: t.bodyLarge
                                ?.copyWith(color: AppColors.inkSoft)),
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _slides.length,
                  (i) => AnimatedContainer(
                    duration: AppDurations.fast,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? scheme.primary
                          : scheme.primary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.xl),
              PrimaryButton(
                label: isLast ? 'Get started' : 'Next',
                onPressed: () {
                  if (isLast) {
                    context.go('/sign-in');
                  } else {
                    _controller.nextPage(
                        duration: AppDurations.med, curve: Curves.easeOut);
                  }
                },
              ),
              const SizedBox(height: AppSpace.lg),
            ],
          ),
        ),
      ),
    );
  }
}

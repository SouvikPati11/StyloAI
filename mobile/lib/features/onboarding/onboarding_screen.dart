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
          padding: const EdgeInsets.all(AppSpace.gutter),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.go('/sign-in'),
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
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(s.icon, size: 42, color: scheme.primary),
                        ),
                        const SizedBox(height: AppSpace.xxl),
                        Text(s.title,
                            textAlign: TextAlign.center,
                            style: t.displaySmall ?? t.headlineMedium),
                        const SizedBox(height: AppSpace.md),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.lg),
                          child: Text(s.body,
                              textAlign: TextAlign.center,
                              style: t.bodyLarge
                                  ?.copyWith(color: AppColors.inkSoft)),
                        ),
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
                          : Theme.of(context).dividerColor,
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
              const SizedBox(height: AppSpace.sm),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:styloai/app/theme.dart';
import 'package:styloai/features/onboarding/onboarding_screen.dart';

/// The redesigned onboarding is the first premium impression of StyloAI. These
/// tests lock in the editorial structure (eyebrow + headline + tags), the CTA
/// label contract (Continue → until the last slide, then Get started), and that
/// advancing through the deck works without overflowing on a small screen.
void main() {
  Widget harness() => MaterialApp(
        theme: AppTheme.dark(),
        home: const OnboardingScreen(),
      );

  testWidgets('renders the first slide with eyebrow, headline and tags',
      (tester) async {
    await tester.pumpWidget(harness());
    expect(find.text('YOUR PERSONAL STYLE STUDIO'), findsOneWidget);
    expect(find.text('Discover your style.'), findsOneWidget);
    expect(find.text('Styled around you.'), findsOneWidget);
    // Tag chips.
    expect(find.text('Outfits'), findsOneWidget);
    expect(find.text('Hair'), findsOneWidget);
    // First three slides advance with "Continue".
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Get started'), findsNothing);
  });

  testWidgets('Continue advances to the next slide', (tester) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('EDIT WITH INTENTION'), findsOneWidget);
    expect(find.text('Try the look.'), findsOneWidget);
  });

  testWidgets('final slide shows the Get started CTA', (tester) async {
    await tester.pumpWidget(harness());
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }
    expect(find.text('THE STYLE FEED'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
  });

  testWidgets('does not overflow on a small phone viewport', (tester) async {
    tester.view.physicalSize = const Size(360 * 2, 640 * 2); // small Android
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

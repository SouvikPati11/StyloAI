import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tokens.dart';

/// Shared, reusable UI components — the visual vocabulary every screen speaks.

/// The StyloAI app logo (the real brand asset), rounded and never distorted.
class BrandLogo extends StatelessWidget {
  final double size;
  final double radius;
  const BrandLogo({super.key, this.size = 96, this.radius = AppRadii.lg});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        'assets/brand/logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

/// The "StyloAI" wordmark — "Stylo" in ink/ivory, "AI" in champagne gold, echoing
/// the logo. [onDark] switches the base color for dark canvases.
class StyloWordmark extends StatelessWidget {
  final double size;
  final bool onDark;
  const StyloWordmark({super.key, this.size = 26, this.onDark = false});
  @override
  Widget build(BuildContext context) {
    final base = onDark ? AppColors.inkDark : AppColors.ink;
    final gold = onDark ? AppColors.accentDark : AppColors.accent;
    TextStyle s(Color c) => GoogleFonts.fraunces(
        fontSize: size, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: c);
    return Text.rich(TextSpan(children: [
      TextSpan(text: 'Stylo', style: s(base)),
      TextSpan(text: 'AI', style: s(gold)),
    ]));
  }
}

/// Primary CTA.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  /// Optional leading widget (e.g. a brand glyph) shown before the label.
  final Widget? leading;
  const PrimaryButton(
      {super.key,
      required this.label,
      this.onPressed,
      this.loading = false,
      this.icon,
      this.leading});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2.4, color: Colors.white))
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 10)],
                if (icon != null && leading == null) ...[
                  Icon(icon, size: 20),
                  const SizedBox(width: 8)
                ],
                Text(label),
              ],
            ),
    );
  }
}

/// A small white circular badge with a Google "G" — a tasteful, asset-free
/// brand mark for the "Continue with Google" button that stays consistent with
/// the design system (no third-party image assets).
class GoogleGlyph extends StatelessWidget {
  const GoogleGlyph({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4), // Google blue
          fontWeight: FontWeight.w700,
          fontSize: 15,
          height: 1.0,
        ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  const SecondaryButton(
      {super.key, required this.label, this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
          Text(label),
        ],
      ),
    );
  }
}

/// Credit balance chip shown in headers.
class CreditChip extends StatelessWidget {
  final int? balance;
  final VoidCallback? onTap;
  const CreditChip({super.key, required this.balance, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Credits are the product's "currency" — rendered in the metallic gold
    // accent so value reads as premium, distinct from navy primary actions.
    final gold = isDark ? AppColors.accentDark : AppColors.accent;
    return Material(
      color: isDark ? AppColors.accentSoftDark : AppColors.accentSoft,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, size: 15, color: gold),
              const SizedBox(width: 6),
              Text(balance == null ? '—' : '$balance',
                  style: TextStyle(
                      color: gold, fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cost badge that renders a server-provided credit cost.
class CostBadge extends StatelessWidget {
  final int cost;
  const CostBadge({super.key, required this.cost});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gold = isDark ? AppColors.accentDark : AppColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.auto_awesome, size: 13, color: gold),
        const SizedBox(width: 5),
        Text('$cost ${cost == 1 ? 'credit' : 'credits'}',
            style: TextStyle(
                color: gold, fontWeight: FontWeight.w600, fontSize: 12.5)),
      ]),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader(
      {super.key, required this.title, this.action, this.onAction});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md, top: AppSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
              child:
                  Text(title, style: Theme.of(context).textTheme.titleLarge)),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

/// Rounded network image with graceful loading/error.
class RemoteImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double radius;
  const RemoteImage(this.url,
      {super.key,
      this.width,
      this.height,
      this.fit = BoxFit.cover,
      this.radius = AppRadii.md});

  @override
  Widget build(BuildContext context) {
    final placeholderColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.surfaceAltDark
        : AppColors.surfaceAlt;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        placeholder: (_, __) =>
            Container(width: width, height: height, color: placeholderColor),
        errorWidget: (_, __, ___) => Container(
          width: width,
          height: height,
          color: placeholderColor,
          child: const Icon(Icons.image_not_supported_outlined,
              color: AppColors.muted),
        ),
      ),
    );
  }
}

/// Standard states — never a bare spinner or blank screen.
class LoadingState extends StatelessWidget {
  final String? message;
  const LoadingState({super.key, this.message});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(strokeWidth: 2.6),
          if (message != null) ...[
            const SizedBox(height: AppSpace.lg),
            Text(message!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.muted),
            const SizedBox(height: AppSpace.lg),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpace.sm),
              Text(subtitle!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: AppSpace.xl),
              SecondaryButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorStateView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorStateView({super.key, required this.message, this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 44, color: AppColors.error),
            const SizedBox(height: AppSpace.lg),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpace.xl),
              SecondaryButton(
                  label: 'Try again', icon: Icons.refresh, onPressed: onRetry),
            ],
          ],
        ),
      ),
    );
  }
}

/// A tappable card used across Create/Explore.
class StyleCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? imageUrl;
  final VoidCallback? onTap;
  const StyleCard({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.imageUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.md),
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null)
                Icon(icon,
                    size: 26, color: Theme.of(context).colorScheme.primary),
              if (imageUrl != null)
                RemoteImage(imageUrl!, height: 96, width: double.infinity),
              const SizedBox(height: AppSpace.md),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Selectable chip for categories.
class CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const CategoryChip(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
              color:
                  selected ? scheme.primary : Theme.of(context).dividerColor),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : scheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 13.5)),
      ),
    );
  }
}

/// A subtle banner used for configuration/notice states.
class NoticeBanner extends StatelessWidget {
  final String message;
  final IconData icon;
  const NoticeBanner(
      {super.key, required this.message, this.icon = Icons.info_outline});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: AppSpace.sm),
          Expanded(
              child: Text(message,
                  style: TextStyle(fontSize: 13, color: scheme.primary))),
        ],
      ),
    );
  }
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

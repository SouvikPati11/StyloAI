import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../state/providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authControllerProvider).me;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.gutter, AppSpace.md, AppSpace.gutter, 90),
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.1),
                  backgroundImage: (me?.avatarUrl != null)
                      ? NetworkImage(me!.avatarUrl!)
                      : null,
                  child: me?.avatarUrl == null
                      ? Text(
                          (me?.displayName ?? 'S')
                              .characters
                              .first
                              .toUpperCase(),
                          style: t.headlineMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary),
                        )
                      : null,
                ),
                const SizedBox(width: AppSpace.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(me?.displayName ?? 'Stylist', style: t.titleLarge),
                      if (me?.email != null)
                        Text(me!.email!, style: t.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.xl),
            InkWell(
              borderRadius: BorderRadius.circular(AppRadii.md),
              onTap: () => context.push('/credits'),
              child: Container(
                padding: const EdgeInsets.all(AppSpace.lg),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: AppSpace.md),
                    Text('${me?.balance ?? 0} credits', style: t.titleMedium),
                    const Spacer(),
                    Text('Get more',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpace.xl),
            _Group(children: [
              _Item(
                  icon: Icons.style_outlined,
                  label: 'Style preferences',
                  onTap: () => context.push('/style-profile')),
              _Item(
                  icon: Icons.notifications_none,
                  label: 'Notifications',
                  onTap: () => context.push('/notifications')),
              _Item(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  onTap: () => context.push('/settings')),
            ]),
            const SizedBox(height: AppSpace.lg),
            _Group(children: [
              _Item(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Privacy Policy',
                  onTap: () => context.push('/legal/privacy')),
              _Item(
                  icon: Icons.description_outlined,
                  label: 'Terms of Service',
                  onTap: () => context.push('/legal/terms')),
            ]),
            const SizedBox(height: AppSpace.xl),
            SecondaryButton(
              label: 'Log out',
              icon: Icons.logout,
              onPressed: () async {
                await ref.read(authControllerProvider.notifier).signOut();
                if (context.mounted) context.go('/onboarding');
              },
            ),
            const SizedBox(height: AppSpace.lg),
            Center(child: Text('StyloAI · v1.0.0', style: t.bodySmall)),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(
                  height: 1, color: Theme.of(context).dividerColor, indent: 52),
          ]
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Item({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 22),
      title: Text(label, style: Theme.of(context).textTheme.titleMedium),
      trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
      onTap: onTap,
    );
  }
}

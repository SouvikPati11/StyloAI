import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../state/providers.dart';

/// Settings — notification preferences, privacy, and account controls
/// (including data + account deletion, §21).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<void> _updatePref(String key, bool value) async {
    try {
      await ref.read(userRepoProvider).update({key: value});
      await ref.read(authControllerProvider.notifier).refreshMe();
    } catch (_) {
      if (mounted) showSnack(context, 'Could not update. Please try again.');
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
            'This permanently deletes your account, photos, generated looks, and data. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(authControllerProvider.notifier).deleteAccount();
        if (mounted) context.go('/onboarding');
      } catch (_) {
        if (mounted) {
          showSnack(context, 'Could not delete account. Please try again.');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authControllerProvider).me;
    final prefs = me?.notifications;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter, AppSpace.md, AppSpace.gutter, 40),
        children: [
          Text('Notifications', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpace.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Generation updates'),
            subtitle:
                const Text('When your look is ready or a generation fails'),
            value: prefs?.generation ?? true,
            onChanged: (v) => _updatePref('notif_generation', v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('New trends & styles'),
            value: prefs?.trending ?? true,
            onChanged: (v) => _updatePref('notif_trending', v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Offers & updates'),
            value: prefs?.marketing ?? false,
            onChanged: (v) => _updatePref('notif_marketing', v),
          ),
          const SizedBox(height: AppSpace.xl),
          Text('Privacy', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpace.sm),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
            onTap: () => context.push('/legal/privacy'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
            onTap: () => context.push('/legal/terms'),
          ),
          const SizedBox(height: AppSpace.xl),
          Text('Account', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpace.sm),
          Text(
            'Deleting your account removes your photos, generated looks, saved looks, and profile.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpace.md),
          OutlinedButton(
            onPressed: _confirmDeleteAccount,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
            ),
            child: const Text('Delete account & data'),
          ),
        ],
      ),
    );
  }
}

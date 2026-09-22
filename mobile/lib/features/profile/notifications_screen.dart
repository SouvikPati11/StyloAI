import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../state/providers.dart';

final _notificationsProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  return ref.read(notificationsRepoProvider).list();
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_notificationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: async.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorStateView(
            message: '$e',
            onRetry: () => ref.invalidate(_notificationsProvider)),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none,
              title: 'You’re all caught up',
              subtitle:
                  'Updates about your looks and new trends will show up here.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_notificationsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpace.gutter),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Theme.of(context).dividerColor),
              itemBuilder: (_, i) {
                final n = items[i];
                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: AppSpace.sm),
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.1),
                    child: Icon(_iconFor(n.type),
                        size: 20, color: Theme.of(context).colorScheme.primary),
                  ),
                  title: Text(n.title,
                      style: Theme.of(context).textTheme.titleMedium),
                  subtitle: Text(
                      '${n.body}\n${DateFormat.MMMd().add_jm().format(n.createdAt.toLocal())}'),
                  isThreeLine: true,
                  onTap: () =>
                      ref.read(notificationsRepoProvider).markRead(n.id),
                );
              },
            ),
          );
        },
      ),
    );
  }

  IconData _iconFor(String type) {
    if (type.contains('completed')) return Icons.auto_awesome;
    if (type.contains('failed')) return Icons.error_outline;
    if (type.contains('credit') || type.contains('bonus')) {
      return Icons.card_giftcard;
    }
    return Icons.notifications_none;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../services/purchase_service.dart';
import '../../state/providers.dart';

final _productsProvider =
    FutureProvider.autoDispose<List<StoreProduct>>((ref) async {
  return ref.read(billingRepoProvider).products();
});
final _txnsProvider = FutureProvider.autoDispose<List<CreditTxn>>((ref) async {
  return ref.read(creditsRepoProvider).transactions();
});

/// Credits: balance, credit packs (Google Play Billing), and the ledger.
class CreditsScreen extends ConsumerStatefulWidget {
  const CreditsScreen({super.key});
  @override
  ConsumerState<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends ConsumerState<CreditsScreen> {
  PurchaseService? _purchases;
  bool _billingAvailable = false;
  bool _checkedBilling = false;
  String? _busyProductId;

  @override
  void initState() {
    super.initState();
    _initBilling();
  }

  Future<void> _initBilling() async {
    final service = PurchaseService(ref.read(billingRepoProvider));
    final available = await service.isAvailable();
    service.start(
      onGranted: (balance) async {
        await ref.read(authControllerProvider.notifier).refreshMe();
        ref.invalidate(_txnsProvider);
        if (mounted) {
          setState(() => _busyProductId = null);
          showSnack(context, 'Credits added. New balance: $balance');
        }
      },
      onError: (message) {
        if (!mounted) return;
        setState(() => _busyProductId = null);
        if (message == 'cancelled') return;
        showSnack(context, _friendlyError(message));
      },
    );
    if (mounted) {
      setState(() {
        _purchases = service;
        _billingAvailable = available;
        _checkedBilling = true;
      });
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('play_not_configured') || raw.contains('not configured')) {
      return 'Purchases aren’t enabled yet. Please try again later.';
    }
    return 'Purchase could not be completed. Please try again.';
  }

  @override
  void dispose() {
    _purchases?.dispose();
    super.dispose();
  }

  Future<void> _buy(StoreProduct product) async {
    if (!_billingAvailable || _purchases == null) return;
    setState(() => _busyProductId = product.productId);
    try {
      final details = await _purchases!.queryProducts({product.productId});
      if (!mounted) return;
      if (details.isEmpty) {
        setState(() => _busyProductId = null);
        showSnack(context, 'This pack isn’t available on this device yet.');
        return;
      }
      await _purchases!.buy(details.first);
      // Result arrives via the purchase stream (onGranted/onError).
    } catch (_) {
      if (!mounted) return;
      setState(() => _busyProductId = null);
      showSnack(context, 'Could not start the purchase.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authControllerProvider).me;
    final products = ref.watch(_productsProvider);
    final txns = ref.watch(_txnsProvider);
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Credits')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter, AppSpace.md, AppSpace.gutter, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpace.xl),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your balance',
                    style:
                        TextStyle(color: Colors.white.withValues(alpha: 0.85))),
                const SizedBox(height: 4),
                Text('${me?.balance ?? 0} credits',
                    style: t.displayMedium?.copyWith(color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          Text('Buy credits', style: t.titleLarge),
          const SizedBox(height: AppSpace.sm),
          if (_checkedBilling && !_billingAvailable)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpace.md),
              child: NoticeBanner(
                message:
                    'In-app purchases are unavailable on this device/build. Configure Google Play Billing to enable them.',
              ),
            ),
          products.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(AppSpace.xl), child: LoadingState()),
            error: (e, _) => ErrorStateView(
                message: '$e',
                onRetry: () => ref.invalidate(_productsProvider)),
            data: (list) => Column(
              children: [
                for (final p in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.md),
                    child: _ProductTile(
                      product: p,
                      busy: _busyProductId == p.productId,
                      enabled: _billingAvailable,
                      onBuy: () => _buy(p),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          Text('Transaction history', style: t.titleLarge),
          const SizedBox(height: AppSpace.sm),
          txns.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(AppSpace.lg), child: LoadingState()),
            error: (e, _) => ErrorStateView(
                message: '$e', onRetry: () => ref.invalidate(_txnsProvider)),
            data: (list) {
              if (list.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpace.xl),
                  child: EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No transactions yet',
                    subtitle: 'Your credit activity will appear here.',
                  ),
                );
              }
              return Column(
                  children: [for (final txn in list) _TxnRow(txn: txn)]);
            },
          ),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final StoreProduct product;
  final bool busy;
  final bool enabled;
  final VoidCallback onBuy;
  const _ProductTile(
      {required this.product,
      required this.busy,
      required this.enabled,
      required this.onBuy});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${product.totalCredits} credits',
                    style: Theme.of(context).textTheme.titleLarge),
                Text(
                  product.bonus > 0
                      ? '${product.title} · +${product.bonus} bonus'
                      : product.title,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: 108,
              child: FilledButton(
                onPressed: enabled && !busy ? onBuy : null,
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44)),
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(product.priceHint ?? 'Buy'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TxnRow extends StatelessWidget {
  final CreditTxn txn;
  const _TxnRow({required this.txn});
  @override
  Widget build(BuildContext context) {
    final positive = txn.amount >= 0;
    final color = positive ? AppColors.success : AppColors.inkSoft;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_label(txn.type),
                    style: Theme.of(context).textTheme.titleMedium),
                Text(
                    DateFormat.yMMMd().add_jm().format(txn.createdAt.toLocal()),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Text('${positive ? '+' : ''}${txn.amount}',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: color, fontSize: 16)),
        ],
      ),
    );
  }

  String _label(String type) {
    switch (type) {
      case 'signup_bonus':
        return 'Welcome bonus';
      case 'purchase':
        return 'Credits purchased';
      case 'admin_grant':
        return 'Bonus credits';
      case 'promo':
        return 'Promo credits';
      case 'generation_hold':
        return 'Generation';
      case 'generation_refund':
        return 'Refund';
      default:
        return type.replaceAll('_', ' ');
    }
  }
}

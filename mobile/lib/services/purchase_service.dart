import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../data/repositories.dart';

/// Wraps Google Play Billing (in_app_purchase). The client only launches the
/// purchase and forwards the resulting purchase token to the backend, which
/// verifies it with the Play Developer API and grants credits. The client is
/// never trusted to grant credits itself.
class PurchaseService {
  final BillingRepository billing;
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  PurchaseService(this.billing);

  Future<bool> isAvailable() => _iap.isAvailable();

  Future<List<ProductDetails>> queryProducts(Set<String> ids) async {
    final response = await _iap.queryProductDetails(ids);
    return response.productDetails;
  }

  /// Starts listening for purchase updates. [onGranted] fires with the new
  /// balance after successful server verification; [onError] on failure.
  void start({
    required void Function(int balance) onGranted,
    required void Function(String message) onError,
  }) {
    _sub ??= _iap.purchaseStream.listen((purchases) async {
      for (final p in purchases) {
        if (p.status == PurchaseStatus.purchased ||
            p.status == PurchaseStatus.restored) {
          try {
            final token = p.verificationData.serverVerificationData;
            final res = await billing.verify(
              productId: p.productID,
              purchaseToken: token,
              orderId: p.purchaseID,
            );
            onGranted((res['balance'] as num?)?.toInt() ?? 0);
          } catch (e) {
            onError(e.toString());
          } finally {
            if (p.pendingCompletePurchase) {
              await _iap.completePurchase(p);
            }
          }
        } else if (p.status == PurchaseStatus.error) {
          onError(p.error?.message ?? 'Purchase failed.');
        } else if (p.status == PurchaseStatus.canceled) {
          onError('cancelled');
        }
      }
    });
  }

  Future<void> buy(ProductDetails product) async {
    final param = PurchaseParam(productDetails: product);
    // Credits are consumable.
    await _iap.buyConsumable(purchaseParam: param);
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}

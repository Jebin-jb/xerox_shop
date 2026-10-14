import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/app_models.dart';

/// Firebase Firestore Service for Shop Payment Settings.
///
/// Stores and streams merchant UPI configurations from:
/// `/shops/main_shop/settings/payment`
///
/// Rules:
/// - Firebase Firestore is the single source of truth for payment configuration.
/// - Only Shopkeeper can update settings.
/// - Never collects or stores sensitive banking passwords, PINs, or CVV.
class FirebasePaymentConfigService {
  static final FirebasePaymentConfigService instance =
      FirebasePaymentConfigService._internal();

  FirebasePaymentConfigService._internal();

  FirebaseFirestore? _firestoreInstance;

  FirebaseFirestore? get _firestore {
    try {
      _firestoreInstance ??= FirebaseFirestore.instance;
      return _firestoreInstance;
    } catch (_) {
      return null;
    }
  }

  DocumentReference<Map<String, dynamic>>? get _paymentDoc => _firestore
      ?.collection('shops')
      .doc('main_shop')
      .collection('settings')
      .doc('payment');

  DocumentReference<Map<String, dynamic>>? get _accountDoc => _firestore
      ?.collection('shops')
      .doc('main_shop')
      .collection('settings')
      .doc('payment_account');

  DocumentReference<Map<String, dynamic>>? get _pricingDoc => _firestore
      ?.collection('shops')
      .doc('main_shop')
      .collection('settings')
      .doc('live_pricing');

  /// Streams real-time payment configuration from Firebase Firestore.
  Stream<ShopPaymentConfig> streamPaymentConfig() {
    final doc = _paymentDoc;
    if (doc == null) {
      return Stream.value(ShopPaymentConfig.defaultConfig());
    }
    return doc
        .snapshots()
        .map((snapshot) {
          if (snapshot.exists && snapshot.data() != null) {
            return ShopPaymentConfig.fromMap(snapshot.data()!);
          }
          return ShopPaymentConfig.defaultConfig();
        })
        .handleError((error) {
          debugPrint('FirebasePaymentConfigService stream error: $error');
          return ShopPaymentConfig.defaultConfig();
        });
  }

  /// Fetches current payment configuration once.
  Future<ShopPaymentConfig> getPaymentConfig() async {
    final doc = _paymentDoc;
    if (doc == null) return ShopPaymentConfig.defaultConfig();
    try {
      final snapshot = await doc.get().timeout(const Duration(seconds: 2));
      if (snapshot.exists && snapshot.data() != null) {
        return ShopPaymentConfig.fromMap(snapshot.data()!);
      }
    } catch (e) {
      debugPrint('FirebasePaymentConfigService getPaymentConfig notice: $e');
    }
    return ShopPaymentConfig.defaultConfig();
  }

  /// Updates shop payment configuration in Firebase Firestore.
  Future<void> updatePaymentConfig(ShopPaymentConfig config) async {
    final doc = _paymentDoc;
    if (doc == null) return;
    try {
      await doc
          .set(config.toMap(), SetOptions(merge: true))
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('Error updating payment config: $e');
    }
  }

  /// Streams full Shop Payment Account for Shopkeeper
  Stream<ShopPaymentAccount> streamPaymentAccount() {
    final doc = _accountDoc;
    if (doc == null) return const Stream.empty();
    return doc
        .snapshots()
        .where((snapshot) => snapshot.exists && snapshot.data() != null)
        .map((snapshot) => ShopPaymentAccount.fromMap(snapshot.data()!))
        .handleError((error) {
          debugPrint(
            'FirebasePaymentConfigService streamPaymentAccount notice: $error',
          );
        });
  }

  /// Fetches full Shop Payment Account
  Future<ShopPaymentAccount> getPaymentAccount() async {
    final doc = _accountDoc;
    if (doc == null) return ShopPaymentAccount.empty();
    try {
      final snapshot = await doc.get().timeout(const Duration(seconds: 2));
      if (snapshot.exists && snapshot.data() != null) {
        return ShopPaymentAccount.fromMap(snapshot.data()!);
      }
    } catch (e) {
      debugPrint('FirebasePaymentConfigService getPaymentAccount notice: $e');
    }
    return ShopPaymentAccount.empty();
  }

  /// Updates full Shop Payment Account (Shopkeeper only)
  Future<void> updatePaymentAccount(ShopPaymentAccount account) async {
    final accDoc = _accountDoc;
    final payDoc = _paymentDoc;
    if (accDoc == null || payDoc == null) return;
    try {
      await accDoc
          .set(account.toMap(), SetOptions(merge: true))
          .timeout(const Duration(seconds: 3));
      // Also update safe payment config so student online pay flow syncs instantly
      await payDoc
          .set(account.toPaymentConfig().toMap(), SetOptions(merge: true))
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('FirebasePaymentConfigService updatePaymentAccount notice: $e');
    }
  }

  /// Streams Live Shop Pricing from Firestore (Firestore is single source of truth)
  Stream<LiveShopPricing> streamLivePricing() {
    final doc = _pricingDoc;
    if (doc == null) return const Stream.empty();
    return doc
        .snapshots()
        .where((snapshot) => snapshot.exists && snapshot.data() != null)
        .map((snapshot) => LiveShopPricing.fromMap(snapshot.data()!))
        .handleError((error) {
          debugPrint(
            'FirebasePaymentConfigService streamLivePricing notice: $error',
          );
        });
  }

  /// Fetches current Live Shop Pricing directly from Firestore.
  /// Returns null if network fails or times out so local saved pricing is never clobbered.
  Future<LiveShopPricing?> getLivePricing() async {
    final doc = _pricingDoc;
    if (doc == null) return null;
    try {
      final snapshot = await doc.get().timeout(const Duration(seconds: 2));
      if (snapshot.exists && snapshot.data() != null) {
        return LiveShopPricing.fromMap(snapshot.data()!);
      }
      // Seed once into Firestore if document does not exist
      final def = LiveShopPricing.defaultPricing();
      try {
        await doc
            .set(def.toMap(), SetOptions(merge: true))
            .timeout(const Duration(seconds: 2));
      } catch (e) {
        debugPrint('Notice seeding default pricing to Firestore: $e');
      }
      return def;
    } catch (e) {
      debugPrint('FirebasePaymentConfigService getLivePricing notice: $e');
      return null;
    }
  }

  /// Updates Live Shop Pricing in Firestore (Shopkeeper only).
  /// Confirms write completion before returning or safely times out.
  Future<void> updateLivePricing(LiveShopPricing pricing) async {
    final doc = _pricingDoc;
    if (doc == null) {
      debugPrint('Firestore not initialized; skipping live pricing cloud write.');
      return;
    }
    try {
      await doc
          .set(pricing.toMap(), SetOptions(merge: true))
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              debugPrint('Firestore updateLivePricing timed out: queued locally');
            },
          );
    } catch (e) {
      debugPrint('FirebasePaymentConfigService updateLivePricing notice: $e');
    }
  }

  CollectionReference<Map<String, dynamic>>? get _ordersCollection =>
      _firestore?.collection('orders');

  /// Persists order to Firestore with special instructions and all configuration options
  Future<void> saveOrder(PrintOrder order) async {
    final col = _ordersCollection;
    if (col == null) return;
    try {
      await col
          .doc(order.id)
          .set(order.toMap(), SetOptions(merge: true))
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('FirebasePaymentConfigService saveOrder notice: $e');
    }
  }

  /// Updates order fields in Firestore
  Future<void> updateFirestoreOrder(
    String orderId,
    Map<String, dynamic> changes,
  ) async {
    final col = _ordersCollection;
    if (col == null) return;
    try {
      await col
          .doc(orderId)
          .set(changes, SetOptions(merge: true))
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('FirebasePaymentConfigService updateFirestoreOrder notice: $e');
    }
  }
}

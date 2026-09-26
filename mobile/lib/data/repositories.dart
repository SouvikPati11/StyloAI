import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../core/api_client.dart';
import 'models.dart';

/// Repositories wrap the API client and expose typed methods to the app.
/// Image uploads use the backend's presigned-PUT flow: the app asks the backend
/// for a short-lived S3 URL, PUTs the bytes directly to S3, then references the
/// returned key. Bytes never pass through the API server.

class AuthRepository {
  final ApiClient api;
  AuthRepository(this.api);

  /// Exchange a verified Firebase ID token for backend tokens.
  Future<Map<String, dynamic>> loginWithGoogle(String firebaseIdToken) =>
      api.post('/auth/google', data: {'firebase_id_token': firebaseIdToken});

  Future<void> logout() async {
    await api.post('/auth/logout');
  }

  Future<void> deleteAccount() async {
    await api.delete('/account');
  }
}

class UserRepository {
  final ApiClient api;
  UserRepository(this.api);

  Future<Me> me() async => Me.fromJson(await api.get('/me'));

  Future<Me> update(Map<String, dynamic> patch) async =>
      Me.fromJson(await api.patch('/me', data: patch));

  Future<AppConfig> config() async =>
      AppConfig.fromJson(await api.get('/config'));

  Future<void> registerDevice(String fcmToken) =>
      api.post('/devices', data: {'fcm_token': fcmToken}).then((_) {});
}

class UploadRepository {
  final ApiClient api;
  UploadRepository(this.api);

  /// Presign + PUT to S3, returning the s3 key to reference in a generation.
  Future<String> uploadImage(File file, String purpose) async {
    final contentType = _contentTypeFor(file.path);
    final presign = await api.post('/uploads/presign',
        data: {'purpose': purpose, 'content_type': contentType});
    final uploadUrl = presign['upload_url'] as String;
    final key = presign['s3_key'] as String;
    final bytes = await file.readAsBytes();
    await _putToS3(uploadUrl, bytes, contentType);
    return key;
  }

  Future<void> _putToS3(String url, Uint8List bytes, String contentType) async {
    // A bare Dio without our auth interceptor — S3 rejects extra headers.
    final s3 = Dio();
    await s3.put(url,
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: {
            'Content-Type': contentType,
            Headers.contentLengthHeader: bytes.length
          },
        ));
  }

  String _contentTypeFor(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}

class GenerationRepository {
  final ApiClient api;
  GenerationRepository(this.api);

  /// Submit a generation. `idempotencyKey` protects against duplicate charges.
  Future<Generation> submit({
    required String type,
    required String mode, // 'explore' | 'reference_upload'
    required String userPhotoKey,
    String? presetKey,
    String? referenceKey,
    String? trendingContentId,
    String? poseId,
    String? resolution,
    required String idempotencyKey,
  }) async {
    final res = await api.post('/generations', headers: {
      'Idempotency-Key': idempotencyKey
    }, data: {
      'type': type,
      'mode': mode,
      'user_photo_key': userPhotoKey,
      if (presetKey != null) 'preset_key': presetKey,
      if (referenceKey != null) 'reference_key': referenceKey,
      // When a specific admin-created style/pose is chosen, the backend prices
      // and configures the generation from its id — never from the client.
      if (trendingContentId != null) 'trending_content_id': trendingContentId,
      if (poseId != null) 'pose_id': poseId,
      'options': {'resolution': resolution ?? 'standard'},
    });
    // Submit returns { generation_id, status, credit_cost }; fetch full state.
    final id = res['generation_id'] as String;
    return get(id);
  }

  Future<Generation> get(String id) async =>
      Generation.fromJson(await api.get('/generations/$id'));

  Future<List<GenerationSummary>> history({String? type}) async {
    final res =
        await api.get('/generations', query: {if (type != null) 'type': type});
    return ((res['items'] as List?) ?? [])
        .map((e) =>
            GenerationSummary.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> delete(String id) => api.delete('/generations/$id').then((_) {});
}

class ContentRepository {
  final ApiClient api;
  ContentRepository(this.api);

  Future<List<TrendingItem>> trending({String? section}) async {
    final res = await api
        .get('/trending', query: {if (section != null) 'section': section});
    return ((res['items'] as List?) ?? [])
        .map((e) => TrendingItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<TrendingItem>> recommendations() async {
    final res = await api.get('/recommendations');
    return ((res['items'] as List?) ?? [])
        .map((e) => TrendingItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Reference poses — a separate, free content type (no credit price).
  Future<List<Pose>> poses() async {
    final res = await api.get('/poses');
    return ((res['items'] as List?) ?? [])
        .map((e) => Pose.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }
}

class CreditsRepository {
  final ApiClient api;
  CreditsRepository(this.api);

  Future<int> balance() async =>
      (await api.get('/wallet'))['balance'] as int? ?? 0;

  Future<List<CreditTxn>> transactions() async {
    final res = await api.get('/wallet/transactions');
    return ((res['items'] as List?) ?? [])
        .map((e) => CreditTxn.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }
}

class BillingRepository {
  final ApiClient api;
  BillingRepository(this.api);

  Future<List<StoreProduct>> products() async {
    final res = await api.get('/store/products');
    return ((res['products'] as List?) ?? [])
        .map((e) => StoreProduct.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Server-side Play verification. Returns the new balance; grants once.
  Future<Map<String, dynamic>> verify({
    required String productId,
    required String purchaseToken,
    String? orderId,
  }) =>
      api.post('/billing/google/verify', data: {
        'product_id': productId,
        'purchase_token': purchaseToken,
        if (orderId != null) 'order_id': orderId,
      });
}

class LooksRepository {
  final ApiClient api;
  LooksRepository(this.api);

  Future<void> save(String generatedImageId, {String? title}) =>
      api.post('/looks', data: {
        'generated_image_id': generatedImageId,
        if (title != null) 'title': title
      }).then((_) {});

  Future<List<SavedLook>> list() async {
    final res = await api.get('/looks');
    return ((res['items'] as List?) ?? [])
        .map((e) => SavedLook.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> delete(String id) => api.delete('/looks/$id').then((_) {});
}

class StyleProfileRepository {
  final ApiClient api;
  StyleProfileRepository(this.api);

  Future<StyleProfile> get() async =>
      StyleProfile.fromJson(await api.get('/me/style-profile'));

  Future<StyleProfile> put(StyleProfile profile) async => StyleProfile.fromJson(
      await api.put('/me/style-profile', data: profile.toJson()));
}

class NotificationsRepository {
  final ApiClient api;
  NotificationsRepository(this.api);

  Future<List<AppNotification>> list() async {
    final res = await api.get('/notifications');
    return ((res['items'] as List?) ?? [])
        .map(
            (e) => AppNotification.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> markRead(String id) =>
      api.post('/notifications/$id/read').then((_) {});
}

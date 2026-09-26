// Data models mirroring the backend API contracts (docs/API_CONTRACTS.md).
// Kept as immutable value objects with fromJson factories.

class Me {
  final String id;
  final String? displayName;
  final String? email;
  final String? avatarUrl;
  final int balance;
  final bool onboardingCompleted;
  final NotificationPrefs notifications;

  Me({
    required this.id,
    this.displayName,
    this.email,
    this.avatarUrl,
    required this.balance,
    required this.onboardingCompleted,
    required this.notifications,
  });

  factory Me.fromJson(Map<String, dynamic> j) => Me(
        id: j['id'] as String,
        displayName: j['display_name'] as String?,
        email: j['email'] as String?,
        avatarUrl: j['avatar_url'] as String?,
        balance: (j['balance'] ?? 0) as int,
        onboardingCompleted: (j['onboarding_completed'] ?? false) as bool,
        notifications: NotificationPrefs.fromJson(
            (j['notifications'] as Map?)?.cast<String, dynamic>() ?? const {}),
      );
}

class NotificationPrefs {
  final bool generation;
  final bool trending;
  final bool marketing;
  NotificationPrefs(
      {required this.generation,
      required this.trending,
      required this.marketing});
  factory NotificationPrefs.fromJson(Map<String, dynamic> j) =>
      NotificationPrefs(
        generation: (j['generation'] ?? true) as bool,
        trending: (j['trending'] ?? true) as bool,
        marketing: (j['marketing'] ?? false) as bool,
      );
}

/// Server-driven config: credit costs, features, categories. The client renders
/// these and never hard-codes them.
class AppConfig {
  final Map<String, int> creditCosts;
  final Map<String, bool> features;
  final List<String> resolutions;
  final Map<String, List<Category>> sections;

  AppConfig({
    required this.creditCosts,
    required this.features,
    required this.resolutions,
    required this.sections,
  });

  factory AppConfig.fromJson(Map<String, dynamic> j) {
    final costs = <String, int>{};
    (j['credit_costs'] as Map?)
        ?.forEach((k, v) => costs[k as String] = (v as num).toInt());
    final feats = <String, bool>{};
    (j['features'] as Map?)?.forEach((k, v) => feats[k as String] = v as bool);
    final sections = <String, List<Category>>{};
    (j['sections'] as Map?)?.forEach((k, v) {
      sections[k as String] = (v as List)
          .map((e) => Category.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    });
    return AppConfig(
      creditCosts: costs,
      features: feats,
      resolutions: ((j['resolutions'] as List?) ?? ['standard']).cast<String>(),
      sections: sections,
    );
  }

  int costFor(String type) => creditCosts[type] ?? 0;
  bool isEnabled(String feature) => features[feature] != false;
}

class Category {
  final String key;
  final String label;
  Category({required this.key, required this.label});
  factory Category.fromJson(Map<String, dynamic> j) =>
      Category(key: j['key'] as String, label: j['label'] as String);
}

class TrendingItem {
  final String id;
  final String section;
  final String title;
  final String? subtitle;
  final String? description;
  final List<String> tags;
  final String? presetKey;

  /// Authoritative per-item credit price. null = use the category default; the
  /// client never decides the charge — the backend prices by this item's id.
  final int? creditPrice;
  final String imageUrl;
  TrendingItem({
    required this.id,
    required this.section,
    required this.title,
    this.subtitle,
    this.description,
    this.tags = const [],
    this.presetKey,
    this.creditPrice,
    required this.imageUrl,
  });
  factory TrendingItem.fromJson(Map<String, dynamic> j) => TrendingItem(
        id: j['id'] as String,
        section: j['section'] as String,
        title: j['title'] as String,
        subtitle: j['subtitle'] as String?,
        description: j['description'] as String?,
        tags: ((j['tags'] as List?) ?? const []).cast<String>(),
        presetKey: j['preset_key'] as String?,
        creditPrice: (j['credit_price'] as num?)?.toInt(),
        imageUrl: j['image_url'] as String,
      );
}

/// A reference pose — a SEPARATE, FREE content type. No credit price. The app
/// shows the image + name + short instruction so the user understands the pose.
class Pose {
  final String id;
  final String title;
  final String? description;
  final String? poseType;
  final List<String> tags;
  final String imageUrl;
  Pose({
    required this.id,
    required this.title,
    this.description,
    this.poseType,
    this.tags = const [],
    required this.imageUrl,
  });
  factory Pose.fromJson(Map<String, dynamic> j) => Pose(
        id: j['id'] as String,
        title: j['title'] as String,
        description: j['description'] as String?,
        poseType: j['pose_type'] as String?,
        tags: ((j['tags'] as List?) ?? const []).cast<String>(),
        imageUrl: j['image_url'] as String,
      );
}

enum GenStatus { queued, processing, succeeded, failed, refunded, unknown }

GenStatus _status(String? s) {
  switch (s) {
    case 'queued':
      return GenStatus.queued;
    case 'processing':
      return GenStatus.processing;
    case 'succeeded':
      return GenStatus.succeeded;
    case 'failed':
      return GenStatus.failed;
    case 'refunded':
      return GenStatus.refunded;
    default:
      return GenStatus.unknown;
  }
}

class GeneratedImageRef {
  final String id;
  final String url;
  final String? thumbnailUrl;
  GeneratedImageRef({required this.id, required this.url, this.thumbnailUrl});
  factory GeneratedImageRef.fromJson(Map<String, dynamic> j) =>
      GeneratedImageRef(
        id: j['id'] as String,
        url: j['url'] as String,
        thumbnailUrl: j['thumbnail_url'] as String?,
      );
}

class Generation {
  final String id;
  final String type;
  final GenStatus status;
  final int creditCost;
  final String? errorCode;
  final List<GeneratedImageRef> images;

  Generation({
    required this.id,
    required this.type,
    required this.status,
    required this.creditCost,
    this.errorCode,
    required this.images,
  });

  factory Generation.fromJson(Map<String, dynamic> j) => Generation(
        id: j['id'] as String,
        type: (j['type'] ?? '') as String,
        status: _status(j['status'] as String?),
        creditCost: (j['credit_cost'] ?? 0) as int,
        errorCode: j['error_code'] as String?,
        images: ((j['images'] as List?) ?? [])
            .map((e) =>
                GeneratedImageRef.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );

  bool get isTerminal =>
      status == GenStatus.succeeded ||
      status == GenStatus.failed ||
      status == GenStatus.refunded;
}

class GenerationSummary {
  final String id;
  final String type;
  final GenStatus status;
  final String? thumbnailUrl;
  final DateTime createdAt;
  GenerationSummary({
    required this.id,
    required this.type,
    required this.status,
    this.thumbnailUrl,
    required this.createdAt,
  });
  factory GenerationSummary.fromJson(Map<String, dynamic> j) =>
      GenerationSummary(
        id: j['id'] as String,
        type: (j['type'] ?? '') as String,
        status: _status(j['status'] as String?),
        thumbnailUrl: j['thumbnail_url'] as String?,
        createdAt: DateTime.tryParse((j['created_at'] ?? '') as String) ??
            DateTime.now(),
      );
}

class SavedLook {
  final String id;
  final String? title;
  final String imageUrl;
  SavedLook({required this.id, this.title, required this.imageUrl});
  factory SavedLook.fromJson(Map<String, dynamic> j) => SavedLook(
        id: j['id'] as String,
        title: j['title'] as String?,
        imageUrl: j['image_url'] as String,
      );
}

class CreditTxn {
  final int amount;
  final int balanceAfter;
  final String type;
  final String status;
  final String? note;
  final DateTime createdAt;
  CreditTxn({
    required this.amount,
    required this.balanceAfter,
    required this.type,
    required this.status,
    this.note,
    required this.createdAt,
  });
  factory CreditTxn.fromJson(Map<String, dynamic> j) => CreditTxn(
        amount: (j['amount'] ?? 0) as int,
        balanceAfter: (j['balance_after'] ?? 0) as int,
        type: (j['type'] ?? '') as String,
        status: (j['status'] ?? '') as String,
        note: j['note'] as String?,
        createdAt: DateTime.tryParse((j['created_at'] ?? '') as String) ??
            DateTime.now(),
      );
}

class StoreProduct {
  final String productId;
  final int credits;
  final String title;
  final String? priceHint;
  final int bonus;
  StoreProduct({
    required this.productId,
    required this.credits,
    required this.title,
    this.priceHint,
    required this.bonus,
  });
  factory StoreProduct.fromJson(Map<String, dynamic> j) => StoreProduct(
        productId: j['product_id'] as String,
        credits: (j['credits'] ?? 0) as int,
        title: (j['title'] ?? '') as String,
        priceHint: j['price_hint'] as String?,
        bonus: (j['bonus'] ?? 0) as int,
      );
  int get totalCredits => credits + bonus;
}

class StyleProfile {
  final List<String> preferredStyles;
  final List<String> favoriteColors;
  final List<String> styleInterests;
  final List<String> hairPreferences;
  final List<String> glassesPreferences;
  final List<String> occasionPreferences;
  final String? aiSummary;

  StyleProfile({
    required this.preferredStyles,
    required this.favoriteColors,
    required this.styleInterests,
    required this.hairPreferences,
    required this.glassesPreferences,
    required this.occasionPreferences,
    this.aiSummary,
  });

  factory StyleProfile.fromJson(Map<String, dynamic> j) => StyleProfile(
        preferredStyles:
            ((j['preferred_styles'] as List?) ?? []).cast<String>(),
        favoriteColors: ((j['favorite_colors'] as List?) ?? []).cast<String>(),
        styleInterests: ((j['style_interests'] as List?) ?? []).cast<String>(),
        hairPreferences:
            ((j['hair_preferences'] as List?) ?? []).cast<String>(),
        glassesPreferences:
            ((j['glasses_preferences'] as List?) ?? []).cast<String>(),
        occasionPreferences:
            ((j['occasion_preferences'] as List?) ?? []).cast<String>(),
        aiSummary: j['ai_summary'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'preferred_styles': preferredStyles,
        'favorite_colors': favoriteColors,
        'style_interests': styleInterests,
        'hair_preferences': hairPreferences,
        'glasses_preferences': glassesPreferences,
        'occasion_preferences': occasionPreferences,
      };
}

class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;
  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
  });
  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        type: (j['type'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        body: (j['body'] ?? '') as String,
        read: (j['read'] ?? false) as bool,
        createdAt: DateTime.tryParse((j['created_at'] ?? '') as String) ??
            DateTime.now(),
      );
}

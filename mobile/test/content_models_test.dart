import 'package:flutter_test/flutter_test.dart';
import 'package:styloai/data/models.dart';

/// Locks the Admin↔Backend↔Mobile content contract on the mobile side: a
/// Trending Style carries category, tags, description and an authoritative
/// credit price; a Pose is a separate, free type with no price at all.
void main() {
  group('TrendingItem', () {
    test('parses category, tags, description and credit price', () {
      final t = TrendingItem.fromJson({
        'id': 'abc',
        'section': 'hair',
        'title': 'Modern Fade',
        'subtitle': 'Sharp taper',
        'description': 'Modern low fade hairstyle',
        'tags': ['Fade', 'Modern'],
        'preset_key': 'fade',
        'credit_price': 10,
        'image_url': 'https://example.com/x.jpg',
      });
      expect(t.section, 'hair');
      expect(t.tags, ['Fade', 'Modern']);
      expect(t.description, 'Modern low fade hairstyle');
      expect(t.creditPrice, 10);
    });

    test('free content (price 0) and default price (null) are distinct', () {
      final free = TrendingItem.fromJson({
        'id': '1', 'section': 'outfit', 'title': 'A', 'image_url': 'u', 'credit_price': 0,
      });
      final def = TrendingItem.fromJson({
        'id': '2', 'section': 'outfit', 'title': 'B', 'image_url': 'u',
      });
      expect(free.creditPrice, 0);
      expect(def.creditPrice, isNull);
      expect(def.tags, isEmpty);
    });
  });

  group('Pose', () {
    test('parses title, instruction and tags with no price field', () {
      final p = Pose.fromJson({
        'id': 'p1',
        'title': 'Confident Standing',
        'description': 'Stand upright, one shoulder slightly forward.',
        'pose_type': 'Standing',
        'tags': ['Standing'],
        'image_url': 'https://example.com/p.jpg',
      });
      expect(p.title, 'Confident Standing');
      expect(p.description, contains('shoulder'));
      expect(p.poseType, 'Standing');
      expect(p.tags, ['Standing']);
      // There is deliberately no credit-price concept on Pose.
      expect(p.imageUrl, isNotEmpty);
    });
  });
}

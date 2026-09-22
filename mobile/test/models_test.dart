import 'package:flutter_test/flutter_test.dart';
import 'package:styloai/data/models.dart';

void main() {
  group('AppConfig', () {
    test('parses credit costs, features and sections from server config', () {
      final config = AppConfig.fromJson({
        'credit_costs': {'outfit': 4, 'hair': 4, 'ai_edit': 3},
        'features': {'outfit': true, 'hair': false},
        'resolutions': ['standard', 'high'],
        'sections': {
          'outfit': [
            {'key': 'streetwear', 'label': 'Streetwear'},
          ],
        },
      });
      // Costs come from the server, never hard-coded on the client.
      expect(config.costFor('outfit'), 4);
      expect(config.costFor('ai_edit'), 3);
      expect(config.costFor('unknown'), 0);
      // Feature flags: default enabled unless explicitly false.
      expect(config.isEnabled('outfit'), true);
      expect(config.isEnabled('hair'), false);
      expect(config.isEnabled('glasses'), true);
      expect(config.sections['outfit']!.first.label, 'Streetwear');
    });
  });

  group('Generation', () {
    test('maps status and detects terminal states', () {
      final g = Generation.fromJson({
        'id': 'g1',
        'type': 'outfit',
        'status': 'succeeded',
        'credit_cost': 4,
        'images': [
          {'id': 'i1', 'url': 'https://example/img.jpg'},
        ],
      });
      expect(g.status, GenStatus.succeeded);
      expect(g.isTerminal, true);
      expect(g.images.single.url, 'https://example/img.jpg');
    });

    test('refunded and failed are terminal; processing is not', () {
      expect(Generation.fromJson({'id': 'a', 'status': 'refunded'}).isTerminal,
          true);
      expect(Generation.fromJson({'id': 'b', 'status': 'failed'}).isTerminal,
          true);
      expect(
          Generation.fromJson({'id': 'c', 'status': 'processing'}).isTerminal,
          false);
    });
  });

  group('StoreProduct', () {
    test('total credits include bonus', () {
      final p = StoreProduct.fromJson({
        'product_id': 'credits_120',
        'credits': 120,
        'title': 'Popular',
        'bonus': 10
      });
      expect(p.totalCredits, 130);
    });
  });
}

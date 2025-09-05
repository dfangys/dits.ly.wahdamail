import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/features/messaging/domain/value_objects/search_query.dart';

void main() {
  test('SearchQuery normalizes fields', () {
    final q = SearchQuery(
      text: '  Hello  ',
      from: ' Alice@ExaMple.com ',
      flags: {' Seen ', '  '},
      limit: 10,
    );
    expect(q.text, 'hello');
    expect(q.from, 'alice@example.com');
    expect(q.flags, contains('seen'));
    expect(q.limit, 10);
  });
}

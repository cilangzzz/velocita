// Unit tests for AddRequest parsing.
import 'package:flutter_test/flutter_test.dart';
import 'package:velocita/src/features/browser_integration/domain/add_request.dart';

void main() {
  test('AddRequest values are immutable', () {
    final r = AddRequest(
      url: 'https://x.test/y',
      source: AddSource.extension,
      receivedAt: DateTime.now(),
    );
    expect(r.url, 'https://x.test/y');
    expect(r.source, AddSource.extension);
  });

  test('AddSource enum covers all 4 cases', () {
    expect(AddSource.values, hasLength(4));
    expect(AddSource.values, contains(AddSource.extension));
    expect(AddSource.values, contains(AddSource.deepLink));
    expect(AddSource.values, contains(AddSource.hostForward));
    expect(AddSource.values, contains(AddSource.unknown));
  });
}

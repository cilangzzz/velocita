// Basic smoke test — verifies the kernel provider throws when unoverridden
// (which is the contract for "not bootstrapped yet").
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:velocita/src/kernel_bridge/kernel_provider.dart';

void main() {
  testWidgets('kernelProvider throws when not bootstrapped', (tester) async {
    final container = ProviderContainer();
    expect(
      () => container.read(kernelProvider),
      throwsA(isA<UnimplementedError>()),
    );
    container.dispose();
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'kernel_bootstrap.dart';

/// Riverpod handle to the bootstrapped [KernelFacade].
///
/// Overridden in `main()` once bootstrap completes — every `ref.read(...)`
/// downstream is a cheap lookup.
final kernelProvider = Provider<KernelFacade>((ref) {
  throw UnimplementedError(
    'kernelProvider was read before bootstrapKernel() finished.',
  );
});

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

/// Riverpod handle to the [AppDatabase] living on the [KernelFacade].
///
/// Same override-in-main.dart pattern as [kernelProvider]. Exposed as
/// its own provider so notifiers can `ref.read(appDatabaseProvider)`
/// without each one having to know about the facade shape.
final appDatabaseProvider = Provider((ref) {
  return ref.read(kernelProvider).appDatabase;
});

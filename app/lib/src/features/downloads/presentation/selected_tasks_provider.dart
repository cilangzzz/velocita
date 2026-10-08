import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Gids of tasks the user has checked via the leading checkbox column.
/// Lives at module scope so the table (which writes via row taps) and
/// the toolbar (which reads to power batch ops) can share state without
/// prop-drilling.
final selectedTaskGidsProvider = StateProvider<Set<String>>((ref) => <String>{});

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/constants.dart';
import '../providers/mock_mode_provider.dart';

/// Refuses the handful of operations that must not run against demo data.
///
/// Demo mode is deliberately writable everywhere else — that is what makes it a
/// usable test bed. The exceptions are operations that cross the boundary
/// between the demo and the real world, where "it worked" would be a lie:
///
/// - **Exporting a backup** would write a file that looks exactly like a real
///   one but contains fabricated entries. Restoring it later — in real mode —
///   would merge those entries into the actual journal. That is the one way
///   demo data can reach real storage, and this is what closes it.
/// - **Importing or restoring a backup** would write into the in-memory store
///   and vanish on restart, so a user restoring real data during a demo would
///   watch it disappear and reasonably conclude the backup was lost.
///
/// Device-level settings are *not* guarded here. They are routed to real
/// storage instead (see `platformStorageServiceProvider`), which makes them
/// correct rather than merely blocked.
class MockModeGuard {
  const MockModeGuard._();

  /// True when demo mode is on, after telling the user why [operation] did not
  /// run. Call it as an early return:
  ///
  /// ```dart
  /// if (MockModeGuard.blocks(context, ref, operation: 'Backups')) return;
  /// ```
  static bool blocks(
    BuildContext context,
    WidgetRef ref, {
    required String operation,
  }) {
    if (!ref.read(mockModeProvider)) return false;

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '$operation is unavailable while demo data is on — it would act on '
            'sample entries, not your own. Turn demo data off first.',
          ),
          backgroundColor: AppColors.amber500,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    return true;
  }
}

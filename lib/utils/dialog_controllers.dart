import 'package:flutter/widgets.dart';

/// Runs [body], then clears and disposes every controller in [controllers].
///
/// Dialog-scoped [TextEditingController]s are easy to leak: they are created in
/// an `async` method, handed to a `TextField`, and then simply go out of scope
/// when the dialog pops. Each one is a [ChangeNotifier] that stays registered
/// for the lifetime of the process, so every open of the dialog leaks another.
///
/// Clearing before disposing matters on the credential dialogs, whose buffers
/// hold PIN digits and recovery answers in plaintext — leaving those in the
/// heap indefinitely is a secrets-lifetime problem, not just a memory one.
///
/// The `finally` is what makes this reliable: disposal still happens if [body]
/// returns early or throws.
Future<T> withDisposedControllers<T>(
  List<TextEditingController> controllers,
  Future<T> Function() body,
) async {
  try {
    return await body();
  } finally {
    for (final controller in controllers) {
      controller.clear();
      controller.dispose();
    }
  }
}

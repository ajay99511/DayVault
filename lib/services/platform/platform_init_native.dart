import '../objectbox_service.dart' as obx;
import 'platform_init_stub.dart';
export 'platform_init_stub.dart' show InitResult, PlatformInitOutcome;

/// Native platform initialization — delegates to [obx.ObjectBoxService] and
/// maps the result to platform-agnostic types.
Future<PlatformInitOutcome> platformInit() async {
  final outcome = await obx.ObjectBoxService.init();
  return PlatformInitOutcome(
    _mapResult(outcome.result),
    backupPath: outcome.backupPath,
    errorMessage: outcome.errorMessage,
  );
}

InitResult _mapResult(obx.InitResult r) {
  switch (r) {
    case obx.InitResult.success:
      return InitResult.success;
    case obx.InitResult.migrationRequired:
      return InitResult.migrationRequired;
    case obx.InitResult.fatalError:
      return InitResult.fatalError;
  }
}

/// Re-initialize ObjectBox after user grants consent to discard the old
/// database. Wraps [obx.ObjectBoxService.reinitializeAfterConsent].
Future<void> platformReinitializeAfterConsent(String backupPath) async {
  await obx.ObjectBoxService.reinitializeAfterConsent(backupPath);
}

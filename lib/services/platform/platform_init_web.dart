import 'platform_init_stub.dart';
export 'platform_init_stub.dart' show InitResult, PlatformInitOutcome;

/// Web platform initialization.
///
/// No database initialization is needed on web — all persistence is handled
/// by [WebStorageService] via `window.localStorage`.
Future<PlatformInitOutcome> platformInit() async {
  return const PlatformInitOutcome(InitResult.success);
}

/// No-op on web — there is no local database to reinitialize.
Future<void> platformReinitializeAfterConsent(String backupPath) async {
  // Nothing to do on web.
}

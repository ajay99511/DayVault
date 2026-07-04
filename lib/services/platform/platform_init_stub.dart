enum InitResult { success, migrationRequired, fatalError }

class PlatformInitOutcome {
  final InitResult result;
  final String? backupPath;
  final String? errorMessage;
  const PlatformInitOutcome(this.result, {this.backupPath, this.errorMessage});
}

Future<PlatformInitOutcome> platformInit() {
  throw UnsupportedError('No platform implementation available.');
}

Future<void> platformReinitializeAfterConsent(String backupPath) {
  throw UnsupportedError('No platform implementation available.');
}

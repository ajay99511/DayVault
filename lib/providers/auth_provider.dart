import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_provider.g.dart';

/// App-global authentication state (true once the vault is unlocked).
///
/// keepAlive: this is session-wide state that must survive transient periods
/// with no listeners (e.g. the brief loading frame in RootOrchestrator before
/// it starts watching), so it must not auto-dispose.
@Riverpod(keepAlive: true)
class AuthState extends _$AuthState {
  @override
  bool build() => false;

  void authenticate() => state = true;

  void unauthenticate() => state = false;
}

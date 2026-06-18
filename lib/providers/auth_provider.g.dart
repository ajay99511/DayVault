// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// App-global authentication state (true once the vault is unlocked).
///
/// keepAlive: this is session-wide state that must survive transient periods
/// with no listeners (e.g. the brief loading frame in RootOrchestrator before
/// it starts watching), so it must not auto-dispose.

@ProviderFor(AuthState)
final authStateProvider = AuthStateProvider._();

/// App-global authentication state (true once the vault is unlocked).
///
/// keepAlive: this is session-wide state that must survive transient periods
/// with no listeners (e.g. the brief loading frame in RootOrchestrator before
/// it starts watching), so it must not auto-dispose.
final class AuthStateProvider extends $NotifierProvider<AuthState, bool> {
  /// App-global authentication state (true once the vault is unlocked).
  ///
  /// keepAlive: this is session-wide state that must survive transient periods
  /// with no listeners (e.g. the brief loading frame in RootOrchestrator before
  /// it starts watching), so it must not auto-dispose.
  AuthStateProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'authStateProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$authStateHash();

  @$internal
  @override
  AuthState create() => AuthState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$authStateHash() => r'502aed6e90a884cfe58071dcf63efe0caee69288';

/// App-global authentication state (true once the vault is unlocked).
///
/// keepAlive: this is session-wide state that must survive transient periods
/// with no listeners (e.g. the brief loading frame in RootOrchestrator before
/// it starts watching), so it must not auto-dispose.

abstract class _$AuthState extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<bool, bool>, bool, Object?, Object?>;
    element.handleCreate(ref, build);
  }
}

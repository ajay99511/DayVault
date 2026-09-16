/// Storage service barrel file.
///
/// Re-exports the platform-agnostic [StorageService] interface and provides
/// the [storageServiceProvider] that resolves to the correct platform
/// implementation at compile time via conditional imports.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

// Re-export everything consumers need from the interface
export 'storage/storage_service_interface.dart';

// Conditional import picks the right factory at compile time
import 'storage/storage_factory_stub.dart'
    if (dart.library.ffi) 'storage/storage_factory_native.dart'
    if (dart.library.js_interop) 'storage/storage_factory_web.dart';

import 'storage/storage_service_interface.dart';

/// An alternative backend to serve instead of the platform one, or null to use
/// the platform one.
///
/// This is the single seam through which mock ("demo") mode replaces the whole
/// storage layer. It is declared here, next to the thing it substitutes, but
/// deliberately left inert: the default is null and this file knows nothing
/// about demo mode. The app root supplies the real implementation via
/// `mockModeOverrides()` in `lib/mock/mock_mode_scope.dart`.
///
/// Declaring the seam rather than having this file reach into `providers/`
/// keeps the dependency arrow pointing the right way — presentation and
/// feature code depend on services, never the reverse — so the storage layer
/// stays compilable and testable with no knowledge that demo mode exists.
final storageBackendOverrideProvider = Provider<StorageService?>((ref) => null);

/// The real, on-device backend — never substituted, not even by demo mode.
///
/// [NativeStorageService] backed by ObjectBox on Android, iOS, Windows, macOS
/// and Linux; `WebStorageService` backed by localStorage on web. The choice is
/// made at compile time by the conditional import above.
///
/// **Read through this, not [storageServiceProvider], for anything that is a
/// fact about the device rather than about journal content** — whether the app
/// is PIN-locked, whether biometrics are enrolled, which theme the user picked.
/// Those answers must not change when demo mode is switched on, and writes to
/// them must not land in a store that is discarded on restart.
///
/// The app lock is the case that makes this non-negotiable. Reading
/// `securityEnabled` through [storageServiceProvider] meant demo mode's
/// `securityEnabled: false` satisfied the launch gate, so a demo-mode install
/// started with no PIN prompt — and the user could then switch demo mode off
/// and read the real journal without ever entering the PIN.
final platformStorageServiceProvider = Provider<StorageService>((ref) {
  return createPlatformStorageService();
});

/// Provides the [StorageService] journal **content** is read and written
/// through.
///
/// Resolves to [storageBackendOverrideProvider] when something has supplied an
/// alternative backend (demo mode does), and otherwise to
/// [platformStorageServiceProvider].
///
/// Because the override is *watched*, switching demo mode on or off rebuilds
/// this provider and hands every consumer the other backend. While demo mode is
/// on the platform backend is never read or written through here at all, so
/// fabricated data can neither reach the real journal nor be mistaken for it.
final storageServiceProvider = Provider<StorageService>((ref) {
  return ref.watch(storageBackendOverrideProvider) ??
      ref.watch(platformStorageServiceProvider);
});

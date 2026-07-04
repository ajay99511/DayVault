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

/// Provides the platform-appropriate [StorageService] implementation.
///
/// On native platforms (Android, iOS, Windows, macOS, Linux) this resolves to
/// [NativeStorageService] backed by ObjectBox. On web it resolves to
/// [WebStorageService] backed by localStorage.
final storageServiceProvider = Provider<StorageService>((ref) {
  return createPlatformStorageService();
});

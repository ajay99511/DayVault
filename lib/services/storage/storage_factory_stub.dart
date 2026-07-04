import 'storage_service_interface.dart';

StorageService createPlatformStorageService() {
  throw UnsupportedError(
    'Cannot create StorageService without a platform implementation.',
  );
}

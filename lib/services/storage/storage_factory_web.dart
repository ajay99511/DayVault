import 'storage_service_interface.dart';
import 'web_storage_service.dart';

StorageService createPlatformStorageService() {
  return WebStorageService();
}

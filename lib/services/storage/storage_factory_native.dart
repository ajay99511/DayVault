import 'storage_service_interface.dart';
import 'native_storage_service.dart';
import '../objectbox_service.dart';

StorageService createPlatformStorageService() {
  return NativeStorageService(ObjectBoxService.instance.store);
}

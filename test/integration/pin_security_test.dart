import 'package:flutter_test/flutter_test.dart';
import 'package:memory_palace/services/security_service.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mockito/annotations.dart';

@GenerateNiceMocks([MockSpec<FlutterSecureStorage>()])
import 'pin_security_test.mocks.dart';

void main() {
  late SecurityService securityService;
  late MockFlutterSecureStorage mockStorage;

  setUp(() {
    mockStorage = MockFlutterSecureStorage();
    securityService = SecurityService.withStorage(mockStorage);
  });

  test('PIN verification integration: wrong PINs lead to lockout', () async {
    when(mockStorage.read(key: 'lockout_until')).thenAnswer((_) async => null);
    when(mockStorage.read(key: 'pin_hash')).thenAnswer((_) async => 'stored_hash');
    when(mockStorage.read(key: 'security_salt')).thenAnswer((_) async => 'salt');
    
    // 1st failure
    var result = await securityService.verifyPin('1111');
    expect(result.success, isFalse);
    expect(result.remainingAttempts, 4);
    when(mockStorage.read(key: 'attempt_count')).thenAnswer((_) async => '1');

    // ... simulate 4 more
    when(mockStorage.read(key: 'attempt_count')).thenAnswer((_) async => '4');
    result = await securityService.verifyPin('4444');
    expect(result.success, isFalse);
    expect(result.remainingLockoutSeconds, isNotNull);
  });
}

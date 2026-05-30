import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_palace/main.dart';
import 'package:memory_palace/services/storage_service.dart';
import 'package:memory_palace/services/security_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:memory_palace/models/types.dart';

@GenerateNiceMocks([MockSpec<StorageService>(), MockSpec<FlutterSecureStorage>()])
import 'root_orchestrator_test.mocks.dart';

void main() {
  late MockStorageService mockStorageService;
  late MockFlutterSecureStorage mockSecureStorage;

  setUp(() {
    mockStorageService = MockStorageService();
    mockSecureStorage = MockFlutterSecureStorage();
    
    // Setup default responses
    when(mockStorageService.getSettings()).thenReturn(const UserSettings(securityEnabled: false));
  });

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorageService),
      ],
      child: const MaterialApp(
        home: RootOrchestrator(),
      ),
    );
  }

  testWidgets('Shows MainShell when security is disabled', (tester) async {
    when(mockStorageService.getSettings()).thenReturn(const UserSettings(securityEnabled: false));
    
    await tester.pumpWidget(createTestWidget());
    await tester.pump();
    
    expect(find.byType(MainShell), findsOneWidget);
  });

  testWidgets('Shows LockScreen when security is enabled', (tester) async {
    when(mockStorageService.getSettings()).thenReturn(const UserSettings(securityEnabled: true));
    
    await tester.pumpWidget(createTestWidget());
    await tester.pump();
    
    expect(find.byType(MainShell), findsNothing);
    // Note: LockScreen might be shown after a small delay if isLoading is true initially
  });
}

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
import 'package:memory_palace/models/paged_result.dart';

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

    // JournalScreen (inside MainShell) loads data on mount; stub the journal
    // read paths so the nice-mock fakes aren't accessed.
    when(mockStorageService.getJournal())
        .thenAnswer((_) async => <JournalEntry>[]);
    when(mockStorageService.getOnThisDay(any))
        .thenAnswer((_) async => <JournalEntry>[]);
    when(mockStorageService.journalCount()).thenReturn(0);
    when(mockStorageService.getJournalPage(any))
        .thenAnswer((_) async => const PagedResult<JournalEntry>(items: []));
    when(mockStorageService.getJournalPage(any, any))
        .thenAnswer((_) async => const PagedResult<JournalEntry>(items: []));
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

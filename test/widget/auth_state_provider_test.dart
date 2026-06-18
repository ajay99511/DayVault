import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_palace/main.dart';
import 'package:memory_palace/providers/auth_provider.dart';
import 'package:memory_palace/services/storage_service.dart';
import 'package:mockito/mockito.dart';
import 'package:memory_palace/models/types.dart';

import 'root_orchestrator_test.mocks.dart';

void main() {
  // ─── 7.6* authStateProvider isolation widget test ────────────────────────
  group('authStateProvider isolation', () {
    testWidgets('only widgets watching authStateProvider rebuild on change',
        (tester) async {
      var authBuilds = 0;
      var otherBuilds = 0;
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Column(
              children: [
                Consumer(builder: (c, ref, _) {
                  authBuilds++;
                  final authed = ref.watch(authStateProvider);
                  return Text('authed=$authed',
                      textDirection: TextDirection.ltr);
                }),
                Builder(builder: (c) {
                  otherBuilds++;
                  return const SizedBox.shrink();
                }),
              ],
            ),
          ),
        ),
      );

      expect(authBuilds, 1);
      final otherBaseline = otherBuilds;
      expect(find.text('authed=false'), findsOneWidget);

      // Flip auth state.
      container.read(authStateProvider.notifier).authenticate();
      await tester.pump();

      // The watcher rebuilt; the unrelated sibling did not.
      expect(authBuilds, 2);
      expect(otherBuilds, otherBaseline);
      expect(find.text('authed=true'), findsOneWidget);
    });

    testWidgets('toggling the provider drives RootOrchestrator lock/unlock',
        (tester) async {
      final mockStorage = MockStorageService();
      // Security enabled -> RootOrchestrator should start locked (no MainShell).
      when(mockStorage.getSettings())
          .thenReturn(const UserSettings(securityEnabled: true));

      final container = ProviderContainer(
        overrides: [storageServiceProvider.overrideWithValue(mockStorage)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: RootOrchestrator()),
        ),
      );
      await tester.pump();

      expect(find.byType(MainShell), findsNothing);

      // Simulate a successful unlock by flipping the shared auth provider.
      container.read(authStateProvider.notifier).authenticate();
      await tester.pump();

      expect(find.byType(MainShell), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_palace/models/types.dart';
import 'package:memory_palace/screens/entry_editor.dart';

/// Pumps [child] inside a minimal Material host.
Future<void> _host(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
  );
}

void main() {
  // ─── 7.4* EntryEditor sub-widget isolation / behavior ────────────────────
  group('MoodSelector', () {
    testWidgets('reports the tapped mood', (tester) async {
      Mood? picked;
      await _host(
        tester,
        MoodSelector(selected: Mood.happy, onChanged: (m) => picked = m),
      );

      // Tap the euphoric emoji.
      await tester.tap(find.text('🤩'));
      expect(picked, Mood.euphoric);
    });
  });

  group('SpotlightToggle', () {
    testWidgets('flips the value when tapped', (tester) async {
      bool? next;
      await _host(
        tester,
        SpotlightToggle(value: false, onChanged: (v) => next = v),
      );

      await tester.tap(find.text('Spotlight this memory'));
      expect(next, true);
    });
  });

  group('TagPicker', () {
    testWidgets('adds a typed tag and renders a chip', (tester) async {
      // Controlled component: host owns the list.
      var tags = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => TagPicker(
                tags: tags,
                onChanged: (t) => setState(() => tags = t),
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'travel');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(tags, ['travel']);
      expect(find.byType(Chip), findsOneWidget);
      expect(find.text('travel'), findsOneWidget);
    });

    testWidgets('ignores duplicate tags (case-insensitive)', (tester) async {
      var tags = <String>['Travel'];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => TagPicker(
                tags: tags,
                onChanged: (t) => setState(() => tags = t),
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'travel');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(tags, ['Travel']); // unchanged
    });

    testWidgets('removes a tag when its chip delete is tapped', (tester) async {
      var tags = <String>['a', 'b'];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => TagPicker(
                tags: tags,
                onChanged: (t) => setState(() => tags = t),
              ),
            ),
          ),
        ),
      );

      // Each chip exposes a delete (close) icon.
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pump();

      expect(tags, ['b']);
    });
  });
}

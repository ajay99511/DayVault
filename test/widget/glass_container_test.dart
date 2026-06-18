import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_palace/widgets/glass_widgets.dart';

void main() {
  // ─── 4.2* Property test — blur clamping invariant ────────────────────────
  group('GlassContainer.clampBlur property', () {
    test('result is always within [minBlur, maxBlur]', () {
      final rng = Random(1234);
      for (var i = 0; i < 1000; i++) {
        // Sample a wide range incl. out-of-bounds and extreme values.
        final raw = (rng.nextDouble() * 200) - 50; // [-50, 150)
        final clamped = GlassContainer.clampBlur(raw);
        expect(clamped, greaterThanOrEqualTo(GlassContainer.minBlur));
        expect(clamped, lessThanOrEqualTo(GlassContainer.maxBlur));
      }
    });

    test('values already in range are returned unchanged (idempotent)', () {
      final rng = Random(99);
      for (var i = 0; i < 200; i++) {
        final inRange = GlassContainer.minBlur +
            rng.nextDouble() * (GlassContainer.maxBlur - GlassContainer.minBlur);
        expect(GlassContainer.clampBlur(inRange), inRange);
        // Double application is a no-op.
        expect(
          GlassContainer.clampBlur(GlassContainer.clampBlur(inRange)),
          GlassContainer.clampBlur(inRange),
        );
      }
    });

    test('out-of-range extremes snap to the bounds', () {
      expect(GlassContainer.clampBlur(-1000), GlassContainer.minBlur);
      expect(GlassContainer.clampBlur(0), GlassContainer.minBlur);
      expect(GlassContainer.clampBlur(1000), GlassContainer.maxBlur);
    });
  });

  // ─── 4.3* Widget test — RepaintBoundary placement ────────────────────────
  group('GlassContainer RepaintBoundary placement', () {
    testWidgets(
        'wraps the BackdropFilter in a RepaintBoundary when backdrop is enabled',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassContainer(
              useBackdropFilter: true,
              child: SizedBox(width: 10, height: 10),
            ),
          ),
        ),
      );

      final backdrop = find.byType(BackdropFilter);
      expect(backdrop, findsOneWidget);

      // A RepaintBoundary must be an ancestor of the BackdropFilter so the blur
      // is isolated into its own compositing layer.
      final boundaryAboveBackdrop = find.ancestor(
        of: backdrop,
        matching: find.byType(RepaintBoundary),
      );
      expect(boundaryAboveBackdrop, findsWidgets);
    });

    testWidgets('does not build a BackdropFilter when backdrop is disabled',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassContainer(
              child: SizedBox(width: 10, height: 10),
            ),
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsNothing);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_palace/main.dart';

/// Regression guard for the "nav pill floats in the middle of the screen and
/// blocks content" bug.
///
/// Root cause was wrapping the pill in a bare `Center`/`Align` (no
/// heightFactor): Scaffold measures `bottomNavigationBar` with a loose,
/// full-height constraint, so such a widget expands to the FULL screen height
/// and vertically centers the pill. The fix pins the Align with
/// `heightFactor: 1.0` so the bar hugs its child.
void main() {
  const screenHeight = 800.0;

  Future<void> pumpNav(WidgetTester tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(size: Size(400, screenHeight)),
        child: MaterialApp(
          home: Scaffold(
            extendBody: true,
            body: SizedBox.expand(),
            bottomNavigationBar: GlassNavBar(currentIndex: 0, onTap: _noop),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('nav bar hugs its content height, not the full screen',
      (tester) async {
    tester.view.physicalSize = const Size(400, screenHeight);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpNav(tester);

    final navSize = tester.getSize(find.byType(GlassNavBar));
    // A real pill is well under ~140px tall. If the regression returns it
    // balloons to ~screenHeight.
    expect(navSize.height, lessThan(200),
        reason: 'Nav bar should wrap the pill, not expand to full height');
  });

  testWidgets('nav bar is anchored to the bottom of the screen',
      (tester) async {
    tester.view.physicalSize = const Size(400, screenHeight);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpNav(tester);

    final bottom = tester.getBottomLeft(find.byType(GlassNavBar)).dy;
    expect(bottom, moreOrLessEquals(screenHeight, epsilon: 1.0),
        reason: 'Nav bar bottom edge should sit at the screen bottom');
  });
}

void _noop(int _) {}

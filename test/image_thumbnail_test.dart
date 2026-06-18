import 'package:flutter_test/flutter_test.dart';
import 'package:memory_palace/widgets/image_widgets.dart';

void main() {
  int r(double? size, double dpr, {double fallback = 400}) =>
      ImageThumbnailWidget.resolveCacheDimension(size, dpr,
          fallbackLogical: fallback);

  // ─── 12.5* ImageThumbnailWidget cache-dimension / fallback ───────────────
  group('ImageThumbnailWidget.resolveCacheDimension', () {
    test('scales logical size by device pixel ratio', () {
      expect(r(100, 1.0), 100);
      expect(r(100, 2.0), 200);
      expect(r(100, 3.0), 300);
    });

    test('falls back to the fallback when size is missing/invalid', () {
      expect(r(null, 2.0, fallback: 300), 600); // 300 * 2
      expect(r(0, 2.0, fallback: 300), 600);
      expect(r(-50, 2.0, fallback: 300), 600);
      expect(r(double.infinity, 1.0, fallback: 250), 250);
    });

    test('guards against a non-positive / non-finite dpr (treated as 1.0)', () {
      expect(r(120, 0), 120);
      expect(r(120, -2), 120);
      expect(r(120, double.nan), 120);
    });

    test('result is always a positive int within [1, 4096]', () {
      expect(r(0.1, 0.1), greaterThanOrEqualTo(1));
      expect(r(10000, 4.0), 4096); // clamped
      expect(r(2000, 3.0), 4096); // 6000 -> clamped
    });

    test('rounds up (ceil) fractional pixels so we never under-decode', () {
      expect(r(100, 1.5), 150);
      expect(r(33, 1.0), 33);
      expect(r(33.2, 1.0), 34);
    });
  });
}

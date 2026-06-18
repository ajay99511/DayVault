import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_palace/utils/idle_timer.dart';

void main() {
  // ─── 4.6* LockScreen idle timer ──────────────────────────────────────────
  group('IdleTimer', () {
    test('fires onIdle once after a full quiet period', () {
      fakeAsync((async) {
        var fired = 0;
        final t = IdleTimer(
          timeout: const Duration(seconds: 5),
          onIdle: () => fired++,
        );

        t.poke();
        async.elapse(const Duration(seconds: 4)); // not yet
        expect(fired, 0);
        expect(t.isActive, isTrue);

        async.elapse(const Duration(seconds: 1)); // 5s reached
        expect(fired, 1);
        expect(t.isActive, isFalse);
      });
    });

    test('each poke restarts the countdown (activity keeps it alive)', () {
      fakeAsync((async) {
        var fired = 0;
        final t = IdleTimer(
          timeout: const Duration(seconds: 5),
          onIdle: () => fired++,
        );

        // Poke every 4s for a long time — it should never fire.
        for (var i = 0; i < 10; i++) {
          t.poke();
          async.elapse(const Duration(seconds: 4));
        }
        expect(fired, 0);

        // Now go quiet — it fires exactly once.
        async.elapse(const Duration(seconds: 5));
        expect(fired, 1);
      });
    });

    test('cancel prevents onIdle from firing', () {
      fakeAsync((async) {
        var fired = 0;
        final t = IdleTimer(
          timeout: const Duration(seconds: 5),
          onIdle: () => fired++,
        );

        t.poke();
        async.elapse(const Duration(seconds: 2));
        t.cancel();
        async.elapse(const Duration(seconds: 10));

        expect(fired, 0);
        expect(t.isActive, isFalse);
      });
    });
  });
}

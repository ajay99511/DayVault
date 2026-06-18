import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_palace/utils/debouncer.dart';

void main() {
  // ─── 7.2* Search debounce idempotence ────────────────────────────────────
  group('Debouncer', () {
    test('a burst of rapid calls fires the action exactly once', () {
      fakeAsync((async) {
        final d = Debouncer(delay: const Duration(milliseconds: 300));
        var count = 0;
        var last = '';

        // 50 rapid "keystrokes", each 10ms apart (< 300ms debounce window).
        for (var i = 0; i < 50; i++) {
          d.run(() {
            count++;
            last = 'k$i';
          });
          async.elapse(const Duration(milliseconds: 10));
        }

        // Nothing has fired yet — the window keeps resetting.
        expect(count, 0);

        // Let the window close.
        async.elapse(const Duration(milliseconds: 300));

        // Exactly one fire, and it carries the LAST scheduled action.
        expect(count, 1);
        expect(last, 'k49');
        expect(d.isActive, isFalse);
      });
    });

    test('settled value is stable — re-running with same value is idempotent',
        () {
      fakeAsync((async) {
        final d = Debouncer(delay: const Duration(milliseconds: 300));
        var value = '';

        d.run(() => value = 'hello');
        async.elapse(const Duration(milliseconds: 300));
        expect(value, 'hello');

        // Running the identical action again produces the same settled state.
        d.run(() => value = 'hello');
        async.elapse(const Duration(milliseconds: 300));
        expect(value, 'hello');
      });
    });

    test('separated calls each fire (beyond the debounce window)', () {
      fakeAsync((async) {
        final d = Debouncer(delay: const Duration(milliseconds: 300));
        var count = 0;

        d.run(() => count++);
        async.elapse(const Duration(milliseconds: 300));
        d.run(() => count++);
        async.elapse(const Duration(milliseconds: 300));

        expect(count, 2);
      });
    });

    test('cancel prevents a pending action from firing', () {
      fakeAsync((async) {
        final d = Debouncer(delay: const Duration(milliseconds: 300));
        var fired = false;

        d.run(() => fired = true);
        async.elapse(const Duration(milliseconds: 100));
        d.cancel();
        async.elapse(const Duration(milliseconds: 500));

        expect(fired, isFalse);
        expect(d.isActive, isFalse);
      });
    });
  });
}

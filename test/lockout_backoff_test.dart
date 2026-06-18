import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_palace/config/constants.dart';
import 'package:memory_palace/services/security_service.dart';

void main() {
  const base = SecurityConstants.lockoutDurationSeconds;
  const cap = SecurityConstants.maxLockoutDurationSeconds;
  int f(int cycle) => SecurityService.computeLockoutDurationSeconds(cycle);

  // ─── 11.6* Lockout duration formula property test ────────────────────────
  group('computeLockoutDurationSeconds — properties', () {
    test('always within [base, cap]', () {
      final rng = Random(2026);
      for (var i = 0; i < 2000; i++) {
        final cycle = rng.nextInt(100000) - 10; // includes negatives
        final d = f(cycle);
        expect(d, greaterThanOrEqualTo(base));
        expect(d, lessThanOrEqualTo(cap));
      }
    });

    test('monotonically non-decreasing in cycle count', () {
      var prev = f(0);
      for (var cycle = 1; cycle <= 60; cycle++) {
        final cur = f(cycle);
        expect(cur, greaterThanOrEqualTo(prev),
            reason: 'cycle $cycle regressed: $cur < $prev');
        prev = cur;
      }
    });

    test('doubles each cycle until the cap is hit', () {
      // While under the cap, each step should be exactly 2x the previous.
      var cycle = 1;
      var cur = f(cycle);
      while (true) {
        final next = f(cycle + 1);
        if (next >= cap) break;
        expect(next, cur * 2);
        cur = next;
        cycle++;
        if (cycle > 50) fail('cap never reached');
      }
    });
  });

  // ─── 11.7* Exponential backoff edge cases ────────────────────────────────
  group('computeLockoutDurationSeconds — edge cases', () {
    test('cycle <= 1 returns the base (first-offense backwards compat)', () {
      expect(f(1), base);
      expect(f(0), base);
      expect(f(-5), base);
    });

    test('known early-cycle values', () {
      expect(f(2), base * 2);
      expect(f(3), base * 4);
      expect(f(4), base * 8);
    });

    test('large cycle counts saturate at the cap (no overflow)', () {
      expect(f(1000), cap);
      expect(f(1 << 30), cap);
      expect(f(9223372036854775807), cap); // int max
    });
  });
}

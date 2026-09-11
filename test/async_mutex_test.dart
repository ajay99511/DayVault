
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_palace/utils/async_mutex.dart';

void main() {
  group('AsyncMutex', () {
    test('runs queued actions strictly one at a time', () async {
      final mutex = AsyncMutex();
      final events = <String>[];

      Future<void> slow(String name, int ms) => mutex.run(() async {
            events.add('$name-start');
            await Future<void>.delayed(Duration(milliseconds: ms));
            events.add('$name-end');
          });

      // Deliberately queue the slowest first: without the lock, 'b' and 'c'
      // would start before 'a' finished and the ends would interleave.
      await Future.wait([slow('a', 30), slow('b', 1), slow('c', 1)]);

      expect(events, [
        'a-start', 'a-end',
        'b-start', 'b-end',
        'c-start', 'c-end',
      ]);
    });

    test('preserves request order', () async {
      final mutex = AsyncMutex();
      final order = <int>[];
      await Future.wait([
        for (var i = 0; i < 10; i++)
          mutex.run(() async {
            await Future<void>.delayed(Duration(milliseconds: 10 - i));
            order.add(i);
          }),
      ]);
      expect(order, List.generate(10, (i) => i));
    });

    test('a read-modify-write sequence cannot lose an update', () async {
      // This is the draft-index scenario in miniature. Each task reads the
      // shared list, yields, then writes back — the classic lost-update shape.
      final mutex = AsyncMutex();
      var shared = <int>[];

      Future<void> append(int value) => mutex.run(() async {
            final snapshot = List<int>.from(shared);
            await Future<void>.delayed(const Duration(milliseconds: 5));
            shared = [...snapshot, value];
          });

      await Future.wait([for (var i = 0; i < 20; i++) append(i)]);

      expect(shared.length, 20, reason: 'every append must survive');
      expect(shared.toSet().length, 20);
    });

    test('without the mutex the same sequence does lose updates', () async {
      // Pins the premise: proves the test above is measuring the lock and not
      // an accident of scheduling.
      var shared = <int>[];

      Future<void> append(int value) async {
        final snapshot = List<int>.from(shared);
        await Future<void>.delayed(const Duration(milliseconds: 5));
        shared = [...snapshot, value];
      }

      await Future.wait([for (var i = 0; i < 20; i++) append(i)]);

      expect(shared.length, lessThan(20),
          reason: 'unsynchronised read-modify-write must drop updates');
    });

    test('returns each action result to its own caller', () async {
      final mutex = AsyncMutex();
      final results = await Future.wait([
        mutex.run(() async => 'first'),
        mutex.run(() async => 'second'),
      ]);
      expect(results, ['first', 'second']);
    });

    test('a failing action does not wedge the queue', () async {
      final mutex = AsyncMutex();

      final failing = mutex.run<int>(() async => throw StateError('boom'));
      final following = mutex.run<int>(() async => 42);

      await expectLater(failing, throwsStateError);
      expect(await following, 42,
          reason: 'later work must still run after an earlier failure');
    });

    test('reports how much work is outstanding', () async {
      final mutex = AsyncMutex();
      expect(mutex.pending, 0);

      final work = mutex.run(() => Future<void>.delayed(
            const Duration(milliseconds: 20),
          ));
      expect(mutex.pending, 1);

      await work;
      expect(mutex.pending, 0);
    });
  });
}

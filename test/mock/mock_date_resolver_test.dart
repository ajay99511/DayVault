import 'package:flutter_test/flutter_test.dart';
import 'package:memory_palace/mock/mock_date_resolver.dart';

void main() {
  // A leap-year reference. Several assertions below only fail against a
  // Duration-based implementation when a 29 February sits in the interval.
  final reference = DateTime(2024, 3, 10, 14, 30);
  final resolver = MockDateResolver(reference: reference);

  DateTime dateOf(Object? token) =>
      DateTime.parse(resolver.resolve(token) as String);

  group(r'$date', () {
    test('defaults to 09:00 on the reference day', () {
      expect(dateOf({r'$date': <String, dynamic>{}}), DateTime(2024, 3, 10, 9));
    });

    test('applies day offsets and an explicit wall clock', () {
      expect(
        dateOf({
          r'$date': {'days': -3, 'hour': 21, 'minute': 40}
        }),
        DateTime(2024, 3, 7, 21, 40),
      );
    });

    test('a year offset keeps the same month and day across a leap year', () {
      // The reason for calendar-field arithmetic. 10 March 2024 minus 365 days
      // is 11 March 2023 — one day off — which would quietly stop matching
      // "On this day".
      final lastYear = dateOf({
        r'$date': {'years': -1}
      });
      expect(lastYear.month, reference.month);
      expect(lastYear.day, reference.day);
      expect(lastYear.year, reference.year - 1);
    });

    test('month offsets normalise across a year boundary', () {
      expect(
        dateOf({
          r'$date': {'months': -4}
        }),
        DateTime(2023, 11, 10, 9),
      );
    });

    test('offsets compose', () {
      expect(
        dateOf({
          r'$date': {'years': -1, 'months': 2, 'days': 5, 'hour': 8}
        }),
        DateTime(2023, 5, 15, 8),
      );
    });
  });

  group(r'$year', () {
    test('resolves to an int, not a string', () {
      expect(
        resolver.resolve({
          r'$year': {'years': 0}
        }),
        2024,
      );
      expect(
        resolver.resolve({
          r'$year': {'years': -1}
        }),
        2023,
      );
    });
  });

  group('traversal', () {
    test('rewrites tokens nested in lists and maps, leaving the rest alone', () {
      final resolved = resolver.resolve({
        'id': 'x',
        'rank': 3,
        'nested': {
          'date': {
            r'$date': {'days': -1, 'hour': 0}
          }
        },
        'history': [
          {
            'date': {
              r'$date': {'days': -2, 'hour': 0}
            },
            'rank': 1
          },
        ],
      }) as Map<String, dynamic>;

      expect(resolved['id'], 'x');
      expect(resolved['rank'], 3);
      expect(resolved['nested']['date'], DateTime(2024, 3, 9).toIso8601String());
      expect((resolved['history'] as List).first['date'],
          DateTime(2024, 3, 8).toIso8601String());
    });

    test('leaves literal ISO dates untouched', () {
      expect(resolver.resolve({'date': '2020-01-01T00:00:00.000'}),
          {'date': '2020-01-01T00:00:00.000'});
    });

    test('does not mutate its input', () {
      final input = <String, dynamic>{
        'date': {
          r'$date': {'days': -1}
        }
      };
      resolver.resolve(input);
      expect(input['date'], isA<Map>());
    });
  });

  group('malformed tokens fail loudly', () {
    // Fixtures are source code. A typo must stop the load, not silently
    // resolve to "now" and produce a demo nobody can explain.
    test('unknown offset field', () {
      expect(
        () => resolver.resolve({
          r'$date': {'weeks': -1}
        }),
        throwsA(isA<MockDateTokenException>()),
      );
    });

    test('non-integer offset', () {
      expect(
        () => resolver.resolve({
          r'$date': {'days': '-1'}
        }),
        throwsA(isA<MockDateTokenException>()),
      );
    });

    test('token is not an object', () {
      expect(
        () => resolver.resolve({r'$date': '-1d'}),
        throwsA(isA<MockDateTokenException>()),
      );
    });

    test('token shares its object with other keys', () {
      expect(
        () => resolver.resolve({
          r'$date': {'days': -1},
          'hour': 9,
        }),
        throwsA(isA<MockDateTokenException>()),
      );
    });

    test('a document that is not a JSON object', () {
      expect(
        () => resolver.resolveDocument(<dynamic>[], source: 'test.json'),
        throwsA(isA<MockDateTokenException>()),
      );
    });
  });
}

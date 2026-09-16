/// Resolves the relative-date tokens used by the mock fixtures.
///
/// Fixtures must stay interesting forever: a demo whose newest entry is dated
/// two years ago shows a broken streak, an empty 12-week chart and no "On this
/// day" memories. Hardcoding absolute dates guarantees that decay, so the
/// fixtures express *when relative to launch* an item happened and this
/// resolver turns that into the concrete values the models deserialize from.
///
/// Two tokens are recognised anywhere in a decoded fixture tree:
///
/// ```json
/// { "$date": { "days": -2, "hour": 21, "minute": 15 } }  // → ISO-8601 String
/// { "$year": { "years": 0 } }                            // → int
/// ```
///
/// `$date` accepts `years`, `months`, `days` (calendar offsets, any sign) plus
/// `hour`/`minute` (absolute wall-clock, defaulting to 09:00). Offsets are
/// applied to the *calendar* fields rather than by adding a [Duration], so
/// `years: -1` lands on the same month and day one year earlier — which is
/// exactly what "On this day" matches on. Adding `Duration(days: 365)` would
/// drift by a day across a leap year and silently break that surface.
///
/// Everything else passes through untouched, so a fixture is free to use a
/// literal `"2024-03-01T09:00:00.000"` when a fixed date is the point.
library;

/// Thrown when a fixture contains a malformed relative-date token. Mock data is
/// developer-authored, so a bad token is a bug to fix, never something to
/// paper over with a fallback date.
class MockDateTokenException implements Exception {
  final String message;
  const MockDateTokenException(this.message);

  @override
  String toString() => 'MockDateTokenException: $message';
}

class MockDateResolver {
  /// Wall-clock instant every relative token is measured from.
  final DateTime reference;

  MockDateResolver({DateTime? reference})
      : reference = reference ?? DateTime.now();

  static const String dateToken = r'$date';
  static const String yearToken = r'$year';

  /// Recursively replace every relative token in [node] with its concrete
  /// value, returning a new tree. The input is never mutated.
  Object? resolve(Object? node) {
    if (node is List) return node.map(resolve).toList();
    if (node is! Map) return node;

    final map = Map<String, dynamic>.from(node);
    if (map.containsKey(dateToken)) {
      _rejectExtraKeys(map, dateToken);
      return _resolveDate(_argsOf(map[dateToken], dateToken))
          .toIso8601String();
    }
    if (map.containsKey(yearToken)) {
      _rejectExtraKeys(map, yearToken);
      return _resolveDate(_argsOf(map[yearToken], yearToken)).year;
    }

    return map.map((key, value) => MapEntry(key, resolve(value)));
  }

  /// Resolve a whole fixture document, asserting it decodes to a JSON object.
  Map<String, dynamic> resolveDocument(Object? decoded, {required String source}) {
    final resolved = resolve(decoded);
    if (resolved is! Map<String, dynamic>) {
      throw MockDateTokenException(
          '$source must contain a JSON object at its root.');
    }
    return resolved;
  }

  DateTime _resolveDate(Map<String, dynamic> args) {
    final years = _intArg(args, 'years');
    final months = _intArg(args, 'months');
    final days = _intArg(args, 'days');
    final hour = _intArg(args, 'hour', fallback: 9);
    final minute = _intArg(args, 'minute');

    final unknown =
        args.keys.toSet().difference({'years', 'months', 'days', 'hour', 'minute'});
    if (unknown.isNotEmpty) {
      throw MockDateTokenException(
          'Unknown relative-date field(s): ${unknown.join(', ')}.');
    }

    // DateTime normalises out-of-range calendar fields (month 14 → next
    // February, day 0 → last day of the previous month), so the offsets can be
    // applied directly to the components.
    return DateTime(
      reference.year + years,
      reference.month + months,
      reference.day + days,
      hour,
      minute,
    );
  }

  static Map<String, dynamic> _argsOf(Object? raw, String token) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    throw MockDateTokenException('"$token" must map to a JSON object.');
  }

  static void _rejectExtraKeys(Map<String, dynamic> map, String token) {
    if (map.length > 1) {
      throw MockDateTokenException(
          'A "$token" token must be the only key in its object; '
          'found ${map.keys.join(', ')}.');
    }
  }

  static int _intArg(Map<String, dynamic> args, String key, {int fallback = 0}) {
    final value = args[key];
    if (value == null) return fallback;
    if (value is int) return value;
    throw MockDateTokenException('"$key" must be an integer, got $value.');
  }
}

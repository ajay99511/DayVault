import 'package:flutter_test/flutter_test.dart';
import 'package:memory_palace/models/types.dart';
import 'package:memory_palace/screens/journal_screen.dart';

JournalEntry _e(
  String id, {
  String headline = '',
  String content = '',
  List<String> tags = const [],
  bool spotlight = false,
}) =>
    JournalEntry(
      id: id,
      type: EntryType.story,
      date: DateTime(2025, 1, 1),
      headline: headline,
      content: content,
      mood: Mood.happy,
      tags: tags,
      isSpotlight: spotlight,
    );

List<String> _ids(List<JournalEntry> es) => es.map((e) => e.id).toList();

void main() {
  // ─── 7.8* Spotlight + tag filter logic ───────────────────────────────────
  group('JournalScreen.filterEntries', () {
    final entries = [
      _e('1', headline: 'Beach day', tags: ['travel', 'summer'], spotlight: true),
      _e('2', content: 'Great food', tags: ['food']),
      _e('3', headline: 'Work', tags: ['travel'], spotlight: true),
      _e('4', headline: 'Nothing tagged'),
    ];

    test('no filters returns everything', () {
      expect(_ids(JournalScreen.filterEntries(entries)), ['1', '2', '3', '4']);
    });

    test('spotlightOnly keeps only spotlighted entries', () {
      expect(
        _ids(JournalScreen.filterEntries(entries, spotlightOnly: true)),
        ['1', '3'],
      );
    });

    test('query matches headline, content, or tags (case-insensitive)', () {
      expect(_ids(JournalScreen.filterEntries(entries, query: 'BEACH')), ['1']);
      expect(_ids(JournalScreen.filterEntries(entries, query: 'food')), ['2']);
      // 'travel' only appears as a tag on 1 and 3.
      expect(
          _ids(JournalScreen.filterEntries(entries, query: 'travel')), ['1', '3']);
    });

    test('selectedTags keeps entries with any selected tag (OR, case-insensitive)',
        () {
      expect(
        _ids(JournalScreen.filterEntries(entries, selectedTags: {'TRAVEL'})),
        ['1', '3'],
      );
      expect(
        _ids(JournalScreen.filterEntries(entries,
            selectedTags: {'food', 'summer'})),
        ['1', '2'],
      );
    });

    test('filters compose (AND across filter kinds)', () {
      // spotlight AND tag travel AND query 'beach' -> only entry 1.
      expect(
        _ids(JournalScreen.filterEntries(
          entries,
          spotlightOnly: true,
          selectedTags: {'travel'},
          query: 'beach',
        )),
        ['1'],
      );
      // spotlight AND tag food -> entry 2 is not spotlight -> empty.
      expect(
        JournalScreen.filterEntries(entries,
            spotlightOnly: true, selectedTags: {'food'}),
        isEmpty,
      );
    });

    test('blank/whitespace query is treated as no query', () {
      expect(_ids(JournalScreen.filterEntries(entries, query: '   ')),
          ['1', '2', '3', '4']);
    });
  });

  group('JournalScreen.availableTags', () {
    test('returns distinct tags sorted case-insensitively', () {
      final entries = [
        _e('1', tags: ['Travel', 'food']),
        _e('2', tags: ['apple', 'travel']), // dup 'travel' (diff case)
        _e('3'),
      ];
      // 'Travel' first-seen casing preserved; deduped against 'travel'.
      expect(JournalScreen.availableTags(entries), ['apple', 'food', 'Travel']);
    });

    test('empty when no tags', () {
      expect(JournalScreen.availableTags([_e('1')]), isEmpty);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_palace/models/types.dart';

/// Pins the declaration order of every enum that is persisted **by ordinal**.
///
/// `ObjectBoxJournalEntry` stores `type`, `mood` and `timeBucket` as integer
/// indices, and both the backup format and the autosaved draft format do the
/// same. That makes the order of these declarations a storage format, not a
/// stylistic choice: inserting a value anywhere but the end silently reassigns
/// the meaning of every row already on disk — every "happy" entry could become
/// "productive" with no error anywhere.
///
/// These tests exist so that change fails loudly in CI instead of quietly in
/// users' journals. If one fails, the correct response is almost never to
/// update the expected list: it is to append the new value at the end, or to
/// migrate the stored data deliberately.
void main() {
  group('persisted enum ordinals must not be reordered', () {
    test('Mood', () {
      expect(Mood.values.map((v) => v.name).toList(), const [
        'euphoric',
        'happy',
        'productive',
        'neutral',
        'tired',
        'sad',
        'anxious',
        'angry',
        'excited',
        'relaxed',
        'social',
        'bored',
        'creative',
      ]);
    });

    test('EntryType', () {
      expect(EntryType.values.map((v) => v.name).toList(), const [
        'story',
        'event',
      ]);
    });

    test('TimeBucket', () {
      expect(TimeBucket.values.map((v) => v.name).toList(), const [
        'midnight',
        'earlyMorning',
        'morning',
        'afternoon',
        'evening',
        'night',
      ]);
    });

    test('ImageSourceType', () {
      // Stored by *name* inside ImageReference JSON rather than by ordinal, but
      // pinned too: the name is equally load-bearing for stored data.
      expect(ImageSourceType.values.map((v) => v.name).toList(), const [
        'galleryAsset',
        'webUrl',
        'filePath',
      ]);
    });
  });
}

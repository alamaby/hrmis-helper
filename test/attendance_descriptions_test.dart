import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:codex_auto_attend/core/attendance_descriptions.dart';

void main() {
  group('kAttendanceDescriptions', () {
    test('has exactly 30 bilingual entries', () {
      expect(kAttendanceDescriptions.length, 30);
      for (final entry in kAttendanceDescriptions) {
        expect(entry.english, isNotEmpty);
        expect(entry.indonesian, isNotEmpty);
      }
    });

    test('entries are safe to splice into a single-quoted JS string', () {
      for (final entry in kAttendanceDescriptions) {
        for (final text in [entry.english, entry.indonesian]) {
          expect(text, isNot(contains("'")), reason: '$text must not use apostrophes');
          expect(text, isNot(contains(r'\')), reason: '$text must not use backslashes');
          expect(text, isNot(contains('\n')), reason: '$text must not span lines');
          expect(text, isNot(contains('\r')), reason: '$text must not span lines');
          expect(text, text.trim(),
              reason: '$text must not have leading/trailing whitespace');
        }
      }
    });

    test('keeps the original Indonesian description as one entry', () {
      expect(
        kAttendanceDescriptions.any((entry) => entry.indonesian == 'Bismillah, semangat bekerja!'),
        isTrue,
      );
    });
  });

  group('pickRandomAttendanceDescription', () {
    final pool = kAttendanceDescriptions
        .expand((entry) => [entry.english, entry.indonesian])
        .toSet();

    test('always returns a member of the pool', () {
      for (var seed = 0; seed < 50; seed += 1) {
        final picked = pickRandomAttendanceDescription(Random(seed));
        expect(pool.contains(picked), isTrue, reason: 'Unexpected pick: $picked');
      }
    });

    test('is deterministic for the same seeded Random', () {
      final first = pickRandomAttendanceDescription(Random(1));
      final second = pickRandomAttendanceDescription(Random(1));
      expect(first, second);
    });

    test('varies picks across seeds and uses both languages', () {
      final rng = Random(7);
      final picks = <String>{
        for (var i = 0; i < 1000; i += 1) pickRandomAttendanceDescription(rng),
      };

      expect(picks.length, greaterThan(1));

      final englishPicks = picks
          .intersection(kAttendanceDescriptions.map((e) => e.english).toSet());
      final indonesianPicks = picks
          .intersection(kAttendanceDescriptions.map((e) => e.indonesian).toSet());

      expect(englishPicks, isNotEmpty);
      expect(indonesianPicks, isNotEmpty);
    });
  });
}

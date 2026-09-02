// Tests for the Icelandic system prompt builder.

import 'package:flutter_test/flutter_test.dart';

import 'package:embla/assistant/prompt.dart';

void main() {
  group('formatIcelandicDateTime', () {
    test('formats in Icelandic words', () {
      // 2026-09-02 is a Wednesday.
      expect(
        formatIcelandicDateTime(DateTime.utc(2026, 9, 2, 14, 35)),
        'miðvikudagur 2. september 2026, 14:35',
      );
      expect(
        formatIcelandicDateTime(DateTime.utc(2026, 1, 4, 9, 5)),
        'sunnudagur 4. janúar 2026, 09:05',
      );
    });

    test('converts to Atlantic/Reykjavik, which is UTC', () {
      // 15:20 in UTC+2 is 13:20 in Iceland.
      final DateTime local =
          DateTime.parse('2026-09-02T15:20:00+02:00');
      expect(formatIcelandicDateTime(local), 'miðvikudagur 2. september 2026, 13:20');
    });

    test('has a name for every weekday and month', () {
      expect(kIcelandicWeekdays.length, 7);
      expect(kIcelandicMonths.length, 12);
      for (int m = 1; m <= 12; m++) {
        expect(formatIcelandicDateTime(DateTime.utc(2026, m, 15, 0, 0)),
            contains(kIcelandicMonths[m - 1]));
      }
    });
  });

  group('buildSystemPrompt', () {
    final DateTime now = DateTime.utc(2026, 9, 2, 14, 35);

    test('states identity, time and platform', () {
      final String p = buildSystemPrompt(now: now, platform: 'ios');
      expect(p, contains('Þú ert Embla, íslensk raddaðstoðarkona frá Miðeind'));
      expect(p, contains('miðvikudagur 2. september 2026, 14:35'));
      expect(p, contains('Atlantic/Reykjavik'));
      expect(p, contains('iPhone (iOS)'));
      expect(p, isNot(contains('Android')));
    });

    test('mentions the Android platform when running on Android', () {
      final String p = buildSystemPrompt(now: now, platform: 'android');
      expect(p, contains('Android-tæki'));
      expect(p, isNot(contains('iPhone')));
    });

    test('includes coordinates when the location is known', () {
      final String p = buildSystemPrompt(
        now: now,
        platform: 'ios',
        location: [64.1466, -21.9426],
      );
      expect(p, contains('64.1466'));
      expect(p, contains('-21.9426'));
      expect(p, isNot(contains('Staðsetning notandans er óþekkt')));
    });

    test('says the location is unknown when it is missing', () {
      final String p = buildSystemPrompt(now: now, platform: 'android');
      expect(p, contains('Staðsetning notandans er óþekkt'));
    });

    test('suppresses the location in private mode', () {
      final String p = buildSystemPrompt(
        now: now,
        platform: 'ios',
        location: [64.1466, -21.9426],
        privateMode: true,
      );
      expect(p, isNot(contains('64.1466')));
      expect(p, contains('Huliðsstilling'));
    });

    test('lists tools and gives greynir_query guidance', () {
      final String p = buildSystemPrompt(
        now: now,
        platform: 'ios',
        toolNames: const ['greynir_query', 'get_datetime', 'get_location', 'open_url'],
      );
      expect(p, contains('greynir_query'));
      expect(p, contains('get_datetime'));
      expect(p, contains('veðurspár'));
      expect(p, contains('valid=false'));
      expect(p, contains('Búðu ALDREI til niðurstöður úr verkfærum'));
    });

    test('notes the absence of tools', () {
      final String p = buildSystemPrompt(now: now, platform: 'ios');
      expect(p, contains('engin verkfæri'));
      expect(p, isNot(contains('greynir_query')));
    });

    test('carries the MVP action rules', () {
      final String p = buildSystemPrompt(now: now, platform: 'ios');
      expect(p, contains('fyrstu persónu'));
      expect(p, contains('ISO 8601'));
      expect(p, contains('ein klukkustund'));
      expect(p, contains('niðurteljari'));
      expect(p, contains('vekjari'));
    });

    test('describes the reply contract', () {
      final String p = buildSystemPrompt(now: now, platform: 'ios');
      for (final String field in ['kind', 'speech', 'display']) {
        expect(p, contains(field));
      }
      for (final String kind in ['answer', 'action_done', 'clarify', 'unknown']) {
        expect(p, contains(kind));
      }
      expect(p, contains('bókstöfum'));
    });
  });
}

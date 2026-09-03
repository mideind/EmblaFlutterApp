// Matching spoken Icelandic names, which arrive declined, against the
// address book, where they are stored in the nominative.

import 'package:flutter_test/flutter_test.dart';

import 'package:embla/tools/contact_match.dart';

ContactCandidate c(String name, [String? phone]) => ContactCandidate(
    displayName: name, phoneNumbers: phone == null ? const <String>[] : <String>[phone]);

void main() {
  group('tokensMatch', () {
    test('accepts suffixal declension, which is how Icelandic inflects names', () {
      // The case from live testing: spoken "Kára Steini", stored "Kári Steinn".
      expect(tokensMatch('kara', 'kari'), isTrue);
      expect(tokensMatch('steini', 'steinn'), isTrue);
      expect(tokensMatch('mariu', 'maria'), isTrue);
      expect(tokensMatch('gudrunu', 'gudrun'), isTrue);
    });

    test('rejects names that merely start alike', () {
      expect(tokensMatch('sigurdur', 'sigrun'), isFalse);
      expect(tokensMatch('jon', 'jonatan'), isFalse);
      expect(tokensMatch('ka', 'kari'), isFalse, reason: 'stem shorter than 3');
    });

    test('does not pretend to handle stem-vowel changes', () {
      // "Anna" -> "Önnu" asciifies to anna/onnu, which share no prefix. This
      // is a documented limitation, not an accident.
      expect(tokensMatch('onnu', 'anna'), isFalse);
    });
  });

  group('matchContact', () {
    test('resolves the declined name from live testing', () {
      final res = matchContact('Kára Steini', [c('Kári Steinn', '5551234'), c('Jón Jónsson')]);
      expect(res, isA<ContactResolved>());
      expect((res as ContactResolved).contact.displayName, 'Kári Steinn');
    });

    test('a first name alone still resolves', () {
      final res = matchContact('Kára', [c('Kári Steinn', '5551234')]);
      expect((res as ContactResolved).contact.displayName, 'Kári Steinn');
    });

    test('every spoken token must match, so a wrong surname does not resolve', () {
      expect(matchContact('Kára Jóns', [c('Kári Steinn', '5551234')]), isA<ContactNotFound>());
    });

    test('an exact match outranks an inflected one', () {
      final res = matchContact('María', [c('Maríus', '111'), c('María', '222')]);
      expect((res as ContactResolved).contact.displayName, 'María');
    });

    test('a contact with a number beats an identically named one without', () {
      final res = matchContact('Anna', [c('Anna'), c('Anna', '5559999')]);
      expect((res as ContactResolved).contact.phoneNumbers, ['5559999']);
    });

    test('two equally good matches ask rather than guess', () {
      // Messaging the wrong person is worse than a clarifying question.
      final res = matchContact('Jón', [c('Jón Jónsson', '111'), c('Jón Sigurðsson', '222')]);
      expect(res, isA<ContactAmbiguous>());
      expect((res as ContactAmbiguous).candidates, hasLength(2));
    });

    test('no contacts, or no name, is not a match', () {
      expect(matchContact('Kára', const []), isA<ContactNotFound>());
      expect(matchContact('   ', [c('Kári Steinn')]), isA<ContactNotFound>());
    });

    test('punctuation and case in stored names do not matter', () {
      final res = matchContact('kara steini', [c('Kári  Steinn', '111')]);
      expect(res, isA<ContactResolved>());
    });
  });
}

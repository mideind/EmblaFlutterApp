/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2026 Miðeind ehf. <mideind@mideind.is>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

// Matching a spoken Icelandic name against the address book.
//
// People decline names when they speak: "sendu Kára Steini" refers to the
// contact stored as "Kári Steinn". Equality fails, and so does a substring
// search -- "Kára" does not contain "Kári". Icelandic declension is almost
// entirely suffixal, so comparing stems rather than whole words handles the
// common cases.

import '../util.dart' show asciifyIcelandic;

/// The parts of a contact that matter for matching.
class ContactCandidate {
  final String displayName;
  final List<String> phoneNumbers;
  const ContactCandidate({required this.displayName, this.phoneNumbers = const <String>[]});
}

/// Outcome of resolving a spoken name.
sealed class ContactMatch {
  const ContactMatch();
}

class ContactResolved extends ContactMatch {
  final ContactCandidate contact;
  const ContactResolved(this.contact);
}

/// Several contacts fit equally well. Messaging the wrong person is worse than
/// asking, so the caller should ask rather than pick.
class ContactAmbiguous extends ContactMatch {
  final List<ContactCandidate> candidates;
  const ContactAmbiguous(this.candidates);
}

class ContactNotFound extends ContactMatch {
  const ContactNotFound();
}

/// Normalized name tokens: ASCII, lower case, punctuation dropped.
List<String> nameTokens(String name) {
  return asciifyIcelandic(name)
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((String t) => t.isNotEmpty)
      .toList(growable: false);
}

/// Whether two normalized tokens are plausibly the same name in different
/// cases. Requires a shared stem of at least three characters, with at most
/// two characters differing after it.
///
/// Known limitation: this only handles suffixal declension. Names whose stem
/// vowel changes ("Anna" -> "Önnu") will not match, because after asciifying
/// they share no prefix at all.
bool tokensMatch(String a, String b) {
  if (a == b) return true;
  final int max = a.length < b.length ? a.length : b.length;
  int stem = 0;
  while (stem < max && a.codeUnitAt(stem) == b.codeUnitAt(stem)) {
    stem++;
  }
  if (stem < 3) return false;
  return (a.length - stem) <= 2 && (b.length - stem) <= 2;
}

/// Resolves [spokenName] against [contacts].
///
/// Every token of the spoken name must match a token of the contact's name, so
/// "Kára" alone still matches "Kári Steinn" while "Kára Jóns" does not. Exact
/// token matches outrank inflected ones, and a contact with no phone number
/// never wins over one that has a number.
ContactMatch matchContact(String spokenName, List<ContactCandidate> contacts) {
  final List<String> spoken = nameTokens(spokenName);
  if (spoken.isEmpty || contacts.isEmpty) {
    return const ContactNotFound();
  }

  ({ContactCandidate contact, int score})? best;
  final List<ContactCandidate> tied = <ContactCandidate>[];

  for (final ContactCandidate c in contacts) {
    final List<String> theirs = nameTokens(c.displayName);
    if (theirs.isEmpty) continue;

    int score = 0;
    bool allMatched = true;
    for (final String s in spoken) {
      if (theirs.contains(s)) {
        // An exact token is stronger evidence than an inflected one.
        score += 2;
      } else if (theirs.any((String t) => tokensMatch(s, t))) {
        score += 1;
      } else {
        allMatched = false;
        break;
      }
    }
    if (!allMatched) continue;

    // Prefer a contact we can actually send to.
    if (c.phoneNumbers.isNotEmpty) score += 1;
    // A name that matches in full beats one that merely contains the tokens.
    if (theirs.length == spoken.length) score += 1;

    if (best == null || score > best.score) {
      best = (contact: c, score: score);
      tied
        ..clear()
        ..add(c);
    } else if (score == best.score) {
      tied.add(c);
    }
  }

  if (best == null) return const ContactNotFound();
  if (tied.length > 1) return ContactAmbiguous(List<ContactCandidate>.unmodifiable(tied));
  return ContactResolved(best.contact);
}

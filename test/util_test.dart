// These are the tests for the project's utility
// functions and custom class extensions.

import 'package:test/test.dart';
import 'package:flutter/material.dart';

import 'package:embla/util.dart';

void main() {
  testUtil();
}

void testUtil() {
  test('Strings should have first character capitalized', () {
    const List<String> ts = [
      "mikið er þetta gaman",
      "HVAÐ ER EIGINLEGA Í GANGI?",
      "The rain in Spain stays mainly in the plain",
      "iT's by no means possible",
    ];
    for (String s in ts) {
      expect(s[0].toUpperCase() == s.sentenceCapitalized()[0], true);
    }
  });

  // Ratatoskur's /rat/v2/tts rejects non-ASCII voice names: sending "Guðrún"
  // makes the origin answer 504, which surfaced as "Villa við talgervingu"
  // for every spoken reply.
  test('asciifyIcelandic transliterates the TTS voice names the server takes', () {
    expect(asciifyIcelandic('Guðrún'), 'Gudrun');
    expect(asciifyIcelandic('Gunnar'), 'Gunnar');
    // Already-ASCII input is untouched, so double-asciifying is safe.
    expect(asciifyIcelandic(asciifyIcelandic('Guðrún')), 'Gudrun');
  });

  test('asciifyIcelandic covers every Icelandic character', () {
    expect(asciifyIcelandic('áéíóúýðþæöÁÉÍÓÚÝÐÞÆÖ'), 'aeiouydthaeoAEIOUYDTHAEO');
    // ASCII letters and punctuation pass through unchanged.
    expect(asciifyIcelandic('abc XYZ 123 -_.'), 'abc XYZ 123 -_.');
  });

  // Color extensions
  test('Color should be correctly generated from hex string', () {
    const Map<String, Color> colors = {
      "#ffffff": Colors.white,
      "#000000": Colors.black,
      //"#ff0000": Colors.red,
    };
    colors.forEach((k, v) {
      expect(HexColor.fromHex(k), v);
    });
  });
}

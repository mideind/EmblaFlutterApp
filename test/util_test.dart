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

// These are the tests for the project's utility
// functions and custom class extensions.

import 'package:test/test.dart';
import 'package:flutter/material.dart';

import 'package:embla/util.dart';

void main() {
  testUtil();
}

void testUtil() {
  // String extensions
  test('Strings should be identified as punctuation-terminated', () {
    final List<String> term = [
      "Þetta var nú gaman!",
      "Hver ert þú?",
      "Hann fór út.",
      "Sjáldan er góð vísa of oft kveðin.“",
      '"This is not great."',
      "'The rain in spain stays mainly in the plain.'",
      "Hann fór út í búð?",
      "Klukkan 16:44!",
      "'Engilbert Humperdink var maðurinn.'",
      '"Ei skal höggva."',
      "Þetta er setning...",
      "Og þetta er önnur setning…",
    ];
    for (String s in term) {
      expect(s.isPunctuationTerminated(), true);
    }
  });

  test('Strings should be identified as NOT punctuation-terminated', () {
    final List<String> nt = [
      "Hann fór út í búð",
      "Klukkan 16:44",
      "'Engilbert Humperdink var maðurinn'",
      '"Ei skal höggva"',
      "",
    ];
    for (String s in nt) {
      expect(s.isPunctuationTerminated(), false);
    }
  });

  test('Strings should be period-terminated', () {
    final List<String> nt = [
      "Hann fór út í búð",
      "Klukkan 16:44",
      "'Engilbert Humperdink var maðurinn'",
      '"Ei skal höggva"',
    ];
    for (String s in nt) {
      expect(s.periodTerminated(), "$s.");
    }
  });

  test('Strings should have first character capitalized', () {
    final List<String> ts = [
      "mikið er þetta gaman",
      "HVAÐ ER EIGINLEGA Í GANGI?",
      "The rain in Spain stays mainly in the plain",
      "iT's by no means possible",
    ];
    for (String s in ts) {
      expect(s[0].toUpperCase() == s.sentenceCapitalized()[0], true);
    }
  });

  test('Strings should be asciified', () {
    final Map<String, String> m = {
      "mikið er þetta gaman": "mikid er thetta gaman",
      "HVAÐ ER EIGINLEGA Í GANGI?": "HVAD ER EIGINLEGA I GANGI?",
      "Örnólfur Gyrðir Möðvarsson": "Ornolfur Gyrdir Modvarsson"
    };
    m.forEach((k, v) {
      String s = k.asciify();
      expect(s == v, true);
    });
  });

  // Color extensions
  test('Color should be correctly generated from hex string', () {
    final Map<String, Color> colors = {
      "#ffffff": Colors.white,
      "#000000": Colors.black,
      //"#ff0000": Colors.red,
    };
    colors.forEach((k, v) {
      expect(HexColor.fromHex(k), v);
    });
  });
}

/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2020-2023 Miðeind ehf. <mideind@mideind.is>
 * Original author: Sveinbjorn Thordarson
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

// Various utility functions and custom class extensions

import 'dart:convert';

import 'package:flutter/material.dart' show Color;

import './keys.dart' show serverAPIKey, openAIAPIKey, elevenLabsAPIKey, anthropicAPIKey;

/// String extensions
extension StringExtension on String {
  // Return string with first character capitalized.
  // Why isn't this part of of the standard library?
  String sentenceCapitalized() {
    if (length == 0) {
      return this;
    }
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

/// Color extensions
extension HexColor on Color {
  // Get standard Flutter Color object from hex string in the
  // format "aabbcc", with an optional leading "#".
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) {
      buffer.write('ff');
    }
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}

// Cache of decoded API keys, keyed by their base64 representation
final Map<String, String> _keyCache = {};

/// Decode (and cache) a base64-encoded API key from the generated keys file.
/// Returns an empty string if no key was baked into the build.
String readKey(String b64) {
  if (b64.isEmpty) {
    return '';
  }
  return _keyCache[b64] ??= utf8.decode(base64.decode(b64)).trim();
}

/// Read and cache Ratatoskur server key
String readServerAPIKey() => readKey(serverAPIKey);

/// Read and cache OpenAI API key
String readOpenAIAPIKey() => readKey(openAIAPIKey);

/// Read and cache ElevenLabs API key
String readElevenLabsAPIKey() => readKey(elevenLabsAPIKey);

/// Read and cache Anthropic API key
String readAnthropicAPIKey() => readKey(anthropicAPIKey);

/// Transliterate Icelandic characters to ASCII.
///
/// Ratatoskur's TTS service (/rat/v2/tts) rejects non-ASCII voice names with a
/// 504 from the origin, so "Guðrún" has to go over the wire as "Gudrun".
/// EmblaCore does the same thing for its bundled audio assets, but does not
/// export its helper.
String asciifyIcelandic(String s) {
  const Map<String, String> icechar2ascii = {
    "ð": "d", "Ð": "D", "á": "a", "Á": "A", "ú": "u", "Ú": "U",
    "í": "i", "Í": "I", "é": "e", "É": "E", "þ": "th", "Þ": "TH",
    "ó": "o", "Ó": "O", "ý": "y", "Ý": "Y", "ö": "o", "Ö": "O",
    "æ": "ae", "Æ": "AE",
  };
  String out = s;
  icechar2ascii.forEach((k, v) => out = out.replaceAll(k, v));
  return out;
}

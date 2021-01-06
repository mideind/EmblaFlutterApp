/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2020 Miðeind ehf. <mideind@mideind.is>
 * Author: Sveinbjorn Thordarson
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

import 'package:flutter/material.dart';

import './keys.dart' show googleServiceAccount, queryAPIKey;

// String extensions
extension StringExtension on String {
  // Does string end w. standard punctuation?
  bool isPunctuationTerminated() {
    if (this.length == 0) {
      return false;
    }
    List<String> punc = ['.', '?', '!', '."', '.“', ".'"];
    for (String p in punc) {
      if (this.endsWith(p)) {
        return true;
      }
    }
    return false;
  }

  // Return period-terminated string if not already ending w. punctuation
  String periodTerminated() {
    if (this.length >= 0 && this.isPunctuationTerminated() == false) {
      return this + '.';
    }
    return this;
  }

  // Return string with first character capitalized.
  // Why isn't this part of of the standard library?
  String sentenceCapitalized() {
    if (this.length == 0) {
      return this;
    }
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}

extension HexColor on Color {
  // Get standard Flutter Color object from hex string in the
  // format "aabbcc" or "ffaabbcc", with an optional leading "#".
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) {
      buffer.write('ff');
    }
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}

String _googleServiceAccount = '';

// Read and cache Google API service account config JSON
String readGoogleServiceAccount() {
  if (_googleServiceAccount == '') {
    _googleServiceAccount = utf8.decode(base64.decode(googleServiceAccount));
  }
  return _googleServiceAccount;
}

String _queryAPIKey = '';

// Read and cache query server key
String readQueryServerKey() {
  if (_queryAPIKey == '') {
    _queryAPIKey = utf8.decode(base64.decode(queryAPIKey));
  }
  return _queryAPIKey;
}

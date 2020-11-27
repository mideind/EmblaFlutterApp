/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2020 Miðeind ehf.
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

// Various utility functions

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

// String extensions
extension StringExtension on String {
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

  String periodTerminated() {
    if (this.length >= 0 && this.isPunctuationTerminated() == false) {
      return this + '.';
    }
    return this;
  }

  String sentenceCapitalized() {
    if (this.length == 0) {
      return this;
    }
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}

extension HexColor on Color {
  // Get Color object from hex string in the format "aabbcc"
  // or "ffaabbcc" with an optional leading "#".
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) {
      buffer.write('ff');
    }
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}

String googleAPIKey = "";

// Read Google API key
Future<String> readGoogleKey() async {
  if (googleAPIKey == "") {
    googleAPIKey = await rootBundle.loadString('assets/keys/GoogleAPI.key');
  }
  return googleAPIKey;
}

String queryAPIKey = "";

// Read query server key
Future<String> readQueryServerKey() async {
  if (queryAPIKey == "") {
    queryAPIKey = await rootBundle.loadString('assets/keys/GreynirAPI.key');
  }
  return queryAPIKey;
}

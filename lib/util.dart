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

/// Various utility functions and custom class extensions

import 'dart:convert';

import 'package:flutter/material.dart' show Color;

import './keys.dart' show serverAPIKey, queryAPIKey;

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

String _cachedServerAPIKey = '';

/// Read and cache Ratatoskur server key
String readServerAPIKey() {
  if (_cachedServerAPIKey == '') {
    _cachedServerAPIKey = utf8.decode(base64.decode(serverAPIKey)).trim();
  }
  return _cachedServerAPIKey;
}

String _cachedQueryAPIKey = '';

/// Read and cache query server key
String readQueryServerKey() {
  if (_cachedQueryAPIKey == '') {
    _cachedQueryAPIKey = utf8.decode(base64.decode(queryAPIKey)).trim();
  }
  return _cachedQueryAPIKey;
}

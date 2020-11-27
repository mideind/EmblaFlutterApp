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

// Shared constants and debug logging

import 'package:flutter/foundation.dart' show kReleaseMode;

// Debug logging
void dlog(String logStr) {
  if (kReleaseMode) {
    return;
  }
  print(logStr);
}

// Software info
const String SOFTWARE_NAME = "Embla";
const String SOFTWARE_VERSION = "1.0.0";

// Server communication
const String DEFAULT_SERVER = "https://greynir.is";
const String QUERY_API_PATH = "/query.api/v1";
const String QUERY_HISTORY_API_PATH = "/query_history.api/v1";
const String SPEECH_API_PATH = "/speech.api/v1";

// Voice speed range
const double VOICE_SPEED_MIN = 0.7;
const double VOICE_SPEED_MAX = 1.3;

// Documentation URLs
const String ABOUT_URL = "https://embla.is/about.html";
const String INSTRUCTIONS_URL = "https://embla.is/instructions.html";
const String PRIVACY_URL = "https://embla.is/privacy.html";

// Alternate query server options f. debugging
const List QUERY_SERVER_OPTIONS = [
  ['Greynir', 'https://greynir.is'],
  ['Brandur', 'http://brandur.mideind.is:5000'],
  ['Vinna', 'http://192.168.1.113:5000'],
  ['Heima', 'http://192.168.1.8:5000']
];

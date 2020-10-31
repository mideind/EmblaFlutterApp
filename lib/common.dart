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

/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2021 Miðeind ehf. <mideind@mideind.is>
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

// Global constants and debug logging

import 'package:flutter/foundation.dart' show kReleaseMode;

// Debug logging
void dlog(var msg) {
  if (kReleaseMode == false) {
    print(msg.toString());
  }
}

// Software info
const String kSoftwareName = 'Embla';
const String kSoftwareVersion = '1.1.0';

// Speech recognition settings
const String kSpeechToTextLanguage = 'is-IS';
const int kSpeechToTextMaxAlternatives = 10;
const int kAudioSampleRate = 16000;

// Server communication
const String kDefaultServer = 'https://greynir.is';
const String kDefaultSTTServer = 'speech.googleapis.com';
const String kQueryAPIPath = '/query.api/v1';
const String kQueryHistoryAPIPath = '/query_history.api/v1';
const String kSpeechAPIPath = '/speech.api/v1';

// Voice speed range
const double kVoiceSpeedMin = 0.7;
const double kVoiceSpeedMax = 1.3;

// Documentation URLs
const String kAboutURL = 'https://embla.is/about.html';
const String kInstructionsURL = 'https://embla.is/instructions.html';
const String kPrivacyURL = 'https://embla.is/privacy.html';

// Alternate query server options f. debugging
const List kQueryServerPresetOptions = [
  ['Greynir', 'https://greynir.is'],
  ['Brandur', 'http://brandur.mideind.is:5000'],
  ['Vinna', 'http://192.168.1.113:5000'],
  ['Heima', 'http://192.168.1.8:5000']
];

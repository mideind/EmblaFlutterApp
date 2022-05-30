/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2020-2022 Miðeind ehf. <mideind@mideind.is>
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

// Global constants and debug logging

import 'package:flutter/foundation.dart' show kReleaseMode;

// Software info
const String kSoftwareName = 'Embla';
const String kSoftwareAuthor = 'Miðeind ehf.';

// Hotword detection
const String kHotwordModelName = 'hae_embla.pmdl';
const double kHotwordSensitivity = 0.5;
const double kHotwordAudioGain = 1.15;
const bool kHotwordApplyFrontend = false;
const String kHotwordAssetsDirectory = 'assets/hotword';

// Speech recognition settings
const String kSpeechToTextLanguage = 'is-IS';
const int kSpeechToTextMaxAlternatives = 10;

// Audio recording settings
const int kAudioSampleRate = 16000;
const int kAudioNumChannels = 1;

// Server communication
const String kDefaultQueryServer = 'https://greynir.is';
const String kDefaultSTTServer = 'speech.googleapis.com';
const String kQueryAPIPath = '/query.api/v1';
const String kQueryHistoryAPIPath = '/query_history.api/v1';
const String kSpeechSynthesisAPIPath = '/speech.api/v1';
const String kVoiceListAPIPath = '/voices.api/v1';

// Voice speed range
const double kVoiceSpeedMin = 0.7;
const double kVoiceSpeedMax = 2.0;

// Documentation URLs
const String kAboutURL = 'https://embla.is/about.html';
const String kInstructionsURL = 'https://embla.is/instructions.html';
const String kPrivacyURL = 'https://embla.is/privacy.html';

// Alternate query server options f. debugging purposes
const List kQueryServerPresetOptions = [
  ['Greynir.is', 'https://greynir.is'],
  ['Brandur', 'http://brandur.mideind.is:5000'],
  ['Staðarnet', 'http://192.168.1.8:5000']
];

// Debug logging
void dlog(dynamic msg) {
  if (kReleaseMode == false) {
    // ignore: avoid_print
    print(msg.toString());
  }
}

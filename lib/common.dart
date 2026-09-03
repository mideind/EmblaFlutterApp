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

// Global constants and debug logging

import 'package:flutter/foundation.dart' show kDebugMode;

// Software info
// Version number is set in pubspec.yaml
const String kSoftwareName = 'Embla';
const String kSoftwareImplementation = 'Flutter';
const String kSoftwareAuthor = 'Miðeind ehf.';

// Hotword detection
const String kHotwordModelName = 'hae_embla.pmdl';
const double kHotwordSensitivity = 0.48;
const double kHotwordAudioGain = 1.08;
const bool kHotwordApplyFrontend = false;
const String kHotwordAssetsDirectory = 'assets/hotword';

// Server communication
const String kDefaultRatatoskurServer = 'https://api.greynir.is';
const String kDefaultQueryServer = 'https://greynir.is';

// ASR

// Speech synthesis
const List<String> kSpeechSynthesisVoices = ["Guðrún", "Gunnar"];
// Only these two are still served by /rat/v2/tts; Dóra and Karl now 504.
const List<String> kSpeechSynthesisDebugVoices = ["Guðrún", "Gunnar"];
const String kDefaultVoiceID = "Guðrún";
const double kDefaultVoiceSpeed = 1.0;
const double kVoiceSpeedMin = 0.7;
const double kVoiceSpeedMax = 2.0;

// Documentation URLs
const String kAboutURL = 'https://embla.is/about.html';
const String kInstructionsURL = 'https://embla.is/instructions.html';
const String kPrivacyURL = 'https://embla.is/privacy.html';

// Ratatoskur server preset options (for debugging purposes)
const List<List<String>> kRatatoskurServerPresetOptions = [
  ['API', kDefaultRatatoskurServer],
  ['Stg.', "https://staging.api.greynir.is"],
  ['Br.', 'http://brandur.mideind.is:8080'],
  ['Lókal', 'http://192.168.1.8:8080']
];

// Query server preset options (for debugging purposes)
const List<List<String>> kQueryServerPresetOptions = [
  ['Greynir', kDefaultQueryServer],
  ['Stg.', "https://staging.greynir.is"],
  ['Br.', 'http://brandur.mideind.is:5000'],
  ['Lókal', 'http://192.168.1.8:5000']
];

// Embla 2.0: LLM pipeline
const String kLongASRPath = '/long_asr/';
const String kQueryPath = '/rat/v1/query';
const String kSpeechSynthesisPath = '/rat/v2/tts';

// Reminders list that add_shopping writes to, overridable in Settings.
const String kDefaultShoppingList = 'Innkaupalisti';
// ElevenLabs is the default voice. Without keys/elevenlabs.key or a voice ID
// createTtsEngine falls back to Icespeak and logs which half is missing.
const String kDefaultTTSProvider = 'elevenlabs';
const List<List<String>> kTTSProviders = [
  ['icespeak', 'Miðeind (Icespeak)'],
  ['elevenlabs', 'ElevenLabs'],
];
const String kDefaultLLMProvider = 'openai';
const List<List<String>> kLLMProviders = [
  ['openai', 'OpenAI'],
  ['gemini', 'Gemini (hljóð beint)'],
];

const String kOpenAIResponsesURL = 'https://api.openai.com/v1/responses';
const String kDefaultOpenAIModel = 'gpt-5.6-luna';
// Gemini takes the recorded audio directly, replacing the separate ASR step.
const String kGeminiBaseURL = 'https://generativelanguage.googleapis.com/v1beta/models';
const String kDefaultGeminiModel = 'gemini-2.5-flash';

const String kElevenLabsTTSURL = 'https://api.elevenlabs.io/v1/text-to-speech';
const String kElevenLabsModel = 'eleven_v3';
// Sarah, one of the stock voices present on every ElevenLabs account.
// Overridable in Settings. An empty default here silently disabled the
// whole ElevenLabs path, since createTtsEngine() falls back to Icespeak
// when the voice ID is blank.
const String kDefaultElevenLabsVoiceID = 'EXAVITQu4vr4xnSDxMaL';

const int kMaxToolIterations = 5;
const int kMaxConversationUserTurns = 12;
const Duration kConversationIdleReset = Duration(minutes: 10);
const String kTimeZoneName = 'Atlantic/Reykjavik';

/// Debug logging
void dlog(dynamic msg) {
  if (kDebugMode) {
    // ignore: avoid_print
    print(msg.toString());
  }
}

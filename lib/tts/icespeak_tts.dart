/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2026 Miðeind ehf. <mideind@mideind.is>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

// Icespeak speech synthesis via Ratatoskur (/rat/v2/tts), played back with
// EmblaCore's AudioPlayer. Default transcription is left on so the server
// normalizes anything the model wrote as digits after all.

import 'package:embla_core/embla_core.dart'
    show AudioPlayer, EmblaAPI, SpeechOptions, TranscriptionOptions;

import '../common.dart'
    show dlog, kDefaultVoiceID, kSpeechSynthesisPath, kSpeechSynthesisVoices;
import '../util.dart' show asciifyIcelandic;
import 'tts_engine.dart';

class IcespeakTts implements TtsEngine {
  IcespeakTts({required this.serverURL, required this.apiKey, this.voice = kDefaultVoiceID});

  final String serverURL;
  final String apiKey;

  /// Icespeak voice name, e.g. "Guðrún". Also the name EmblaCore uses to pick
  /// the bundled audio assets, so it is stored with Icelandic spelling.
  final String voice;

  @override
  String get id => 'icespeak';

  @override
  List<String> get voices => kSpeechSynthesisVoices;

  @override
  Future<void> speak(
    String text, {
    required double speed,
    required void Function(bool err) onDone,
  }) async {
    // The service only accepts ASCII voice names; "Guðrún" makes the origin
    // return 504. Prefs and the bundled audio assets keep the Icelandic
    // spelling, so transliterate here, at the wire boundary.
    final String voiceID =
        asciifyIcelandic(voice.trim().isEmpty ? kDefaultVoiceID : voice);

    final String? url = await EmblaAPI.synthesizeSpeech(
      text,
      apiKey,
      ttsOptions: SpeechOptions(voice: voiceID, speed: speed),
      transcriptionOptions: TranscriptionOptions(),
      transcribe: true,
      apiURL: '$serverURL$kSpeechSynthesisPath',
    );

    if (url == null) {
      dlog('Speech synthesis failed, no audio URL returned');
      onDone(true);
      return;
    }
    await AudioPlayer().playURL(url, (bool err) => onDone(err));
  }

  @override
  void stop() {
    AudioPlayer().stop();
  }
}

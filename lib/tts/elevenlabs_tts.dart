/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2026 Miðeind ehf. <mideind@mideind.is>
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

// ElevenLabs speech synthesis engine.

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:embla_core/embla_core.dart' show AudioPlayer;

import '../common.dart';
import './tts_engine.dart';

// Maximum time to wait for the synthesis request to complete
const Duration kElevenLabsTimeout = Duration(seconds: 20);

// Audio format requested from the API
const String kElevenLabsOutputFormat = 'mp3_44100_128';

// Language enforced for the model. The API docs describe language_code as
// ISO 639-1, but the language list for the v3 models uses ISO 639-3 codes
// ("Icelandic (isl)"). Codes the model doesn't support are ignored server-side.
const String kElevenLabsLanguageCode = 'isl';

// Speech speed is only supported by the non-v3 models. Allowed range 0.25-4.0.
const double kElevenLabsSpeedMin = 0.25;
const double kElevenLabsSpeedMax = 4.0;

/// Function that plays audio at [url] and invokes [onDone] when finished.
/// Injectable so tests don't have to touch the audio player.
typedef AudioURLPlayer = void Function(String url, void Function(bool err) onDone);

/// Speech synthesis via the ElevenLabs API. The whole audio file is downloaded
/// and handed to the audio player as an RFC 2397 data URI.
class ElevenLabsTts implements TtsEngine {
  final String apiKey;
  final String voiceId;
  final String model;
  final String languageCode;
  final http.Client _client;
  final AudioURLPlayer _play;

  ElevenLabsTts({
    required this.apiKey,
    required this.voiceId,
    this.model = kElevenLabsModel,
    this.languageCode = kElevenLabsLanguageCode,
    http.Client? client,
    AudioURLPlayer? player,
  })  : _client = client ?? http.Client(),
        _play = player ?? _defaultPlayer;

  static void _defaultPlayer(String url, void Function(bool err) onDone) {
    AudioPlayer().playURL(url, onDone);
  }

  @override
  String get id => 'elevenlabs';

  @override
  List<String> get voices => [voiceId];

  // The v3 models don't support the voice_settings speed parameter
  bool get _supportsSpeed => model.startsWith('eleven_v3') == false;

  @override
  Future<void> speak(
    String text, {
    required String voice,
    required double speed,
    required void Function(bool err) onDone,
  }) async {
    // The "voice" for ElevenLabs is a voice ID. Fall back to the
    // voice ID this engine was configured with.
    final String vid = voice.isEmpty ? voiceId : voice;
    if (vid.isEmpty) {
      dlog('ElevenLabs TTS error: no voice ID configured');
      onDone(true);
      return;
    }

    final Uri url =
        Uri.parse('$kElevenLabsTTSURL/$vid?output_format=$kElevenLabsOutputFormat');

    final Map<String, dynamic> body = {
      'text': text,
      'model_id': model,
    };
    if (languageCode.isNotEmpty) {
      body['language_code'] = languageCode;
    }
    if (_supportsSpeed) {
      body['voice_settings'] = {
        'speed': speed.clamp(kElevenLabsSpeedMin, kElevenLabsSpeedMax),
      };
    }

    Uint8List bytes;
    try {
      final http.Response resp = await _client
          .post(url,
              headers: {
                'xi-api-key': apiKey,
                'Content-Type': 'application/json',
              },
              body: jsonEncode(body))
          .timeout(kElevenLabsTimeout);

      if (resp.statusCode < 200 || resp.statusCode > 299) {
        dlog('ElevenLabs TTS error, status ${resp.statusCode}: ${resp.body}');
        onDone(true);
        return;
      }
      bytes = resp.bodyBytes;
    } catch (e) {
      dlog('ElevenLabs TTS request failed: $e');
      onDone(true);
      return;
    }

    if (bytes.isEmpty) {
      dlog('ElevenLabs TTS returned no audio data');
      onDone(true);
      return;
    }

    // Hand the audio to the player as a data URI
    final String dataURL = Uri.dataFromBytes(bytes, mimeType: 'audio/mpeg').toString();
    _play(dataURL, onDone);
  }

  @override
  void stop() {
    AudioPlayer().stop();
  }
}

// Tests for the ElevenLabs speech synthesis engine.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' show MockClient;

import 'package:embla/common.dart';
import 'package:embla/tts/elevenlabs_tts.dart';

void main() {
  test('ElevenLabsTts posts expected request and plays returned audio', () async {
    http.Request? captured;
    final client = MockClient((http.Request req) async {
      captured = req;
      return http.Response.bytes([0x49, 0x44, 0x33, 0x04], 200,
          headers: {'content-type': 'audio/mpeg'});
    });

    String? playedURL;
    bool? doneErr;
    final engine = ElevenLabsTts(
      apiKey: 'testkey',
      voiceId: 'voice123',
      client: client,
      player: (String url, void Function(bool err) onDone) {
        playedURL = url;
        onDone(false);
      },
    );

    expect(engine.id, 'elevenlabs');
    expect(engine.voices, ['voice123']);

    await engine.speak('Halló heimur',
        speed: 1.0, onDone: (bool err) => doneErr = err);

    expect(captured, isNotNull);
    expect(captured!.method, 'POST');
    expect(captured!.url.toString(),
        '$kElevenLabsTTSURL/voice123?output_format=mp3_44100_128');
    expect(captured!.headers['xi-api-key'], 'testkey');
    expect(captured!.headers['Content-Type'], contains('application/json'));

    final Map<String, dynamic> body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['text'], 'Halló heimur');
    expect(body['model_id'], kElevenLabsModel);
    expect(body['language_code'], 'is');
    // The v3 models don't support the speed parameter
    expect(body.containsKey('voice_settings'), false);

    // Audio is handed to the player as a data URI
    expect(playedURL, isNotNull);
    expect(playedURL!.startsWith('data:audio/mpeg;base64,'), true);
    expect(doneErr, false);
  });

  test('ElevenLabsTts sends voice_settings speed for non-v3 models', () async {
    http.Request? captured;
    final client = MockClient((http.Request req) async {
      captured = req;
      return http.Response.bytes([0x00], 200);
    });

    final engine = ElevenLabsTts(
      apiKey: 'k',
      voiceId: 'v',
      model: 'eleven_multilingual_v2',
      languageCode: '',
      client: client,
      player: (String url, void Function(bool err) onDone) => onDone(false),
    );

    await engine.speak('Hæ', speed: 1.5, onDone: (bool err) {});

    // The engine always uses the voice ID it was configured with. It used to
    // accept a caller-supplied voice, so the Icespeak voice name reached the
    // API and came back as 400 invalid_uid.
    expect(captured!.url.path.endsWith('/v'), true);
    final Map<String, dynamic> body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body.containsKey('language_code'), false);
    expect((body['voice_settings'] as Map<String, dynamic>)['speed'], 1.5);
  });

  test('ElevenLabsTts reports error on non-2xx response', () async {
    final client = MockClient((http.Request req) async {
      return http.Response('{"detail":"unauthorized"}', 401);
    });

    bool played = false;
    bool? doneErr;
    final engine = ElevenLabsTts(
      apiKey: 'bad',
      voiceId: 'v',
      client: client,
      player: (String url, void Function(bool err) onDone) => played = true,
    );

    await engine.speak('Hæ', speed: 1.0, onDone: (bool err) => doneErr = err);

    expect(doneErr, true);
    expect(played, false);
  });

  test('ElevenLabsTts reports error when request throws', () async {
    final client = MockClient((http.Request req) async {
      throw TimeoutException('too slow');
    });

    bool? doneErr;
    final engine = ElevenLabsTts(
      apiKey: 'k',
      voiceId: 'v',
      client: client,
      player: (String url, void Function(bool err) onDone) => onDone(false),
    );

    await engine.speak('Hæ', speed: 1.0, onDone: (bool err) => doneErr = err);

    expect(doneErr, true);
  });

  test('ElevenLabsTts reports error when no voice ID is available', () async {
    bool requested = false;
    final client = MockClient((http.Request req) async {
      requested = true;
      return http.Response('', 200);
    });

    bool? doneErr;
    final engine = ElevenLabsTts(
      apiKey: 'k',
      voiceId: '',
      client: client,
      player: (String url, void Function(bool err) onDone) => onDone(false),
    );

    await engine.speak('Hæ', speed: 1.0, onDone: (bool err) => doneErr = err);

    expect(doneErr, true);
    expect(requested, false);
  });
}

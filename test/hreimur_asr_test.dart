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

// Tests for the Hreimur batch ASR engine: job submission, the status poll
// loop and the error paths. The microphone is replaced by a fake audio
// source, since the flutter_sound plugins are unavailable under
// `flutter test`.

import 'dart:convert' show jsonEncode, latin1, utf8;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' show MockClient;

import 'package:embla/asr/asr_engine.dart';
import 'package:embla/asr/audio_source.dart';
import 'package:embla/asr/hreimur_batch_asr.dart';
import 'package:embla/asr/wav.dart';

/// Feeds canned PCM to the engine instead of the microphone.
class FakeAudioSource implements AsrAudioSource {
  FakeAudioSource({this.chunk, this.level = 0.0});

  /// PCM delivered once when recording starts. Defaults to 1 s of silence.
  Uint8List? chunk;

  /// Value returned by [signalStrength].
  double level;

  bool started = false;
  bool stopped = false;
  int startSoundCount = 0;
  void Function(Uint8List)? _onData;
  void Function(String)? _onError;

  @override
  Future<void> start(
      void Function(Uint8List data) onData, void Function(String message) onError) async {
    started = true;
    _onData = onData;
    _onError = onError;
    feed(chunk ?? Uint8List(16000 * 2));
  }

  /// Pushes another PCM chunk into the engine.
  void feed(Uint8List data) => _onData?.call(data);

  /// Simulates a recorder failure.
  void fail(String message) => _onError?.call(message);

  @override
  Future<void> stop() async {
    stopped = true;
  }

  @override
  double signalStrength() => level;

  @override
  void playStartSound() => startSoundCount++;
}

const String kServer = 'https://api.greynir.is';
const String kKey = 'test-api-key';

http.Response json(Map<String, dynamic> body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status,
        headers: const {'content-type': 'application/json'});

/// A client that answers the submit request with [jobID] and then returns
/// [statuses] in order (repeating the last one).
MockClient jobClient(
  String jobID,
  List<Map<String, dynamic>> statuses, {
  List<http.BaseRequest>? log,
}) {
  int i = 0;
  return MockClient((http.Request request) async {
    log?.add(request);
    if (request.method == 'POST') {
      return json({'job_id': jobID});
    }
    final Map<String, dynamic> s = statuses[i < statuses.length - 1 ? i++ : statuses.length - 1];
    return json(s);
  });
}

HreimurBatchAsr engine(
  http.Client client, {
  required FakeAudioSource audio,
  bool autoStop = false,
  Duration timeout = const Duration(seconds: 5),
  Duration pollInterval = const Duration(milliseconds: 1),
  double silenceThreshold = kDefaultSilenceThreshold,
  Duration silenceDuration = const Duration(milliseconds: 200),
  Duration maxDuration = const Duration(seconds: 15),
  Duration sampleInterval = const Duration(milliseconds: 10),
  bool playSounds = false,
}) {
  return HreimurBatchAsr(
    serverURL: kServer,
    apiKey: kKey,
    client: client,
    audioSource: audio,
    autoStop: autoStop,
    timeout: timeout,
    pollInterval: pollInterval,
    silenceThreshold: silenceThreshold,
    silenceDuration: silenceDuration,
    maxDuration: maxDuration,
    sampleInterval: sampleInterval,
    playSounds: playSounds,
  );
}

void main() {
  group('HreimurBatchAsr identity', () {
    test('reports its id and capabilities', () {
      final FakeAudioSource audio = FakeAudioSource();
      expect(engine(MockClient((_) async => json({})), audio: audio).id, 'hreimur');
      expect(engine(MockClient((_) async => json({})), audio: audio).emitsPartials, false);
      // Manual mode requires the caller to call finish().
      expect(engine(MockClient((_) async => json({})), audio: audio).needsManualStop, true);
      expect(
          engine(MockClient((_) async => json({})), audio: audio, autoStop: true).needsManualStop,
          false);
    });
  });

  group('HreimurBatchAsr transcription', () {
    test('submits a WAV job and polls until done', () async {
      final FakeAudioSource audio = FakeAudioSource();
      final List<http.BaseRequest> log = <http.BaseRequest>[];
      final HreimurBatchAsr asr = engine(
        jobClient('job-1', [
          {'status': 'pending'},
          {'status': 'processing'},
          {
            'status': 'done',
            'result': {'raw': '  hvað er klukkan?  '}
          },
        ], log: log),
        audio: audio,
      );

      final Future<List<AsrEvent>> events = asr.listen().toList();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(audio.started, true);
      await asr.finish();

      final List<AsrEvent> result = await events;
      expect(result, hasLength(1));
      expect(result.single, isA<AsrFinal>());
      expect((result.single as AsrFinal).text, 'hvað er klukkan?');
      expect(audio.stopped, true);

      // Submit + three status requests.
      expect(log, hasLength(4));
      final http.BaseRequest submit = log.first;
      expect(submit.method, 'POST');
      expect(submit.url.toString(), '$kServer/long_asr/');
      expect(submit.headers['X-API-Key'], kKey);
      expect(submit.headers['content-type'], startsWith('multipart/form-data'));

      // Decode as latin1: the multipart body carries binary WAV data.
      final String body = latin1.decode((submit as http.Request).bodyBytes);
      expect(body, contains('name="output_format"'));
      expect(body, contains('raw'));
      expect(body, contains('name="input_language"'));
      expect(body, contains('is'));
      expect(body, contains('filename="audio.wav"'));
      expect(body, contains('audio/wav'));
      expect(body, contains('RIFF')); // WAV header made it into the upload

      for (final http.BaseRequest r in log.skip(1)) {
        expect(r.method, 'GET');
        expect(r.url.toString(), '$kServer/long_asr/status/job-1');
        expect(r.headers['X-API-Key'], kKey);
      }
    });

    test('uploads exactly the captured PCM, wrapped in a WAV container', () async {
      final Uint8List pcm =
          Uint8List.fromList(List<int>.generate(16000 * 2, (int i) => (i * 7) % 256));
      final FakeAudioSource audio = FakeAudioSource(chunk: pcm);
      Uint8List? uploaded;
      final MockClient client = MockClient((http.Request request) async {
        if (request.method == 'POST') {
          uploaded = request.bodyBytes;
          return json({'job_id': 'job-2'});
        }
        return json({
          'status': 'done',
          'result': {'raw': 'já'}
        });
      });
      final HreimurBatchAsr asr = engine(client, audio: audio);
      final Future<List<AsrEvent>> events = asr.listen().toList();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await asr.finish();
      await events;

      final Uint8List wav = wavFromPcm16(pcm);
      // The multipart body embeds the file verbatim.
      expect(uploaded, isNotNull);
      expect(indexOfBytes(uploaded!, wav.sublist(0, 44)), greaterThan(0));
      expect(uploaded!.length, greaterThan(wav.length));
    });

    test('decodes Icelandic characters as UTF-8', () async {
      final FakeAudioSource audio = FakeAudioSource();
      final HreimurBatchAsr asr = engine(
        jobClient('job-3', [
          {
            'status': 'done',
            'result': {'raw': 'Þórdís á Ægisíðu grillaði ýsu'}
          }
        ]),
        audio: audio,
      );
      final Future<List<AsrEvent>> events = asr.listen().toList();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await asr.finish();
      final List<AsrEvent> result = await events;
      expect((result.single as AsrFinal).text, 'Þórdís á Ægisíðu grillaði ýsu');
    });
  });

  group('HreimurBatchAsr empty results', () {
    test('maps a "No speech" failure to an empty final', () async {
      final FakeAudioSource audio = FakeAudioSource();
      final HreimurBatchAsr asr = engine(
        jobClient('job-4', [
          {
            'status': 'done',
            'result': {'error': 'No speech detected in audio'}
          }
        ]),
        audio: audio,
      );
      final Future<List<AsrEvent>> events = asr.listen().toList();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await asr.finish();
      final List<AsrEvent> result = await events;
      expect(result.single, isA<AsrFinal>());
      expect((result.single as AsrFinal).text, '');
    });

    test('does not upload very short recordings', () async {
      // 100 ms of audio is below the minimum worth transcribing.
      final FakeAudioSource audio = FakeAudioSource(chunk: Uint8List(3200));
      bool requested = false;
      final HreimurBatchAsr asr = engine(MockClient((http.Request request) async {
        requested = true;
        return json({'job_id': 'nope'});
      }), audio: audio);

      final Future<List<AsrEvent>> events = asr.listen().toList();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await asr.finish();
      final List<AsrEvent> result = await events;
      expect((result.single as AsrFinal).text, '');
      expect(requested, false);
      expect(audio.stopped, true);
    });
  });

  group('HreimurBatchAsr errors', () {
    test('reports an HTTP error on submit', () async {
      final FakeAudioSource audio = FakeAudioSource();
      final HreimurBatchAsr asr = engine(
        MockClient((http.Request request) async => http.Response('nope', 503)),
        audio: audio,
      );
      final Future<List<AsrEvent>> events = asr.listen().toList();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await asr.finish();
      final List<AsrEvent> result = await events;
      expect(result.single, isA<AsrError>());
      expect((result.single as AsrError).message, contains('503'));
    });

    test('reports a missing job id', () async {
      final FakeAudioSource audio = FakeAudioSource();
      final HreimurBatchAsr asr = engine(
        MockClient((http.Request request) async => json({'error': 'bad key'})),
        audio: audio,
      );
      final Future<List<AsrEvent>> events = asr.listen().toList();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await asr.finish();
      final List<AsrEvent> result = await events;
      expect(result.single, isA<AsrError>());
      expect((result.single as AsrError).message, contains('bad key'));
    });

    test('reports an HTTP error while polling', () async {
      final FakeAudioSource audio = FakeAudioSource();
      final HreimurBatchAsr asr = engine(
        MockClient((http.Request request) async =>
            request.method == 'POST' ? json({'job_id': 'job-5'}) : http.Response('boom', 500)),
        audio: audio,
      );
      final Future<List<AsrEvent>> events = asr.listen().toList();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await asr.finish();
      final List<AsrEvent> result = await events;
      expect(result.single, isA<AsrError>());
      expect((result.single as AsrError).message, contains('500'));
    });

    test('reports a failed job', () async {
      final FakeAudioSource audio = FakeAudioSource();
      final HreimurBatchAsr asr = engine(
        jobClient('job-6', [
          {
            'status': 'done',
            'result': {'error': 'Internal ASR failure'}
          }
        ]),
        audio: audio,
      );
      final Future<List<AsrEvent>> events = asr.listen().toList();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await asr.finish();
      final List<AsrEvent> result = await events;
      expect(result.single, isA<AsrError>());
      expect((result.single as AsrError).message, contains('Internal ASR failure'));
    });

    test('reports unparseable responses', () async {
      final FakeAudioSource audio = FakeAudioSource();
      final HreimurBatchAsr asr = engine(
        MockClient((http.Request request) async => http.Response('<html>nope</html>', 200)),
        audio: audio,
      );
      final Future<List<AsrEvent>> events = asr.listen().toList();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await asr.finish();
      final List<AsrEvent> result = await events;
      expect(result.single, isA<AsrError>());
      expect((result.single as AsrError).message, contains('Ógilt svar'));
    });

    test('gives up when the job never finishes', () async {
      final FakeAudioSource audio = FakeAudioSource();
      final HreimurBatchAsr asr = engine(
        jobClient('job-7', [
          {'status': 'pending'}
        ]),
        audio: audio,
        timeout: const Duration(milliseconds: 150),
        pollInterval: const Duration(milliseconds: 20),
      );
      final Future<List<AsrEvent>> events = asr.listen().toList();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await asr.finish();
      final List<AsrEvent> result = await events;
      expect(result.single, isA<AsrError>());
      expect((result.single as AsrError).message, 'ASR tímamörk');
    });

    test('reports recorder errors', () async {
      final FakeAudioSource audio = FakeAudioSource();
      final HreimurBatchAsr asr = engine(MockClient((_) async => json({})), audio: audio);
      final Future<List<AsrEvent>> events = asr.listen().toList();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      audio.fail('hljóðnemi í notkun');
      final List<AsrEvent> result = await events;
      expect(result.single, isA<AsrError>());
      expect((result.single as AsrError).message, contains('hljóðnemi í notkun'));
    });
  });

  group('HreimurBatchAsr session control', () {
    test('plays the start cue when sounds are enabled', () async {
      final FakeAudioSource audio = FakeAudioSource();
      final HreimurBatchAsr asr = engine(MockClient((_) async => json({})),
          audio: audio, playSounds: true);
      final Future<List<AsrEvent>> events = asr.listen().toList();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(audio.startSoundCount, 1);
      await asr.cancel();
      await events;
    });

    test('cancel stops the recorder and emits nothing', () async {
      final FakeAudioSource audio = FakeAudioSource();
      bool requested = false;
      final HreimurBatchAsr asr = engine(MockClient((http.Request request) async {
        requested = true;
        return json({'job_id': 'job-8'});
      }), audio: audio);

      final Future<List<AsrEvent>> events = asr.listen().toList();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await asr.cancel();
      // finish() after cancel must be a no-op.
      await asr.finish();
      expect(await events, isEmpty);
      expect(audio.stopped, true);
      expect(requested, false);
    });

    test('auto-stops after a silent stretch following speech', () async {
      final FakeAudioSource audio = FakeAudioSource(level: 0.5);
      final HreimurBatchAsr asr = engine(
        jobClient('job-9', [
          {
            'status': 'done',
            'result': {'raw': 'góðan daginn'}
          }
        ]),
        audio: audio,
        autoStop: true,
        silenceDuration: const Duration(milliseconds: 100),
        sampleInterval: const Duration(milliseconds: 10),
      );

      final Future<List<AsrEvent>> events = asr.listen().toList();
      // Speaking for a while...
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(asr.speechDetected, true);
      // ...then silence, which should end capture without a finish() call.
      audio.level = 0.0;
      final List<AsrEvent> result = await events;
      expect((result.single as AsrFinal).text, 'góðan daginn');
      expect(audio.stopped, true);
    });

    test('auto-stops at the maximum duration even without speech', () async {
      final FakeAudioSource audio = FakeAudioSource(level: 0.0);
      final HreimurBatchAsr asr = engine(
        jobClient('job-10', [
          {'status': 'done'}
        ]),
        audio: audio,
        autoStop: true,
        maxDuration: const Duration(milliseconds: 80),
        sampleInterval: const Duration(milliseconds: 10),
      );
      final List<AsrEvent> result = await asr.listen().toList();
      // Nothing was heard, so nothing is uploaded.
      expect((result.single as AsrFinal).text, '');
      expect(audio.stopped, true);
    });
  });
}

/// Index of the first occurrence of [needle] in [haystack], or -1.
int indexOfBytes(Uint8List haystack, Uint8List needle) {
  outer:
  for (int i = 0; i + needle.length <= haystack.length; i++) {
    for (int j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return i;
  }
  return -1;
}

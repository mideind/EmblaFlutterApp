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

// Batch ASR against Miðeind's Hreimur endpoint (`/long_asr/`): record the
// whole utterance locally, upload it as a WAV file and poll the job status
// until a transcript is ready. No partial results, and one round trip after
// the user stops talking, so it is noticeably slower than streaming ASR —
// but it is the only way to reach Hreimur today.
//
// End of speech is detected client-side (ported from `Recorder.swift` in the
// embla-2.0 MVP): sample the recorder's normalized signal strength every
// 100 ms and finish once the level has stayed below `silenceThreshold` for
// `silenceDuration` after speech was heard, or when `maxDuration` is up.
// With `autoStop: false` the caller drives the end of capture via `finish()`.

import 'dart:async';
import 'dart:convert' show jsonDecode, utf8;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

import '../common.dart' show dlog, kLongASRPath;
import 'asr_engine.dart';
import 'audio_source.dart';
import 'wav.dart';

/// Signal strength (0.0-1.0) at or above which we consider the user to be
/// speaking. `AudioRecorder.signalStrength()` maps -60..0 dB onto 0..1 with a
/// square-root curve, which puts 0.15 at roughly -34 dB — i.e. the -35 dB
/// threshold of the embla-2.0 Swift MVP. Note that flutter_sound's decibel
/// readings are not the same scale as AVAudioRecorder's, and embla_core
/// applies an arbitrary -70 dB offset on top, so this wants tuning on real
/// devices (a car cabin is noisy).
const double kDefaultSilenceThreshold = 0.15;

/// Anything shorter than this is treated as "nothing was said".
const Duration kMinSpeechDuration = Duration(milliseconds: 300);

class HreimurBatchAsr implements AsrEngine {
  HreimurBatchAsr({
    required this.serverURL,
    required this.apiKey,
    http.Client? client,
    AsrAudioSource? audioSource,
    this.autoStop = true,
    this.silenceThreshold = kDefaultSilenceThreshold,
    this.silenceDuration = const Duration(milliseconds: 800),
    this.maxDuration = const Duration(seconds: 15),
    this.pollInterval = const Duration(milliseconds: 150),
    this.timeout = const Duration(seconds: 60),
    this.sampleInterval = const Duration(milliseconds: 100),
    this.minSpeechDuration = kMinSpeechDuration,
    this.sampleRate = 16000,
    this.playSounds = true,
    this.onCapturedWav,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _audio = audioSource ?? const RecorderAudioSource();

  /// When set, the recorded WAV is handed here instead of being uploaded, and
  /// no transcript is produced. This is how the fused audio-LLM path reuses
  /// the recording and silence detection without a second copy of the timing
  /// logic, which is delicate enough that two copies would drift.
  final void Function(Uint8List wav)? onCapturedWav;

  /// Server hosting `/long_asr/`, e.g. `https://api.greynir.is`.
  final String serverURL;

  /// Miðeind API key, sent as `X-API-Key`.
  final String apiKey;

  /// Whether to stop capture on silence/timeout instead of waiting
  /// for the caller to call `finish()`.
  final bool autoStop;

  /// Normalized level below which audio counts as silence.
  final double silenceThreshold;

  /// How long the signal must stay below [silenceThreshold] (after speech
  /// has been heard) before capture ends.
  final Duration silenceDuration;

  /// Hard cap on recording length.
  final Duration maxDuration;

  /// Delay between job status requests.
  final Duration pollInterval;

  /// Budget for the whole upload + polling round trip.
  final Duration timeout;

  /// How often the signal strength is sampled while recording.
  final Duration sampleInterval;

  /// Minimum amount of audio worth uploading.
  final Duration minSpeechDuration;

  /// Sample rate of the captured PCM; written into the WAV header.
  final int sampleRate;

  /// Whether to play the "start listening" cue.
  final bool playSounds;

  final http.Client _client;
  final bool _ownsClient;
  final AsrAudioSource _audio;

  final BytesBuilder _pcm = BytesBuilder(copy: true);
  final Stopwatch _clock = Stopwatch();

  StreamController<AsrEvent>? _controller;
  Timer? _sampleTimer;
  bool _speechDetected = false;
  Duration _lastLoud = Duration.zero;
  bool _finishing = false;
  bool _cancelled = false;
  bool _closed = false;

  @override
  String get id => 'hreimur';

  @override
  bool get emitsPartials => false;

  @override
  bool get needsManualStop => !autoStop;

  /// Whether speech has been detected during the current recording.
  bool get speechDetected => _speechDetected;

  @override
  Stream<AsrEvent> listen() {
    final StreamController<AsrEvent> controller = StreamController<AsrEvent>();
    _controller = controller;
    _pcm.clear();
    _speechDetected = false;
    _lastLoud = Duration.zero;
    _finishing = false;
    _cancelled = false;
    _closed = false;
    _clock
      ..reset()
      ..start();

    if (playSounds) {
      _audio.playStartSound();
    }

    unawaited(_startCapture());

    if (autoStop) {
      _sampleTimer = Timer.periodic(sampleInterval, (_) => _sample());
    }

    return controller.stream;
  }

  @override
  Future<void> finish() async {
    if (_finishing || _cancelled || _closed) {
      return;
    }
    _finishing = true;
    await _stopCapture();

    final Uint8List pcm = _pcm.takeBytes();
    final int minBytes = (sampleRate * 2 * minSpeechDuration.inMilliseconds) ~/ 1000;
    if (pcm.lengthInBytes < minBytes || (autoStop && !_speechDetected)) {
      dlog('Hreimur: no speech captured (${pcm.lengthInBytes} bytes), ending quietly');
      _emit(const AsrFinal(''));
      _close();
      return;
    }

    final Uint8List wav = wavFromPcm16(pcm, sampleRate: sampleRate);

    final void Function(Uint8List)? handOff = onCapturedWav;
    if (handOff != null) {
      handOff(wav);
      // The caller transcribes; emit an empty final so the session's ASR stage
      // completes rather than waiting on a transcript that never arrives.
      _emit(const AsrFinal(''));
      _close();
      return;
    }

    final Stopwatch budget = Stopwatch()..start();
    try {
      final String jobID = await _submit(wav);
      if (_cancelled) {
        return;
      }
      await _poll(jobID, budget);
    } catch (e) {
      dlog('Hreimur ASR failed: $e');
      _emit(AsrError(e is AsrFailure ? e.message : 'Villa í talgreiningu: $e'));
      _close();
    }
  }

  @override
  Future<void> cancel() async {
    if (_cancelled) {
      return;
    }
    dlog('Cancelling Hreimur ASR session');
    _cancelled = true;
    _close(); // Stops any in-flight poll loop from emitting.
    await _stopCapture();
  }

  /// Releases the HTTP client if this engine created it. The engine cannot
  /// be used afterwards.
  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  // ---------------------------------------------------------------------
  // Recording

  Future<void> _startCapture() async {
    try {
      await _audio.start(_handleData, _handleAudioError);
    } catch (e) {
      dlog('Error starting recorder: $e');
      if (_closed) {
        return;
      }
      _emit(AsrError('Ekki náðist að hefja hljóðupptöku: $e'));
      _close();
    }
  }

  Future<void> _stopCapture() async {
    _sampleTimer?.cancel();
    _sampleTimer = null;
    _clock.stop();
    await _audio.stop();
  }

  void _handleData(Uint8List data) {
    if (_closed || _finishing) {
      return;
    }
    _pcm.add(data);
  }

  void _handleAudioError(String message) {
    if (_closed) {
      return;
    }
    _emit(AsrError('Villa í hljóðupptöku: $message'));
    _close();
    unawaited(_stopCapture());
  }

  // Silence detection, sampled on a timer while recording.
  void _sample() {
    if (_closed || _finishing) {
      return;
    }
    final Duration now = _clock.elapsed;
    if (_audio.signalStrength() >= silenceThreshold) {
      _speechDetected = true;
      _lastLoud = now;
    }
    if (_speechDetected && now - _lastLoud > silenceDuration) {
      dlog('Hreimur: silence for ${silenceDuration.inMilliseconds} ms, finishing');
      unawaited(finish());
      return;
    }
    if (now > maxDuration) {
      dlog('Hreimur: max recording duration reached, finishing');
      unawaited(finish());
    }
  }

  // ---------------------------------------------------------------------
  // Hreimur job API

  Future<String> _submit(Uint8List wav) async {
    final Uri uri = Uri.parse('$serverURL$kLongASRPath');
    dlog('Submitting ${wav.lengthInBytes} bytes of audio to $uri');

    final http.MultipartRequest request = http.MultipartRequest('POST', uri)
      ..headers['X-API-Key'] = apiKey
      // `raw` skips server-side postprocessing, which is faster.
      ..fields['output_format'] = 'raw'
      ..fields['input_language'] = 'is'
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        wav,
        filename: 'audio.wav',
        contentType: MediaType('audio', 'wav'),
      ));

    final http.Response response = await http.Response.fromStream(await _client.send(request));
    final Map<String, dynamic> json = _decode(response, uri);
    final Object? jobID = json['job_id'];
    if (jobID is! String || jobID.isEmpty) {
      throw AsrFailure('Svar frá talgreini vantar auðkenni: ${json['error'] ?? 'óþekkt villa'}');
    }
    return jobID;
  }

  Future<void> _poll(String jobID, Stopwatch budget) async {
    final Uri uri = Uri.parse('$serverURL${kLongASRPath}status/$jobID');

    bool firstCheck = true;
    while (budget.elapsed < timeout) {
      // Check once immediately: waiting a full interval before the first
      // status call added that much dead time to every single turn.
      if (!firstCheck) {
        await Future<void>.delayed(pollInterval);
      }
      firstCheck = false;
      if (_cancelled || _closed) {
        return;
      }

      final http.Response response = await _client.get(uri, headers: {'X-API-Key': apiKey});
      if (_cancelled || _closed) {
        return;
      }
      final Map<String, dynamic> json = _decode(response, uri);
      final String status = json['status']?.toString() ?? '';
      if (status != 'done') {
        if (status == 'error' || status == 'failed') {
          throw AsrFailure('Talgreining mistókst: ${json['error'] ?? status}');
        }
        continue;
      }

      final Object? result = json['result'];
      final Map<String, dynamic> data = result is Map<String, dynamic> ? result : const {};
      final Object? raw = data['raw'];
      if (raw is String && raw.trim().isNotEmpty) {
        _emit(AsrFinal(raw.trim()));
        _close();
        return;
      }

      // Done, but no transcript: either nothing was said or a real failure.
      final String error = (data['error'] ?? json['error'])?.toString() ?? 'óþekkt villa';
      if (error.contains('No speech')) {
        dlog('Hreimur: no speech detected in audio');
        _emit(const AsrFinal(''));
        _close();
        return;
      }
      throw AsrFailure('Talgreining mistókst: $error');
    }

    throw const AsrFailure('ASR tímamörk');
  }

  Map<String, dynamic> _decode(http.Response response, Uri uri) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AsrFailure('Talgreiningarþjónn svaraði með ${response.statusCode} (${uri.path})');
    }
    try {
      // Decode as UTF-8 explicitly: http falls back to latin1 when the
      // server does not declare a charset, which mangles Icelandic text.
      final Object? json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is Map<String, dynamic>) {
        return json;
      }
    } catch (e) {
      dlog('Could not parse ASR response: $e');
    }
    throw const AsrFailure('Ógilt svar frá talgreiningarþjóni');
  }

  // ---------------------------------------------------------------------

  void _emit(AsrEvent event) {
    if (_closed || _cancelled) {
      return;
    }
    _controller?.add(event);
  }

  void _close() {
    if (_closed) {
      return;
    }
    _closed = true;
    final StreamController<AsrEvent>? controller = _controller;
    _controller = null;
    controller?.close();
  }
}

/// Internal marker for failures that already carry a user-facing
/// (Icelandic) message.
class AsrFailure implements Exception {
  final String message;
  const AsrFailure(this.message);
  @override
  String toString() => message;
}

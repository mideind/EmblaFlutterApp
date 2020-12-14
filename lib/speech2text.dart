/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2020 Miðeind ehf. <mideind@mideind.is>
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

// Singleton wrapper class for speech recognition

import 'dart:async';
import 'dart:math' show max, pow;
import 'dart:typed_data' show Int16List;

import 'package:dart_numerics/dart_numerics.dart' show log10;
import 'package:google_speech/google_speech.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sound_stream/sound_stream.dart';

import './util.dart';
import './common.dart';

// Speech recognition config
RecognitionConfig speechRecognitionConfig = RecognitionConfig(
    encoding: AudioEncoding.LINEAR16,
    model: RecognitionModel.command_and_search,
    enableAutomaticPunctuation: true,
    sampleRateHertz: 16000,
    languageCode: 'is-IS');

class SpeechRecognizer {
  static final SpeechRecognizer _instance = SpeechRecognizer._internal();

  factory SpeechRecognizer() {
    return _instance;
  }

  SpeechRecognizer._internal() {
    dlog('Initializing SpeechRecognizer');
    _recorder.initialize();
  }

  final RecorderStream _recorder = RecorderStream();
  StreamSubscription<List<int>> _audioStreamSubscription;
  BehaviorSubject<List<int>> _audioStream;
  double lastSignal = 0; // Strength of last audio signal

  double _normalizedPowerLevelFromDecibels(double decibels) {
    if (decibels < -60.0 || decibels == 0.0) {
      return 0.0;
    }
    double exp = 0.05;
    return pow(
        (pow(10.0, exp * decibels) - pow(10.0, exp * -60.0)) *
            (1.0 / (1.0 - pow(10.0, exp * -60.0))),
        1.0 / 2.0);
  }

  void _updateAudioSignal(Int16List samples) {
    int maxSignal = samples.reduce(max);
    double ampl = maxSignal / 32767.0;
    // print(ampl);
    double decibels = 20.0 * log10(ampl);
    // print(decibels);
    lastSignal = _normalizedPowerLevelFromDecibels(decibels);
    // print(lastSignal);
  }

  void start(Function dataHandler, Function completionHandler) async {
    _audioStream = BehaviorSubject<List<int>>();
    _audioStreamSubscription = _recorder.audioStream.listen((data) {
      _audioStream.add(data);
      // Coerce sample bytes into list of 16-bit shorts
      Int16List samples = data.buffer.asInt16List();
      //print("Num samples: ${samples.length.toString()}");
      _updateAudioSignal(samples);
    });

    await _recorder.start();

    final serviceAccount = ServiceAccount.fromString(await readGoogleServiceAccount());
    final speechToText = SpeechToText.viaServiceAccount(serviceAccount);
    final Stream responseStream = speechToText.streamingRecognize(
        StreamingRecognitionConfig(config: speechRecognitionConfig, interimResults: true),
        _audioStream);

    responseStream.listen(dataHandler, onDone: completionHandler);
  }

  void stop() async {
    await _recorder?.stop();
    await _audioStreamSubscription?.cancel();
    await _audioStream?.close();
  }
}

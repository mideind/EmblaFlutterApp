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
import 'dart:typed_data' show Uint8List, Int16List;

import 'package:dart_numerics/dart_numerics.dart' show log10;
import 'package:flutter/foundation.dart';
import 'package:google_speech/google_speech.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sound_stream/sound_stream.dart';

import './util.dart';
import './common.dart';

// Speech recognition config record
final RecognitionConfig speechRecognitionConfig = RecognitionConfig(
    encoding: AudioEncoding.LINEAR16,
    model: RecognitionModel.command_and_search,
    enableAutomaticPunctuation: true,
    sampleRateHertz: 16000,
    maxAlternatives: 10,
    languageCode: 'is-IS');

class SpeechRecognizer {
  // Class variables
  RecorderStream _micRecorder = RecorderStream();
  StreamSubscription<List<int>> _recognitionStreamSubscription;
  BehaviorSubject<List<int>> _recognitionStream;
  double lastSignal = 0.0; // Strength of last audio signal, on a scale of 0.0 to 1.0
  bool isRecognizing = false;

  // Constructor
  static final SpeechRecognizer _instance = SpeechRecognizer._internal();

  // Singleton pattern
  factory SpeechRecognizer() {
    return _instance;
  }

  // Initialization
  SpeechRecognizer._internal() {}

  // Do we have all we need to recognize speech?
  bool canRecognizeSpeech() {
    // TODO: Also check for app permissions f. microphone input
    return (readGoogleServiceAccount() != '');
  }

  // Normalize decibel level to a number between 0.0 and 1.0
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

  // Read audio buffer, analyse strength of signal
  void _updateAudioSignal(Uint8List data) {
    // Coerce sample bytes into list of 16-bit shorts
    Int16List samples = data.buffer.asInt16List();
    dlog("Num samples: ${samples.length.toString()}");
    int maxSignal = samples.reduce(max);
    // Divide by max value of 16-bit short to get amplitude in range 0.0-1.0
    double ampl = maxSignal / 32767.0;
    // dlog(ampl);
    double decibels = 20.0 * log10(ampl);
    // dlog(decibels);
    lastSignal = _normalizedPowerLevelFromDecibels(decibels);
    // dlog(lastSignal);
  }

  // Set things off
  void start(Function dataHandler, Function completionHandler) async {
    dlog('Initializing speech recognizer');
    _micRecorder = RecorderStream();
    _micRecorder.initialize();

    isRecognizing = true;
    dlog('Starting speech recognition');
    // Subscribe to recording stream
    _recognitionStream = BehaviorSubject<List<int>>();
    _recognitionStreamSubscription = _micRecorder.audioStream.listen((data) {
      // When recording stream receives data, pass it on to the recognition
      // stream and note the maximum strength of the audio signal.
      dlog('Received stream data');
      _recognitionStream?.add(data);
      _updateAudioSignal(data);
    });

    // Start microphone recording
    await _micRecorder.start();

    // Start recognizing
    final serviceAccount = ServiceAccount.fromString(readGoogleServiceAccount());
    final speechToText = SpeechToText.viaServiceAccount(serviceAccount);
    final Stream responseStream = speechToText.streamingRecognize(
        StreamingRecognitionConfig(config: speechRecognitionConfig, interimResults: true),
        _recognitionStream);

    // Listen for streaming speech recognition response
    responseStream.listen(dataHandler, onDone: completionHandler);
  }

  void stop() async {
    if (isRecognizing == false) {
      return;
    }
    isRecognizing = false;
    // Kill everything
    dlog('Stopping speech recognition');
    await _micRecorder?.stop();
    await _recognitionStreamSubscription?.cancel();
    await _recognitionStream?.close();
  }
}

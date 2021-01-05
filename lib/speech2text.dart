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

import 'package:flutter_sound/flutter_sound.dart';
import 'package:dart_numerics/dart_numerics.dart' show log10;
import 'package:google_speech/google_speech.dart';
import 'package:rxdart/rxdart.dart';
import 'package:permission_handler/permission_handler.dart';

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

  FlutterSoundRecorder _micRecorder = FlutterSoundRecorder();
  StreamSubscription _recordingDataSubscription;
  StreamController _recordingDataController;

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
  SpeechRecognizer._internal();

  // Do we have all we need to recognize speech?
  Future<bool> canRecognizeSpeech() async {
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      return false;
    }
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
    // Due to the internal details in the flutter_sound
    // implementation, we have to create a copy of the
    // data before analyzing it. Inefficient, but whatchagonnado?
    Uint8List copy = new Uint8List.fromList(data);
    // Coerce into list of 16-bit shorts
    Int16List samples = copy.buffer.asInt16List();
    // dlog("Num samples: ${samples.length.toString()}");
    int maxSignal = samples.reduce(max);
    // int maxSignal = samples.reduce((curr, next) => curr > next ? curr : next);
    // dlog(maxSignal);
    // Divide by max value of 16-bit short to get amplitude in range 0.0-1.0
    double ampl = maxSignal / 32767.0;
    // dlog(ampl.toString());
    double decibels = 20.0 * log10(ampl);
    // dlog(decibels.toString());
    lastSignal = _normalizedPowerLevelFromDecibels(decibels);
    // dlog(lastSignal.toString());
  }

  // Set things off
  void start(Function dataHandler, Function completionHandler) async {
    isRecognizing = true;
    dlog('Starting speech recognition');

    // Stream to be consumed by speech recognizer
    _recognitionStream = BehaviorSubject<List<int>>();

    // Create recording stream
    _recordingDataController = StreamController<Food>();
    _recordingDataSubscription = _recordingDataController.stream.listen((buffer) {
      if (buffer is FoodData) {
        _recognitionStream?.add(buffer.data);
        _updateAudioSignal(buffer.data);
      }
    });

    // Open microphone session
    await _micRecorder.openAudioSession();
    await _micRecorder.startRecorder(
      toStream: _recordingDataController.sink,
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: 16000,
    );

    // Start recognizing
    final serviceAccount = ServiceAccount.fromString(readGoogleServiceAccount());
    final speechToText = SpeechToText.viaServiceAccount(serviceAccount);
    final Stream responseStream = speechToText.streamingRecognize(
        StreamingRecognitionConfig(config: speechRecognitionConfig, interimResults: true),
        _recognitionStream);

    // Listen for streaming speech recognition response
    responseStream.listen(dataHandler, onDone: completionHandler);
  }

  // Teardown
  void stop() async {
    if (isRecognizing == false) {
      return;
    }
    isRecognizing = false;
    dlog('Stopping speech recognition');
    await _micRecorder?.stopRecorder();
    await _micRecorder?.closeAudioSession();
    await _recordingDataSubscription?.cancel();
    await _recordingDataController?.close();
    await _recognitionStreamSubscription?.cancel();
    await _recognitionStream?.close();
  }
}

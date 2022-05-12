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

// Singleton wrapper class for speech to text functionality

import 'dart:async';
import 'dart:math' show pow;

import 'package:logger/logger.dart' show Level;
import 'package:flutter_sound_lite/flutter_sound.dart';
import 'package:google_speech/google_speech.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rxdart/rxdart.dart';

import './common.dart';
import './util.dart';

// Speech recognition config record
final RecognitionConfig speechRecognitionConfig = RecognitionConfig(
    encoding: AudioEncoding.LINEAR16,
    audioChannelCount: 1,
    model: RecognitionModel.command_and_search,
    //enableAutomaticPunctuation: false,
    sampleRateHertz: kAudioSampleRate,
    maxAlternatives: kSpeechToTextMaxAlternatives,
    languageCode: kSpeechToTextLanguage);

class SpeechRecognizer {
  final FlutterSoundRecorder _micRecorder = FlutterSoundRecorder(logLevel: Level.error);
  StreamSubscription _recordingDataSubscription;
  StreamSubscription _recordingProgressSubscription;
  StreamController _recordingDataController;

  StreamSubscription<List<int>> _recognitionStreamSubscription;
  BehaviorSubject<List<int>> _recognitionStream;

  bool isRecognizing = false;
  double lastSignal = 0.0; // Strength of last audio signal, on a scale of 0.0 to 1.0
  int totalAudioDataSize = 0; // Accumulated byte size of audio recording

  static final SpeechRecognizer _instance = SpeechRecognizer._internal();

  // Singleton pattern
  factory SpeechRecognizer() {
    return _instance;
  }

  // Initialization
  SpeechRecognizer._internal();

  // Do we have all we need to recognize speech?
  Future<bool> canRecognizeSpeech() async {
    // Access to microphone?
    PermissionStatus status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      return false;
    }
    // Proper service account for STT server?
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

  // Set things off
  Future<void> start(Function dataHandler, Function completionHandler, Function errHandler) async {
    if (isRecognizing == true) {
      dlog('Speech recognition already running!');
      return;
    }
    dlog('Starting speech recognition');
    isRecognizing = true;
    totalAudioDataSize = 0;

    // Stream to be consumed by speech recognizer
    _recognitionStream = BehaviorSubject<List<int>>();

    // Create recording stream
    _recordingDataController = StreamController<Food>();
    _recordingDataSubscription = _recordingDataController.stream.listen((buffer) {
      if (buffer is FoodData) {
        _recognitionStream?.add(buffer.data);
        totalAudioDataSize += buffer.data.lengthInBytes;
      }
    });

    // Open microphone recording session
    await _micRecorder.openAudioSession();

    // Listen for audio status (duration, decibel) at fixed interval
    _micRecorder.setSubscriptionDuration(Duration(milliseconds: 50));
    _recordingProgressSubscription = _micRecorder.onProgress.listen((e) {
      double decibels = e.decibels - 70.0; // This number is arbitrary but works
      lastSignal = _normalizedPowerLevelFromDecibels(decibels);
      print(lastSignal);
    });

    // Start recording audio
    await _micRecorder.startRecorder(
        toStream: _recordingDataController.sink,
        codec: Codec.pcm16,
        numChannels: kAudioNumChannels,
        sampleRate: kAudioSampleRate);

    // Start recognizing speech from audio stream
    final serviceAccount = ServiceAccount.fromString(readGoogleServiceAccount());
    final speechToText = SpeechToText.viaServiceAccount(serviceAccount);
    final Stream responseStream = speechToText.streamingRecognize(
        StreamingRecognitionConfig(
            config: speechRecognitionConfig, interimResults: true, singleUtterance: true),
        _recognitionStream);

    // Listen for streaming speech recognition server responses
    responseStream.listen(dataHandler,
        onError: errHandler, onDone: completionHandler, cancelOnError: true);
  }

  // Teardown
  Future<void> stop() async {
    if (isRecognizing == false) {
      return;
    }
    isRecognizing = false;
    dlog('Stopping speech recognition');
    double seconds = totalAudioDataSize / (2.0 * kAudioSampleRate);
    dlog("Total audio length: $seconds seconds ($totalAudioDataSize bytes)");
    await _micRecorder?.stopRecorder();
    await _micRecorder?.closeAudioSession();
    await _recordingDataSubscription?.cancel();
    await _recordingProgressSubscription?.cancel();
    await _recordingDataController?.close();
    await _recognitionStreamSubscription?.cancel();
    await _recognitionStream?.close();
  }
}

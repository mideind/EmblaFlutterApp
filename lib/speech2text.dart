/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2021 Miðeind ehf. <mideind@mideind.is>
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
import 'dart:math' show max, pow;
import 'dart:typed_data' show Uint8List, Int16List;

import 'package:dart_numerics/dart_numerics.dart' show log10;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:google_speech/google_speech.dart';
import 'package:google_speech/generated/google/cloud/speech/v1/cloud_speech.pb.dart'
    show RecognitionMetadata;
import 'package:google_speech/generated/google/cloud/speech/v1/cloud_speech.pbenum.dart'
    show
        RecognitionMetadata_RecordingDeviceType,
        RecognitionMetadata_InteractionType,
        RecognitionMetadata_OriginalMediaType;
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
  languageCode: kSpeechToTextLanguage,
  //recognitionMetadata: getMetadata()
);

// Speech recognition metadata
RecognitionMetadata getMetadata() {
  RecognitionMetadata md = RecognitionMetadata.getDefault();
  md.recordingDeviceType = RecognitionMetadata_RecordingDeviceType.SMARTPHONE;
  md.interactionType = RecognitionMetadata_InteractionType.VOICE_COMMAND;
  md.originalMediaType = RecognitionMetadata_OriginalMediaType.AUDIO;
  return md;
}

class SpeechRecognizer {
  FlutterSoundRecorder _micRecorder = FlutterSoundRecorder();
  StreamSubscription _recordingDataSubscription;
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
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      return false;
    }
    // Proper service account for speech2text server?
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
    // Due to internal details of the flutter_sound
    // implementation, we have to create a copy of the
    // data before analyzing it. Inefficient, but whatchagonnado?
    Uint8List copy = new Uint8List.fromList(data);
    // Coerce into list of 16-bit signed integers
    Int16List samples = copy.buffer.asInt16List();
    // dlog("Num samples: ${samples.length.toString()}");
    int maxSignal = samples.reduce(max);
    // dlog(maxSignal);
    // Divide by max value of 16-bit signed integer to get amplitude in range 0.0-1.0
    double ampl = maxSignal / 32767.0;
    // dlog(ampl);
    // Convert to decibels and normalize
    double decibels = 20.0 * log10(ampl);
    lastSignal = _normalizedPowerLevelFromDecibels(decibels);
    // dlog(lastSignal);
  }

  // Set things off
  Future<void> start(Function dataHandler, Function completionHandler, Function errHandler) async {
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
        _updateAudioSignal(buffer.data);
        totalAudioDataSize += buffer.data.lengthInBytes;
      }
    });

    // Open microphone session
    await _micRecorder.openAudioSession();
    await _micRecorder.startRecorder(
      toStream: _recordingDataController.sink,
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: kAudioSampleRate,
    );

    // Start recognizing
    final serviceAccount = ServiceAccount.fromString(readGoogleServiceAccount());
    final speechToText = SpeechToText.viaServiceAccount(serviceAccount);
    final Stream responseStream = speechToText.streamingRecognize(
        StreamingRecognitionConfig(
            config: speechRecognitionConfig, interimResults: true, singleUtterance: true),
        _recognitionStream);

    // Listen for streaming speech recognition response
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
    await _recordingDataController?.close();
    await _recognitionStreamSubscription?.cancel();
    await _recognitionStream?.close();
  }
}

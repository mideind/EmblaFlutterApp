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

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart' show Level;
import 'package:audio_session/audio_session.dart';
import 'package:flutter_sound/flutter_sound.dart';
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

/// Wrapper class for speech to text functionality
class SpeechRecognizer {
  final FlutterSoundRecorder _micRecorder = FlutterSoundRecorder(logLevel: Level.error);
  StreamSubscription? _recordingDataSubscription;
  StreamSubscription? _recordingProgressSubscription;
  StreamController? _recordingDataController;

  StreamSubscription<List<int>>? _recognitionStreamSubscription;
  BehaviorSubject<List<int>>? _recognitionStream;

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
        1.0 / 2.0) as double;
  }

  // Set things off
  Future<void> start(void Function(dynamic) dataHandler, void Function()? completionHandler,
      Function errHandler) async {
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
    _recordingDataSubscription = _recordingDataController?.stream.listen((buffer) {
      if (buffer is FoodData && buffer.data != null) {
        _recognitionStream?.add(buffer.data as Uint8List);
        totalAudioDataSize += buffer.data!.lengthInBytes;
      } else {
        dlog('Got null data in recording stream: $buffer');
      }
    });

    // Open microphone recording session
    await _micRecorder.openRecorder();

    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth |
          AVAudioSessionCategoryOptions.defaultToSpeaker,
      // avAudioSessionMode: AVAudioSessionMode.spokenAudio,
      avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.voiceCommunication,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    ));

    // Listen for audio status (duration, decibel) at fixed interval
    _micRecorder.setSubscriptionDuration(Duration(milliseconds: 50));
    _recordingProgressSubscription = _micRecorder.onProgress?.listen((e) {
      if (e.decibels == 0.0) {
        return;
      }
      dlog(e);
      double decibels = e.decibels! - 70.0; // This number is arbitrary but works
      lastSignal = _normalizedPowerLevelFromDecibels(decibels);
    });

    // Start recording audio
    await _micRecorder.startRecorder(
        toStream: _recordingDataController?.sink as StreamSink<Food>,
        codec: Codec.pcm16,
        numChannels: kAudioNumChannels,
        sampleRate: kAudioSampleRate);

    // Start recognizing speech from audio stream
    final serviceAccount = ServiceAccount.fromString(readGoogleServiceAccount());
    final speechToText = SpeechToText.viaServiceAccount(serviceAccount);
    final Stream responseStream = speechToText.streamingRecognize(
        StreamingRecognitionConfig(
            config: speechRecognitionConfig, interimResults: true, singleUtterance: true),
        _recognitionStream as Stream<List<int>>);

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
    await _micRecorder.stopRecorder();
    await _micRecorder.closeRecorder();
    await _recordingDataSubscription?.cancel();
    await _recordingProgressSubscription?.cancel();
    await _recordingDataController?.close();
    await _recognitionStreamSubscription?.cancel();
    await _recognitionStream?.close();
  }
}

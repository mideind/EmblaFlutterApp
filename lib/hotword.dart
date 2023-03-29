/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2020-2023 Miðeind ehf. <mideind@mideind.is>
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

/// Singleton wrapper class for hotword detection ("Hæ Embla" activation)

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import 'package:logger/logger.dart' show Level;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_snowboy/flutter_snowboy.dart' show Snowboy;
import 'package:flutter_sound/flutter_sound.dart';

import './common.dart';

/// Hotword detection singleton class.
class HotwordDetector {
  static final HotwordDetector _instance = HotwordDetector._constructor();

  static late Snowboy detector;
// TODO: This should use EmblaCore's AudioRecorder class instead of FlutterSound
  final FlutterSoundRecorder _micRecorder = FlutterSoundRecorder(logLevel: Level.error);
  StreamController _recordingDataController = StreamController<Food>();
  StreamSubscription? _recordingDataSubscription;

  // Singleton pattern
  factory HotwordDetector() {
    return _instance;
  }

  // Constructor, only called once, when singleton is instantiated
  HotwordDetector._constructor() {
    initialize();
  }

  /// Load and prepare hotword-related resources.
  void initialize() async {
    late String modelPath;
    try {
      modelPath = await HotwordDetector._copyModelToFilesystem(kHotwordModelName);
    } catch (err) {
      dlog("Error copying hotword model to filesystem: $err");
      return;
    }

    detector = Snowboy();
    detector.prepare(modelPath,
        sensitivity: kHotwordSensitivity,
        audioGain: kHotwordAudioGain,
        applyFrontend: kHotwordApplyFrontend);
  }

  /// Start hotword detection.
  Future<void> start(Function hwHandler) async {
    dlog('Starting hotword detection');
    detector.hotwordHandler = hwHandler;

    // Prepare for recording session
    await _micRecorder.openRecorder();

    // Create recording stream
    _recordingDataController = StreamController<Food>();
    _recordingDataSubscription = _recordingDataController.stream.listen((buffer) {
      if ((buffer is FoodData) == false || buffer.data == null) {
        dlog('Hotword detector received null data: $buffer');
        return;
      }
      // When we get valid data, feed it into Snowboy detector
      detector.detect(buffer.data as Uint8List);
    });

    // Start recording
    await _micRecorder.startRecorder(
        toStream: _recordingDataController.sink as StreamSink<Food>,
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: 16000);
  }

  /// Stop hotword detection
  Future<void> stop() async {
    dlog('Stopping hotword detection');
    await _micRecorder.stopRecorder();
    await _micRecorder.closeRecorder();
    await _recordingDataSubscription?.cancel();
    await _recordingDataController.close();
  }

  /// Copy model file from asset bundle to temp directory on
  /// the filesystem. Does not overwrite the file by default.
  /// When new hotword models are deployed, change the filename.
  /// Otherwise, the old model will continue to be used.
  static Future<String> _copyModelToFilesystem(String filename, [bool overwrite = false]) async {
    final String dir = (await getTemporaryDirectory()).path;
    final String finalPath = "$dir/$filename";
    final file = File(finalPath);

    if (await file.exists() == true) {
      if (overwrite == true) {
        dlog("Overwriting existing hotword model file: $finalPath");
        await file.delete();
      } else {
        // File already exists, return path
        return finalPath;
      }
    }
    // Copy model file from asset bundle to filesystem
    final ByteData bytes = await rootBundle.load("$kHotwordAssetsDirectory/$filename");
    final buffer = bytes.buffer;
    File(finalPath).writeAsBytes(buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));

    return finalPath;
  }
}

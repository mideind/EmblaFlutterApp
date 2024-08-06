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

// Singleton wrapper class for hotword detection ("Hæ Embla" activation)

import 'dart:io';
import 'dart:typed_data';

import 'package:embla_core/embla_core.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:path_provider/path_provider.dart';
import 'package:flutter_snowboy/flutter_snowboy.dart' show Snowboy;

import './common.dart';
import './prefs.dart';

/// Hotword detection singleton class.
class HotwordDetector {
  static final HotwordDetector _instance = HotwordDetector._constructor();
  static late Snowboy detector;

  // Singleton pattern
  factory HotwordDetector() {
    return _instance;
  }

  // Constructor, only called when singleton is instantiated
  HotwordDetector._constructor() {
    initialize();
  }

  /// Load and prepare hotword-detection-related resources.
  void initialize() async {
    late String modelPath;
    try {
      modelPath = await HotwordDetector._copyModelToFilesystem(kHotwordModelName);
    } catch (err) {
      dlog("Error copying hotword model to filesystem: $err");
      return;
    }

    if (await File(modelPath).exists() == false) {
      dlog("WARNING! Hotword model file does not exist at $modelPath");
      return;
    }

    detector = Snowboy();
    detector.prepare(modelPath,
        sensitivity: kHotwordSensitivity,
        audioGain: kHotwordAudioGain,
        applyFrontend: kHotwordApplyFrontend);
  }

  /// Start hotword detection.
  Future<void> start(void Function() hwHandler) async {
    if (isActive() == true) {
      dlog("HotwordDetector(): Detection already in progress, ignoring start request");
      return;
    }

    // This is unnecessary and unpleasant coupling, but just in case.
    // We should never be here if hotword detection is not enabled.
    if (Prefs().boolForKey('hotword_activation') == false) {
      dlog("HotwordDetector(): Hotword activation is disabled, ignoring start request.");
      return;
    }

    dlog('Starting hotword detection');
    detector.hotwordHandler = hwHandler;

    await AudioRecorder().start((Uint8List data) {
      // Feed data into Snowboy detector
      detector.detect(data);
    }, (String err) {
      dlog("Error during hotword detection: $err");
    });
  }

  /// Stop hotword detection
  Future<void> stop() async {
    if (isActive() == false) {
      return;
    }
    dlog('Stopping hotword detection');
    await AudioRecorder().stop();
  }

  bool isActive() {
    return AudioRecorder().isRecording();
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
        dlog("Hotword model file already exists at $finalPath");
        return finalPath;
      }
    }
    // Copy model file from asset bundle to filesystem
    dlog("Copying hotword model file to filesystem: $finalPath");
    final ByteData bytes = await rootBundle.load("$kHotwordAssetsDirectory/$filename");
    final buffer = bytes.buffer;
    await File(finalPath)
        .writeAsBytes(buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));

    return finalPath;
  }
}

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

// Audio playback

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter/services.dart' show rootBundle;

import './prefs.dart' show Prefs;
import './common.dart';

// List of audio file assets in bundle
const List<String> audioFiles = [
  // Voice-independent
  'rec_begin',
  'rec_cancel',
  'rec_confirm',
  // Voice dependent
  'conn-dora',
  'conn-karl',
  'dunno-dora',
  'dunno-karl',
  'err-dora',
  'err-karl',
];

// These sounds are the same regardless of voice ID settings.
const List<String> sessionSounds = [
  'rec_begin',
  'rec_cancel',
  'rec_confirm',
];

class AudioPlayer {
  // Class variables
  FlutterSoundPlayer player;
  Map<String, Uint8List> audioFileCache;

  // Constructor
  static final AudioPlayer _instance = AudioPlayer._internal();

  // Singleton pattern
  factory AudioPlayer() {
    return _instance;
  }

  // Initialization
  AudioPlayer._internal() {
    _init();
  }

  // Audio player setup and audio data preloading
  Future<void> _init() async {
    dlog('Initing audio player');
    await _preloadAudioFiles();
    player = FlutterSoundPlayer();
    await player.openAudioSession();
  }

  // This is never called since we keep the same audio
  // session for the duration of the app's lifetime.
  // Unfortunately, this means the app will crash on
  // Flutter's "hot restart" (but not "hot reload").
  // Future<void> _teardown() async {
  //   await player?.closeAudioSession();
  // }

  // Load all asset-bundled audio files into memory
  Future<void> _preloadAudioFiles() async {
    dlog("Preloading audio assets: ${audioFiles.toString()}");
    audioFileCache = Map();
    for (String fn in audioFiles) {
      ByteData bytes = await rootBundle.load("assets/audio/$fn.wav");
      audioFileCache[fn] = bytes.buffer.asUint8List();
    }
  }

  // Stop playback
  void stop() {
    player?.stopPlayer();
  }

  // Play remote audio file
  Future<void> playURL(String url, [Function() completionHandler]) async {
    _instance.stop();

    dlog("Playing remote audio file '$url'");
    player.startPlayer(
        fromURI: url,
        whenFinished: () {
          if (completionHandler != null) {
            completionHandler();
          }
        });
  }

  // Play a preloaded audio file bundled with the app
  Future<void> playSound(String soundName, [Function() completionHandler]) async {
    _instance.stop();

    // Different file name depending on whether female or male voice is set in prefs
    String fileName = soundName;
    if (sessionSounds.contains(soundName) == false) {
      String voiceName = (Prefs().stringForKey('voice_id') == 'Kona') ? 'dora' : 'karl';
      fileName = "$soundName-$voiceName";
    }

    dlog("Playing audio file '$fileName.wav'");
    player.startPlayer(
        fromDataBuffer: audioFileCache[fileName],
        sampleRate: kAudioSampleRate,
        whenFinished: () {
          if (completionHandler != null) {
            completionHandler();
          }
        });
  }
}

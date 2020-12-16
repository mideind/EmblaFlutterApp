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
  Map<String, Uint8List> audioFileCache = Map();

  // Constructor
  static final AudioPlayer _instance = AudioPlayer._internal();

  // Singleton pattern
  factory AudioPlayer() {
    return _instance;
  }

  // Initialization
  AudioPlayer._internal();

  // Audio player setup and audio data preloading
  Future<void> init() async {
    // Check if already inited
    if (audioFileCache.length > 0) {
      return;
    }
    await preloadAudioFiles();
    dlog('Initing audio player');
    player = FlutterSoundPlayer();
    await player.openAudioSession();
  }

  // Load all asset-bundled audio files into memory
  Future<void> preloadAudioFiles() async {
    dlog("Preloading audio assets: ${audioFiles.toString()}");
    for (String fn in audioFiles) {
      ByteData bytes = await rootBundle.load("assets/audio/$fn.wav");
      audioFileCache[fn] = bytes.buffer.asUint8List();
    }
  }

  // Stop playback
  void stop() {
    player.stopPlayer();
  }

  // Play remote audio file
  Future<void> playURL(String url, [Function completionHandler]) async {
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
  Future<void> playSound(String soundName, [Function completionHandler]) async {
    _instance.stop();

    String fileName = soundName;
    if (sessionSounds.contains(soundName) == false) {
      String voiceName = (Prefs().stringForKey('voice_id') == 'Kona') ? 'dora' : 'karl';
      fileName = "$soundName-$voiceName";
    }

    dlog("Playing audio file '$fileName.wav'");
    player.startPlayer(
        fromDataBuffer: audioFileCache[fileName],
        sampleRate: 16000,
        whenFinished: () {
          if (completionHandler != null) {
            completionHandler();
          }
        });
  }
}

// Future<void> playURL(String url, [Function completionHandler]) async {
// Silence annoying warning on iOS
//audioPlayer.monitorNotificationStateChanges(defaultPlayerHandler);

// stopSound();

// if (completionHandler != null) {
//   _subscribe(completionHandler);
// }

// dlog("Playing remote audio file $url");
// try {
//   await audioPlayer.play(url);
// } catch (e) {
//   if (completionHandler != null) {
//     completionHandler(true);
//   }
// }
// }

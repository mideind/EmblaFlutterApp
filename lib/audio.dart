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

// Audio playback

import 'dart:async';
import 'dart:typed_data';
import 'dart:math';

import 'package:filesize/filesize.dart' show filesize;
import 'package:logger/logger.dart' show Level;
import 'package:flutter_sound_lite/flutter_sound.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import './common.dart';
import './prefs.dart' show Prefs;

// List of audio file assets in bundle
const List<String> audioFiles = [
  // Voice-independent
  'rec_begin',
  'rec_cancel',
  'rec_confirm',
  // Voice dependent
  'conn-dora',
  'conn-karl',
  'dunno01-dora',
  'dunno02-dora',
  'dunno03-dora',
  'dunno04-dora',
  'dunno05-dora',
  'dunno06-dora',
  'dunno07-dora',
  'dunno01-karl',
  'dunno02-karl',
  'dunno03-karl',
  'dunno04-karl',
  'dunno05-karl',
  'dunno06-karl',
  'dunno07-karl',
  'err-dora',
  'err-karl',
];

// These sounds are the same regardless of voice ID settings.
const List<String> sessionSounds = [
  'rec_begin',
  'rec_cancel',
  'rec_confirm',
];

// Singleton class that handles all audio playback
class AudioPlayer {
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
    _preloadAudioFiles();
    player = FlutterSoundPlayer(logLevel: Level.error);
    player.openAudioSession();
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
    audioFileCache = <String, Uint8List>{};
    for (String fn in audioFiles) {
      ByteData bytes = await rootBundle.load("assets/audio/$fn.wav");
      audioFileCache[fn] = bytes.buffer.asUint8List();
    }
  }

  // Stop playback
  void stop() {
    dlog('Stopping audio playback');
    player?.stopPlayer();
  }

  // Play remote audio file
  Future<void> playURL(String url, Function(bool) completionHandler) async {
    //_instance.stop();

    dlog("Playing audio file URL '${url.substring(0, 200)}'");
    try {
      Uint8List data;
      Uri uri = Uri.parse(url);

      if (uri.scheme == 'data') {
        UriData dataURI = UriData.fromUri(uri);
        data = dataURI.contentAsBytes();
      } else {
        data = await http.readBytes(Uri.parse(url));
      }
      dlog("Audio file is ${filesize(data.lengthInBytes, 1)} (${data.lengthInBytes} bytes)");

      player.startPlayer(
          fromDataBuffer: data,
          codec: Codec.mp3,
          whenFinished: () {
            completionHandler(false);
          });
    } catch (e) {
      dlog('Error downloading remote file: $e');
      completionHandler(true);
    }
  }

  String playDunno([Function() completionHandler]) {
    int rnd = Random().nextInt(7) + 1;
    String num = rnd.toString().padLeft(2, '0');
    String fn = "dunno$num";
    playSound(fn, completionHandler);
    Map dunnoStrings = {
      "dunno01": "Ég get ekki svarað því.",
      "dunno02": "Ég get því miður ekki svarað því.",
      "dunno03": "Ég kann ekki svar við því.",
      "dunno04": "Ég skil ekki þessa fyrirspurn.",
      "dunno05": "Ég veit það ekki.",
      "dunno06": "Því miður skildi ég þetta ekki.",
      "dunno07": "Því miður veit ég það ekki.",
    };
    return dunnoStrings[fn];
  }

  // Play a preloaded wav audio file bundled with the app
  void playSound(String soundName, [Function() completionHandler]) {
    _instance.stop();

    // Different file name depending on whether female or male voice is set in prefs
    String fileName = soundName;
    if (sessionSounds.contains(soundName) == false) {
      String voiceName = Prefs().stringForKey('voice_id').toLowerCase();
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

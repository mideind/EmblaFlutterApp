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

// Audio playback

import 'dart:async';
import 'dart:typed_data';
import 'dart:math';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart' show rootBundle;

import 'package:http/http.dart' as http;
import 'package:logger/logger.dart' show Level;
import 'package:filesize/filesize.dart' show filesize;
import 'package:flutter_sound/flutter_sound.dart';

import './common.dart';
import './prefs.dart' show Prefs;
import './util.dart';

// These sounds are always the same regardless of voice ID settings
const List<String> sessionSounds = [
  'rec_begin',
  'rec_cancel',
  'rec_confirm',
];

/// Singleton class that handles all audio playback
class AudioPlayer {
  final FlutterSoundPlayer player = FlutterSoundPlayer(logLevel: Level.error);
  final Map<String, Uint8List> audioFileCache = <String, Uint8List>{};

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
    await player.openPlayer();
  }

  // Load all asset-bundled audio files into memory
  Future<void> _preloadAudioFiles() async {
    // List of audio file assets in bundle
    final List<String> audioFiles = List.from(sessionSounds);

    List<String> voiceSpecificSounds = [
      "conn",
      "err",
      "voicespeed",
      "mynameis",
      "dunno01",
      "dunno02",
      "dunno03",
      "dunno04",
      "dunno05",
      "dunno06",
      "dunno07"
    ];

    List<String> voiceNames = kSpeechSynthesisVoices;
    if (kDebugMode) {
      voiceNames = kSpeechSynthesisDebugVoices;
    }
    for (String voiceName in voiceNames) {
      final String vn = voiceName.asciify().toLowerCase();
      for (String sound in voiceSpecificSounds) {
        audioFiles.add("$sound-$vn");
      }
    }

    dlog("Preloading audio assets: ${audioFiles.toString()}");
    for (String fn in audioFiles) {
      final ByteData bytes = await rootBundle.load("assets/audio/$fn.wav");
      audioFileCache[fn] = bytes.buffer.asUint8List();
    }
  }

  /// Stop playback
  void stop() {
    dlog('Stopping audio playback');
    player.stopPlayer();
  }

  /// Play remote audio file
  Future<void> playURL(String url, Function(bool)? completionHandler) async {
    //_instance.stop();

    String displayURL = url;
    if (displayURL.length >= 200) {
      displayURL = "${displayURL.substring(0, 200)}…";
    }

    dlog("Playing audio file URL '$displayURL'");

    try {
      Uint8List? data;
      final Uri uri = Uri.parse(url);

      if (uri.scheme == 'data') {
        UriData dataURI = UriData.fromUri(uri);
        data = dataURI.contentAsBytes();
      } else {
        data = await http.readBytes(uri);
      }
      dlog("Audio file is ${filesize(data.lengthInBytes, 1)} (${data.lengthInBytes} bytes)");

      player.setSpeed(1.0);
      player.startPlayer(
          fromDataBuffer: data,
          codec: Codec.mp3,
          whenFinished: () {
            completionHandler!(false);
          });
    } catch (e) {
      dlog('Error downloading remote file: $e');
      completionHandler!(true);
    }
  }

  /// Play "I don't know" local audio file and return string
  /// with the text of the spoken reply (for showing in the UI)
  String? playDunno([Function()? completionHandler]) {
    final int rnd = Random().nextInt(7) + 1;
    final String num = rnd.toString().padLeft(2, '0');
    final String fn = "dunno$num";

    playSound(fn, completionHandler);

    final Map<String, String> dunnoStrings = {
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

  /// Play a preloaded wav audio file bundled with the app
  void playSound(String soundName, [Function()? completionHandler]) {
    _instance.stop();

    // Different file name depending on which voice is set in prefs
    String fileName = soundName;
    if (sessionSounds.contains(soundName) == false) {
      String? prefVoice = Prefs().stringForKey('voice_id') ?? kDefaultVoice;
      String voiceName = prefVoice.asciify().toLowerCase();
      fileName = "$soundName-$voiceName";
    }

    // Make sure the file is in the cache
    if (audioFileCache.containsKey(fileName) == false) {
      dlog("Audio file '$fileName' not found in cache!");
      return;
    }

    dlog("Playing audio file '$fileName.wav'");
    player.setSpeed(Prefs().doubleForKey("voice_speed") ?? 1.0);
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

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

import 'package:audioplayers/audio_cache.dart';
import 'package:audioplayers/audioplayers.dart';

import './prefs.dart' show Prefs;
import './common.dart';

final audioPlayer = AudioPlayer(/*mode: PlayerMode.LOW_LATENCY*/);
final audioCache = new AudioCache(fixedPlayer: audioPlayer);

StreamSubscription completionStreamSubscription;
StreamSubscription errorStreamSubscription;

void defaultPlayerHandler(AudioPlayerState value) {
  // Do nothing
  //dlog("Audio player state changed: " + value.toString());
}

const List<String> audioFiles = [
  // Voice-independent
  'audio/rec_begin.wav',
  'audio/rec_cancel.wav',
  'audio/rec_confirm.wav',
  // Voice dependent
  'audio/conn-dora.wav',
  'audio/conn-karl.wav',
  'audio/dunno-dora.wav',
  'audio/dunno-karl.wav',
  'audio/err-dora.wav',
  'audio/err-karl.wav',
];

// These sounds are the same regardless of voice ID settings.
const List<String> sessionSounds = [
  'rec_begin',
  'rec_cancel',
  'rec_confirm',
];

Future<void> preloadAudioFiles() async {
  dlog('Preloading audio assets: ' + audioFiles.toString());
  await audioCache.loadAll(audioFiles);
}

void stopSound() {
  _cancelSubscriptions();
  audioPlayer?.stop();
}

void _subscribe(Function handler) {
  _cancelSubscriptions();
  completionStreamSubscription = audioPlayer.onPlayerCompletion.listen((event) {
    handler(false);
  });
  errorStreamSubscription = audioPlayer.onPlayerError.listen((event) {
    handler(true);
  });
}

void _cancelSubscriptions() {
  completionStreamSubscription?.cancel();
  errorStreamSubscription?.cancel();
}

Future<void> playURL(String url, [Function completionHandler]) async {
  // Silence annoying warning on iOS
  //audioPlayer.monitorNotificationStateChanges(defaultPlayerHandler);

  stopSound();

  if (completionHandler != null) {
    _subscribe(completionHandler);
  }

  dlog("Playing remote audio file $url");
  await audioPlayer.play(url);
}

void playSound(String soundName, [Function completionHandler]) {
  // Silence annoying warning on iOS
  //audioPlayer.monitorNotificationStateChanges(defaultPlayerHandler);

  stopSound();

  if (completionHandler != null) {
    _subscribe(completionHandler);
  }

  String assetPath;
  if (sessionSounds.contains(soundName)) {
    assetPath = "audio/$soundName.wav";
  } else {
    String voiceName = (Prefs().stringForKey('voice_id') == 'Kona') ? 'dora' : 'karl';
    assetPath = "audio/$soundName-$voiceName.wav";
  }
  dlog("Playing audio file '$assetPath'");
  audioCache.play(assetPath);
}

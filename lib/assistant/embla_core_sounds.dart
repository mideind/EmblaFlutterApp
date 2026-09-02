/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2026 Miðeind ehf. <mideind@mideind.is>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

// SessionSounds backed by EmblaCore's bundled WAV assets. Kept in its own
// file so the session and its tests never have to touch an audio plugin.

import 'package:embla_core/embla_core.dart' show AudioPlayer;

import '../common.dart' show kDefaultVoiceID;
import 'session_sounds.dart';

class EmblaCoreSessionSounds implements SessionSounds {
  const EmblaCoreSessionSounds();

  @override
  String? playDunno({
    required String voiceID,
    required double speed,
    required void Function() onDone,
  }) {
    return AudioPlayer().playDunno(_voice(voiceID), onDone, speed);
  }

  @override
  void playError({required String voiceID, required double speed}) {
    AudioPlayer().playSound('err', _voice(voiceID), null, speed);
  }

  @override
  void playConfirm() {
    AudioPlayer().playSessionConfirm();
  }

  @override
  void playCancel() {
    AudioPlayer().playSessionCancel();
  }

  @override
  void stop() {
    AudioPlayer().stop();
  }

  static String _voice(String voiceID) =>
      voiceID.trim().isEmpty ? kDefaultVoiceID : voiceID;
}

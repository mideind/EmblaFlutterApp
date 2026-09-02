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

// Thin seam in front of embla_core's `AudioRecorder`/`AudioPlayer` singletons
// so batch ASR engines can be unit-tested: the flutter_sound plugins are not
// available in `flutter test`, and merely constructing `AudioRecorder()` opens
// the native recorder.
//
// The production implementation must behave exactly like the recorder usage in
// embla_core's `EmblaSession`: `AudioRecorder().start(dataHandler, errHandler)`
// followed by `AudioRecorder().stop()`.

import 'dart:typed_data';

import 'package:embla_core/embla_core.dart' show AudioPlayer, AudioRecorder;

/// Microphone capture (16 kHz mono 16-bit PCM) plus the session start cue.
abstract class AsrAudioSource {
  /// Starts capture. [onData] receives raw PCM chunks, [onError] a message.
  Future<void> start(void Function(Uint8List data) onData, void Function(String message) onError);

  /// Stops capture and releases the microphone.
  Future<void> stop();

  /// Normalized level (0.0-1.0) of the most recent samples.
  double signalStrength();

  /// Plays the "start listening" cue. Lives here so that engines can be
  /// tested without the audio plugins.
  void playStartSound();
}

/// Default implementation, backed by the embla_core singletons.
class RecorderAudioSource implements AsrAudioSource {
  const RecorderAudioSource();

  @override
  Future<void> start(
      void Function(Uint8List data) onData, void Function(String message) onError) async {
    await AudioRecorder().start(onData, onError);
  }

  @override
  Future<void> stop() async {
    await AudioRecorder().stop();
  }

  @override
  double signalStrength() => AudioRecorder().signalStrength();

  @override
  void playStartSound() => AudioPlayer().playSessionStart();
}

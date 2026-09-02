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

// UI sound effects used by the assistant session, abstracted so the
// session can be unit-tested without audio plugins.

abstract class SessionSounds {
  /// Plays a canned "I don't know" clip and returns its text for display.
  /// [onDone] is invoked when playback finishes.
  String? playDunno({required String voiceID, required double speed, required void Function() onDone});

  /// Plays the error sound.
  void playError({required String voiceID, required double speed});

  /// Plays the short confirmation blip after a final transcript.
  void playConfirm();

  /// Plays the cancellation sound.
  void playCancel();

  /// Stops any playing sound.
  void stop();
}

/// No-op implementation for tests.
class SilentSessionSounds implements SessionSounds {
  @override
  String? playDunno({required String voiceID, required double speed, required void Function() onDone}) {
    onDone();
    return null;
  }

  @override
  void playError({required String voiceID, required double speed}) {}
  @override
  void playConfirm() {}
  @override
  void playCancel() {}
  @override
  void stop() {}
}

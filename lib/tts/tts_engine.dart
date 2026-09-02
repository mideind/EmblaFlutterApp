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

// Text-to-speech engine contract.

abstract class TtsEngine {
  /// Engine identifier, e.g. `icespeak`, `elevenlabs`.
  String get id;

  /// Voice identifiers this engine supports (for settings UI).
  List<String> get voices;

  /// Synthesizes `text` and plays it. `onDone(err)` is called when playback
  /// finishes (err == false) or when synthesis/playback failed (err == true).
  /// The returned future completes once playback has been *started* (or failed).
  Future<void> speak(
    String text, {
    required String voice,
    required double speed,
    required void Function(bool err) onDone,
  });

  /// Stops any ongoing playback.
  void stop();
}

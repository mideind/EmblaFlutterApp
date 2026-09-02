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

// Speech recognition engine contract.
//
// Implementations own the microphone while `listen()` is active. The caller
// guarantees that nothing else (e.g. hotword detection) is using the
// shared `AudioRecorder` at that time.

sealed class AsrEvent {
  const AsrEvent();
}

/// Interim transcript (streaming engines only).
class AsrPartial extends AsrEvent {
  final String text;
  const AsrPartial(this.text);
}

/// Final transcript. `text` may be empty if nothing was heard.
class AsrFinal extends AsrEvent {
  final String text;
  const AsrFinal(this.text);
}

class AsrError extends AsrEvent {
  final String message;
  const AsrError(this.message);
}

abstract class AsrEngine {
  /// Engine identifier, e.g. `ratatoskur`, `hreimur`.
  String get id;

  /// Whether the engine emits `AsrPartial` events while listening.
  bool get emitsPartials;

  /// Whether the caller must call `finish()` to end capture
  /// (batch engines without end-of-speech detection).
  bool get needsManualStop;

  /// Starts microphone capture. The stream closes after an
  /// `AsrFinal` or `AsrError` event has been emitted.
  Stream<AsrEvent> listen();

  /// Ends capture early and produces the final result
  /// (batch: upload; streaming: no-op or cancel).
  Future<void> finish();

  /// Aborts capture; no further events are emitted.
  Future<void> cancel();
}

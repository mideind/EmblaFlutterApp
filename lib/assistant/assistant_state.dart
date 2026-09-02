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

// States of an assistant session (one user turn).

enum AssistantState {
  /// Nothing going on.
  idle,

  /// Microphone open, ASR engine consuming audio.
  listening,

  /// Audio captured, waiting for the (batch) ASR result.
  transcribing,

  /// Waiting for the LLM.
  thinking,

  /// Executing one or more tool calls requested by the LLM.
  acting,

  /// Playing the spoken answer.
  speaking,

  /// Turn finished normally (or was cancelled).
  done,

  /// Turn ended with an error.
  error,
}

extension AssistantStateX on AssistantState {
  /// True while the session owns the microphone, network or speaker.
  bool get isActive =>
      this != AssistantState.idle && this != AssistantState.done && this != AssistantState.error;

  /// The session button shows the live waveform in this state.
  bool get showsWaveform => this == AssistantState.listening;

  /// The session button shows the logo animation in these states.
  bool get showsAnimation =>
      this == AssistantState.transcribing ||
      this == AssistantState.thinking ||
      this == AssistantState.acting ||
      this == AssistantState.speaking;
}

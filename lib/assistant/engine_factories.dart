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

// The single seam between the session route (which only knows the abstract
// contracts) and the concrete engines. Every function here is deliberately
// unimplemented: the pipeline streams (ASR, LLM, TTS, tools, prompt) fill
// them in at integration time, and no other UI code needs to change.
//
// Callers must be prepared for these to throw until then.

import '../asr/asr_engine.dart' show AsrEngine;
import '../llm/llm_client.dart' show LlmClient;
import '../tools/tool.dart' show ToolRegistry;
import '../tts/tts_engine.dart' show TtsEngine;
import 'session_sounds.dart' show SessionSounds;

const String _kUnimplemented = 'wired at integration';

/// Creates the speech recognition engine selected in settings.
/// [provider] is one of the ids in `kASRProviders` (`ratatoskur`, `hreimur`).
/// [engine] is the server-side ASR engine for streaming ASR (e.g. `azure`).
AsrEngine createAsrEngine({
  required String provider,
  required String serverURL,
  required String apiKey,
  required String engine,
  required bool privateMode,
  String? clientID,
  String? clientType,
  String? clientVersion,
}) {
  throw UnimplementedError(_kUnimplemented);
}

/// Creates the LLM client for [provider] (e.g. `openai`) and [model].
LlmClient createLlmClient({
  required String provider,
  required String model,
  required String apiKey,
}) {
  throw UnimplementedError(_kUnimplemented);
}

/// Creates the speech synthesis engine for [provider]
/// (one of the ids in `kTTSProviders`).
TtsEngine createTtsEngine({
  required String provider,
  required String serverURL,
  required String apiKey,
}) {
  throw UnimplementedError(_kUnimplemented);
}

/// Creates the tool registry, platform-filtered.
ToolRegistry createToolRegistry({
  required String serverURL,
  required String apiKey,
}) {
  throw UnimplementedError(_kUnimplemented);
}

/// Creates the UI sound effects player (wraps `AudioPlayer` from embla_core).
SessionSounds createSessionSounds() {
  throw UnimplementedError(_kUnimplemented);
}

/// Builds the Icelandic system prompt for a single turn.
String createSystemPrompt({
  required DateTime now,
  List<double>? location,
  required String platform,
  required bool privateMode,
  required Iterable<String> toolNames,
}) {
  throw UnimplementedError(_kUnimplemented);
}

/// Reads the API key for the LLM provider. Stand-in for the key reader that
/// lives in `lib/util.dart` (e.g. `readOpenAIAPIKey()`), kept here so the UI
/// does not have a compile-time dependency on it.
String readLlmAPIKey() {
  throw UnimplementedError(_kUnimplemented);
}

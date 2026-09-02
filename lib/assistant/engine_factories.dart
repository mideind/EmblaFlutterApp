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

// Engine factories: the single seam where the concrete ASR / LLM / TTS /
// tool implementations are wired into the assistant pipeline.

import '../asr/asr_engine.dart';
import '../asr/hreimur_batch_asr.dart';
import '../asr/ratatoskur_streaming_asr.dart';
import '../common.dart';
import '../llm/llm_client.dart';
import '../llm/openai_responses_client.dart';
import '../prefs.dart' show Prefs;
import '../tools/default_tools.dart';
import '../tools/tool.dart';
import '../tts/elevenlabs_tts.dart';
import '../tts/icespeak_tts.dart';
import '../tts/tts_engine.dart';
import '../util.dart' show readElevenLabsAPIKey, readOpenAIAPIKey;
import 'embla_core_sounds.dart';
import 'prompt.dart';
import 'session_sounds.dart';

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
  switch (provider) {
    case 'hreimur':
      return HreimurBatchAsr(serverURL: serverURL, apiKey: apiKey);
    case 'ratatoskur':
    default:
      return RatatoskurStreamingAsr(
        serverURL: serverURL,
        apiKey: apiKey,
        engine: engine,
        privateMode: privateMode,
        clientID: clientID,
        clientType: clientType,
        clientVersion: clientVersion,
      );
  }
}

LlmClient createLlmClient({
  required String provider,
  required String model,
  required String apiKey,
}) {
  switch (provider) {
    case 'openai':
    default:
      // Anthropic adapter is a later phase; fall back to OpenAI.
      return OpenAIResponsesClient(apiKey: apiKey, model: model);
  }
}

TtsEngine createTtsEngine({
  required String provider,
  required String serverURL,
  required String apiKey,
}) {
  switch (provider) {
    case 'elevenlabs':
      final String voiceId = Prefs().stringForKey('elevenlabs_voice_id') ?? kDefaultElevenLabsVoiceID;
      final String key = readElevenLabsAPIKey();
      if (voiceId.isEmpty || key.isEmpty) {
        dlog('ElevenLabs voice ID or API key missing, falling back to Icespeak');
        return IcespeakTts(serverURL: serverURL, apiKey: apiKey);
      }
      return ElevenLabsTts(apiKey: key, voiceId: voiceId);
    case 'icespeak':
    default:
      return IcespeakTts(serverURL: serverURL, apiKey: apiKey);
  }
}

ToolRegistry createToolRegistry({
  required String serverURL,
  required String apiKey,
}) {
  return buildDefaultToolRegistry(serverURL: serverURL, apiKey: apiKey);
}

SessionSounds createSessionSounds() => const EmblaCoreSessionSounds();

String createSystemPrompt({
  required DateTime now,
  List<double>? location,
  required String platform,
  required bool privateMode,
  required Iterable<String> toolNames,
}) {
  return buildSystemPrompt(
    now: now,
    location: location,
    platform: platform,
    privateMode: privateMode,
    toolNames: toolNames,
  );
}

String readLlmAPIKey() => readOpenAIAPIKey();

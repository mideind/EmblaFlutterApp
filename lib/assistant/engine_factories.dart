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
import '../common.dart';
import '../llm/llm_client.dart';
import '../llm/gemini_client.dart';
import '../llm/openai_responses_client.dart';
import '../prefs.dart' show Prefs;
import '../tools/default_tools.dart';
import '../tools/device_tools.dart';
import '../tools/tool.dart';
import '../tts/elevenlabs_tts.dart';
import '../tts/icespeak_tts.dart';
import '../tts/tts_engine.dart';
import '../util.dart' show readElevenLabsAPIKey, readGeminiAPIKey, readOpenAIAPIKey;
import 'embla_core_sounds.dart';
import 'prompt.dart';
import 'session_sounds.dart';

/// Hreimur is Miðeind's own Icelandic ASR and the only engine 2.0 uses. The
/// Ratatoskur streaming path was Azure-backed; streaming returns here once
/// Hreimur itself streams.
AsrEngine createAsrEngine({
  required String serverURL,
  required String apiKey,
  CapturedAudio? capturedAudio,
}) {
  return HreimurBatchAsr(
    serverURL: serverURL,
    apiKey: apiKey,
    // In fused mode Hreimur still does the recording and silence detection --
    // it just hands the WAV over instead of uploading it.
    onCapturedWav: capturedAudio == null ? null : (wav) => capturedAudio.wav = wav,
  );
}

LlmClient createLlmClient({
  required String provider,
  required String model,
  required String apiKey,
}) {
  switch (provider) {
    case 'gemini':
      final String key = readGeminiAPIKey();
      if (key.isEmpty) {
        // Silently answering with the wrong provider is how the ElevenLabs
        // fallback hid a bug for a whole session, so say which key is missing.
        dlog('LLM: falling back to OpenAI, Gemini API key is missing');
        return OpenAIResponsesClient(apiKey: apiKey, model: kDefaultOpenAIModel);
      }
      final String geminiModel =
          model.startsWith('gemini') ? model : kDefaultGeminiModel;
      dlog('LLM: Gemini, model $geminiModel');
      return GeminiClient(apiKey: key, model: geminiModel);
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
  required String voiceID,
}) {
  switch (provider) {
    case 'elevenlabs':
      final String voiceId = Prefs().stringForKey('elevenlabs_voice_id') ?? kDefaultElevenLabsVoiceID;
      final String key = readElevenLabsAPIKey();
      if (voiceId.isEmpty || key.isEmpty) {
        // Silent fallback here is easy to mistake for ElevenLabs being broken,
        // so say which half is missing.
        dlog('TTS: falling back to Icespeak, ElevenLabs '
            '${key.isEmpty ? "API key" : "voice ID"} is missing');
        return IcespeakTts(serverURL: serverURL, apiKey: apiKey, voice: voiceID);
      }
      dlog('TTS: ElevenLabs, voice $voiceId');
      return ElevenLabsTts(apiKey: key, voiceId: voiceId);
    case 'icespeak':
    default:
      return IcespeakTts(serverURL: serverURL, apiKey: apiKey, voice: voiceID);
  }
}

ToolRegistry createToolRegistry({
  required String serverURL,
  required String apiKey,
}) {
  final ToolRegistry registry = buildDefaultToolRegistry(serverURL: serverURL, apiKey: apiKey);
  // Device actions (calendar, reminders, timers/alarms, message drafts)
  registry.registerAll(buildDeviceTools());
  return registry;
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

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

// Assembles an AssistantSessionConfig from user settings. This is the only
// place that translates prefs into engine choices; the session route just
// asks for a config, attaches its handlers and starts a session.

import 'dart:io' show Platform;

import '../common.dart';
import '../info.dart' show getClientType, getMarketingVersion, getUniqueDeviceIdentifier;
import '../loc.dart' show LocationTracker;
import '../prefs.dart' show Prefs;
import '../tools/tool.dart' show ToolContext;
import '../asr/asr_engine.dart' show CapturedAudio;
import '../util.dart' show readGeminiAPIKey, readServerAPIKey;
import 'assistant_session.dart';
import 'engine_factories.dart';

/// Builds a session configuration for one user turn. Handlers are left null;
/// the session route sets them before creating the AssistantSession.
Future<AssistantSessionConfig> buildAssistantSessionConfig() async {
  final String serverURL = Prefs().stringForKey('ratatoskur_server') ?? kDefaultRatatoskurServer;
  final String serverAPIKey = readServerAPIKey();

  final String ttsProvider = Prefs().stringForKey('tts_provider') ?? kDefaultTTSProvider;
  final String llmProvider = Prefs().stringForKey('llm_provider') ?? kDefaultLLMProvider;
  final String llmModel = Prefs().stringForKey('llm_model') ?? kDefaultOpenAIModel;

  final String voiceID = Prefs().stringForKey('voice_id') ?? kDefaultVoiceID;
  final double voiceSpeed = Prefs().doubleForKey('voice_speed') ?? kDefaultVoiceSpeed;

  // Client info, only sent to our own servers.
  final String clientID = await getUniqueDeviceIdentifier();
  final String clientType = await getClientType();
  final String clientVersion = await getMarketingVersion();

  final tools = createToolRegistry(serverURL: serverURL, apiKey: serverAPIKey);

  // Gemini takes the recording directly, so the ASR engine only captures.
  final CapturedAudio? capturedAudio =
      llmProvider == 'gemini' && readGeminiAPIKey().isNotEmpty ? CapturedAudio() : null;

  return AssistantSessionConfig(
    asr: createAsrEngine(
        serverURL: serverURL, apiKey: serverAPIKey, capturedAudio: capturedAudio),
    llm: createLlmClient(
      provider: llmProvider,
      model: llmModel,
      apiKey: readLlmAPIKey(),
    ),
    tts: createTtsEngine(
      provider: ttsProvider,
      serverURL: serverURL,
      apiKey: serverAPIKey,
      voiceID: voiceID,
    ),
    tools: tools,
    conversation: Conversation.shared,
    sounds: createSessionSounds(),
    buildSystemPrompt: () => createSystemPrompt(
      now: DateTime.now(),
      location: sharedLocation(),
      platform: Platform.operatingSystem,
      privateMode: Prefs().boolForKey('privacy_mode'),
      toolNames: tools.tools.map((t) => t.name),
    ),
    buildToolContext: () => ToolContext(
      now: DateTime.now(),
      location: sharedLocation(),
      voiceID: voiceID,
      privateMode: Prefs().boolForKey('privacy_mode'),
      clientID: clientID,
      clientType: clientType,
      clientVersion: clientVersion,
    ),
    capturedAudio: capturedAudio,
    voiceID: voiceID,
    voiceSpeed: voiceSpeed,
  );
}

/// The user's coordinates, but only if location sharing is on and we're not
/// in privacy mode. Location is never handed to third-party services.
List<double>? sharedLocation() {
  if (Prefs().boolForKey('share_location') == false || Prefs().boolForKey('privacy_mode') == true) {
    return null;
  }
  return LocationTracker().location;
}

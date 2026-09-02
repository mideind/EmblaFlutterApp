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

// AssistantSession: orchestrates one user turn.
//
//   idle → listening → transcribing → thinking ⇄ acting → speaking → done
//
// Mirrors the callback style of `EmblaSessionConfig` so the session route
// only needs small changes. One AssistantSession per user turn; the
// long-lived object is the [Conversation].

import 'dart:async';

import '../asr/asr_engine.dart';
import '../common.dart' show dlog, kMaxToolIterations;
import '../llm/llm_client.dart';
import '../tools/tool.dart';
import '../tts/tts_engine.dart';
import 'assistant_state.dart';
import 'conversation.dart';
import 'reply.dart';
import 'session_sounds.dart';

export 'assistant_state.dart';
export 'conversation.dart';
export 'reply.dart';

class AssistantException implements Exception {
  final String message;
  const AssistantException(this.message);
  @override
  String toString() => message;
}

class AssistantSessionConfig {
  AsrEngine asr;
  LlmClient llm;
  TtsEngine tts;
  ToolRegistry tools;
  Conversation conversation;
  SessionSounds sounds;

  /// Builds the system prompt for this turn.
  String Function() buildSystemPrompt;

  /// Builds the ambient tool context for this turn.
  ToolContext Function() buildToolContext;

  String voiceID;
  double voiceSpeed;

  // Handlers
  void Function(AssistantState state)? onStateChanged;
  void Function(String partial)? onPartialTranscript;
  void Function(String finalText)? onFinalTranscript;

  /// The assistant's displayable reply has been added to the conversation.
  void Function(Turn reply)? onReply;
  void Function(String label)? onToolActivity;

  /// A tool asked the UI to open a URL (called after the reply was spoken).
  void Function(Uri url)? onOpenURL;
  void Function()? onDone;
  void Function(String message)? onError;

  AssistantSessionConfig({
    required this.asr,
    required this.llm,
    required this.tts,
    required this.tools,
    required this.conversation,
    required this.sounds,
    required this.buildSystemPrompt,
    required this.buildToolContext,
    this.voiceID = '',
    this.voiceSpeed = 1.0,
  });
}

class AssistantSession {
  AssistantSession(this.config);

  final AssistantSessionConfig config;

  AssistantState _state = AssistantState.idle;
  AssistantState get state => _state;

  StreamSubscription<AsrEvent>? _asrSub;
  bool _cancelled = false;

  /// Per-stage timings for debug output.
  final Map<String, Duration> timings = {};
  final Stopwatch _stageClock = Stopwatch();
  String? _stageName;

  bool isActive() => _state.isActive;

  /// Voice turn: listen → transcribe → run.
  Future<void> startVoice() async {
    _requireIdle();
    _setState(AssistantState.listening);
    _beginStage('asr');

    final completer = Completer<String?>();
    _asrSub = config.asr.listen().listen((event) {
      switch (event) {
        case AsrPartial(:final text):
          config.onPartialTranscript?.call(text);
        case AsrFinal(:final text):
          if (!completer.isCompleted) completer.complete(text);
        case AsrError(:final message):
          if (!completer.isCompleted) completer.completeError(AssistantException(message));
      }
    }, onError: (Object e) {
      if (!completer.isCompleted) completer.completeError(e);
    }, onDone: () {
      if (!completer.isCompleted) completer.complete(null);
    });

    String? text;
    try {
      text = await completer.future;
    } catch (e) {
      if (_cancelled) return;
      // ASR engines play their own error cue (embla_core does for the
      // streaming engine), so don't double it here.
      await _error('Villa í talgreiningu: $e', playSound: false);
      return;
    } finally {
      await _asrSub?.cancel();
      _asrSub = null;
      _endStage();
    }
    if (_cancelled) return;

    if (text == null || text.trim().isEmpty) {
      dlog('Nothing heard, ending turn');
      _finish();
      return;
    }
    config.sounds.playConfirm();
    config.onFinalTranscript?.call(text);
    await _runTurn(text);
  }

  /// Typed turn: skip the microphone.
  Future<void> submitText(String text) async {
    _requireIdle();
    if (text.trim().isEmpty) {
      _finish();
      return;
    }
    await _runTurn(text.trim());
  }

  /// For batch ASR engines: stop capturing and transcribe what we have.
  Future<void> finishListening() async {
    if (_state != AssistantState.listening) return;
    _setState(AssistantState.transcribing);
    await config.asr.finish();
  }

  /// User- or system-initiated cancellation.
  Future<void> cancel() async {
    if (!isActive()) return;
    dlog('AssistantSession cancelled in state $_state');
    _cancelled = true;
    await _asrSub?.cancel();
    _asrSub = null;
    await config.asr.cancel();
    config.tts.stop();
    config.sounds.stop();
    if (_state == AssistantState.listening || _state == AssistantState.transcribing) {
      // The streaming ASR wrapper plays its own cancel sound; keep it uniform.
      config.sounds.playCancel();
    }
    _finish();
  }

  // ---------------------------------------------------------------------

  Future<void> _runTurn(String userText) async {
    _setState(AssistantState.thinking);
    final conv = config.conversation;
    conv.resetIfStale();
    conv.addUser(userText);

    String? pendingImage;
    Uri? pendingOpenURL;

    try {
      final ctx = config.buildToolContext();
      final tools = config.tools.specs();
      final instructions = config.buildSystemPrompt();

      for (int i = 0; i < kMaxToolIterations; i++) {
        if (_cancelled) return;
        _beginStage('llm${i > 0 ? i : ''}');
        final resp = await config.llm.complete(LlmRequest(
          instructions: instructions,
          messages: List.unmodifiable(conv.history),
          tools: tools,
          responseSchema: AssistantReply.schema,
        ));
        _endStage();
        if (_cancelled) return;

        if (resp.hasToolCalls) {
          conv.addHistory(AssistantMessage(text: resp.text, toolCalls: resp.toolCalls));
          _setState(AssistantState.acting);
          for (final call in resp.toolCalls) {
            if (_cancelled) return;
            final label = config.tools.lookup(call.name)?.activityLabel;
            if (label != null) {
              conv.addToolActivity(label);
              config.onToolActivity?.call(label);
            }
            _beginStage('tool:${call.name}');
            final result = await config.tools.dispatch(call, ctx);
            _endStage();
            dlog('Tool ${call.name} → ${result.toJson()}');
            conv.addHistory(ToolResultMessage(callId: call.id, name: call.name, outputJson: result.toJson()));
            pendingImage = result.imageURL ?? pendingImage;
            pendingOpenURL = result.openURL ?? pendingOpenURL;
          }
          _setState(AssistantState.thinking);
          continue;
        }

        // Final text reply
        final reply = AssistantReply.parse(resp.text ?? '');
        conv.addHistory(AssistantMessage(text: resp.text ?? ''));
        await _deliver(reply, imageURL: pendingImage, openURL: pendingOpenURL);
        return;
      }
      throw const AssistantException('Of margar verkfærakallanir í einni umferð');
    } catch (e) {
      if (_cancelled) return;
      await _error(e.toString());
    }
  }

  Future<void> _deliver(AssistantReply reply, {String? imageURL, Uri? openURL}) async {
    final conv = config.conversation;

    void afterSpeech(bool err) {
      if (_cancelled) return;
      if (err) {
        _error('Villa við talgervingu');
        return;
      }
      if (openURL != null) {
        config.onOpenURL?.call(openURL);
      }
      _finish();
    }

    if (reply.kind == ReplyKind.unknown) {
      _setState(AssistantState.speaking);
      final dunnoText = config.sounds.playDunno(
        voiceID: config.voiceID,
        speed: config.voiceSpeed,
        onDone: () => afterSpeech(false),
      );
      conv.addAssistant(dunnoText ?? reply.display);
      config.onReply?.call(conv.turns.last);
      return;
    }

    conv.addAssistant(reply.display, imageURL: imageURL);
    config.onReply?.call(conv.turns.last);

    if (reply.speech.trim().isEmpty) {
      afterSpeech(false);
      return;
    }
    _setState(AssistantState.speaking);
    _beginStage('tts');
    await config.tts.speak(
      reply.speech,
      voice: config.voiceID,
      speed: config.voiceSpeed,
      onDone: (err) {
        _endStage();
        afterSpeech(err);
      },
    );
  }

  Future<void> _error(String message, {bool playSound = true}) async {
    dlog('AssistantSession error: $message');
    _endStage();
    config.tts.stop();
    if (playSound) {
      config.sounds.playError(voiceID: config.voiceID, speed: config.voiceSpeed);
    }
    _setState(AssistantState.error);
    config.onError?.call(message);
  }

  void _finish() {
    _endStage();
    _logTimings();
    _setState(AssistantState.done);
    config.onDone?.call();
  }

  void _requireIdle() {
    if (_state != AssistantState.idle) {
      throw AssistantException('Session already started (state: $_state)');
    }
  }

  void _setState(AssistantState s) {
    if (_state == s) return;
    _state = s;
    config.onStateChanged?.call(s);
  }

  void _beginStage(String name) {
    _endStage();
    _stageName = name;
    _stageClock
      ..reset()
      ..start();
  }

  void _endStage() {
    final name = _stageName;
    if (name == null) return;
    _stageClock.stop();
    timings[name] = _stageClock.elapsed;
    _stageName = null;
  }

  void _logTimings() {
    if (timings.isEmpty) return;
    final parts = timings.entries.map((e) => '${e.key}: ${(e.value.inMilliseconds / 1000).toStringAsFixed(2)}s');
    dlog('Turn timings — ${parts.join(', ')}');
  }
}

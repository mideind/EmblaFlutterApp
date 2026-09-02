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

// Streaming ASR over Ratatoskur's `/rat/v1/short_asr` WebSocket, i.e. an
// `EmblaSession` with the query and TTS stages switched off. Gives live
// partial transcripts and server-side end-of-speech detection, so the caller
// never has to stop capture manually.
//
// `EmblaSession` is single-use: a fresh config + session is built on every
// `listen()`. The session plays the "start listening" cue itself when
// `audio` is on (that is why this engine takes a `playSounds` flag), and it
// also plays its own cancel sound when the server returns an empty final
// transcript. The confirm sound is the orchestrator's business, and
// `cancel()` here deliberately calls `EmblaSession.stop()` rather than
// `cancel()` so that the cancel sound is played exactly once, by the caller.

import 'dart:async';

import 'package:embla_core/embla_core.dart' show EmblaSession, EmblaSessionConfig;

import '../common.dart' show dlog;
import 'asr_engine.dart';

/// Creates the underlying session. Overridable for tests.
typedef EmblaSessionFactory = EmblaSession Function(EmblaSessionConfig config);

class RatatoskurStreamingAsr implements AsrEngine {
  RatatoskurStreamingAsr({
    required this.serverURL,
    required this.apiKey,
    this.engine,
    this.privateMode = false,
    this.clientID,
    this.clientType,
    this.clientVersion,
    this.playSounds = true,
    EmblaSessionFactory? sessionFactory,
  }) : _sessionFactory = sessionFactory ?? EmblaSession.new;

  /// Ratatoskur server URL, e.g. `https://api.greynir.is`.
  final String serverURL;

  /// Miðeind API key, sent as `X-API-Key` when fetching the socket token.
  final String apiKey;

  /// Server-side ASR engine name, lower-case (e.g. `azure`, `google`).
  /// `null` leaves the choice to the server.
  final String? engine;

  /// Suppresses client info in the greetings message.
  final bool privateMode;

  final String? clientID;
  final String? clientType;
  final String? clientVersion;

  /// Whether the session plays its own UI sounds (start cue, cancel, error).
  final bool playSounds;

  final EmblaSessionFactory _sessionFactory;

  StreamController<AsrEvent>? _controller;
  EmblaSession? _session;
  bool _sawFinal = false;
  bool _cancelled = false;
  bool _closed = false;

  /// The session backing the current `listen()` call, for debugging/tests.
  EmblaSession? get currentSession => _session;

  @override
  String get id => 'ratatoskur';

  @override
  bool get emitsPartials => true;

  @override
  bool get needsManualStop => false;

  @override
  Stream<AsrEvent> listen() {
    final StreamController<AsrEvent> controller = StreamController<AsrEvent>();
    _controller = controller;
    _sawFinal = false;
    _cancelled = false;
    _closed = false;

    final EmblaSessionConfig config = EmblaSessionConfig(server: serverURL)
      ..apiKey = apiKey
      ..engine = engine?.toLowerCase()
      ..privateMode = privateMode
      ..clientID = clientID
      ..clientType = clientType
      ..clientVersion = clientVersion
      // ASR only: no query stage, no speech synthesis.
      ..query = false
      ..tts = false
      ..audio = playSounds;

    config.onSpeechTextReceived = _handleSpeechText;
    config.onError = _handleError;
    config.onDone = _handleDone;

    final EmblaSession session = _sessionFactory(config);
    _session = session;

    try {
      // Fetches the socket token and opens the connection. Declared `void`,
      // so failures normally arrive via onError, but guard anyway.
      session.start();
    } catch (e) {
      dlog('Error starting streaming ASR session: $e');
      _emit(AsrError('Ekki náðist að hefja talgreiningu: $e'));
      _close();
    }

    return controller.stream;
  }

  /// Streaming ASR detects end of speech server-side, so there is nothing
  /// to flush. Kept as a no-op for interface parity with batch engines.
  @override
  Future<void> finish() async {}

  @override
  Future<void> cancel() async {
    if (_closed && _cancelled) {
      return;
    }
    dlog('Cancelling streaming ASR session');
    _cancelled = true;
    // Close before stopping: stop() fires onDone, which we must not honour.
    _close();
    // Silent stop; the caller owns the cancel sound.
    await _session?.stop();
  }

  // ---------------------------------------------------------------------

  void _handleSpeechText(String transcript, bool isFinal, Map<String, dynamic> msg) {
    if (_closed) {
      return;
    }
    if (!isFinal) {
      _emit(AsrPartial(transcript));
      return;
    }
    _sawFinal = transcript.trim().isNotEmpty;
    _emit(AsrFinal(transcript.trim()));
    _close();
  }

  void _handleError(String message) {
    if (_closed) {
      return;
    }
    _emit(AsrError(message));
    _close();
  }

  void _handleDone() {
    if (_closed) {
      return;
    }
    // The session ended without a usable transcript — embla_core cancels the
    // session on an empty final result and then calls onDone. Report it as an
    // empty final so the caller can end the turn quietly.
    if (!_sawFinal) {
      _emit(const AsrFinal(''));
    }
    _close();
  }

  void _emit(AsrEvent event) {
    if (_closed || _cancelled) {
      return;
    }
    _controller?.add(event);
  }

  void _close() {
    if (_closed) {
      return;
    }
    _closed = true;
    final StreamController<AsrEvent>? controller = _controller;
    _controller = null;
    controller?.close();
  }
}

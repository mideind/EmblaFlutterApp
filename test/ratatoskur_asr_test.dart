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

// Tests for the streaming ASR wrapper. The real `EmblaSession` needs a
// WebSocket and the audio plugins, so a fake session (implementing
// EmblaSession's implicit interface) stands in and drives the config
// callbacks the way the server would.


import 'package:embla_core/embla_core.dart'
    show EmblaSession, EmblaSessionConfig, EmblaSessionState;
import 'package:flutter_test/flutter_test.dart';

import 'package:embla/asr/asr_engine.dart';
import 'package:embla/asr/ratatoskur_streaming_asr.dart';

/// Stands in for `EmblaSession`; the test plays the role of the server.
class FakeEmblaSession implements EmblaSession {
  FakeEmblaSession(this.config);

  final EmblaSessionConfig config;

  @override
  EmblaSessionState state = EmblaSessionState.idle;

  int startCount = 0;
  int stopCount = 0;
  int cancelCount = 0;
  Object? startError;

  @override
  void start() {
    startCount++;
    if (startError != null) {
      throw startError!;
    }
    state = EmblaSessionState.streaming;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    state = EmblaSessionState.done;
    config.onDone?.call();
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
    await stop();
  }

  @override
  bool isActive() => state != EmblaSessionState.idle && state != EmblaSessionState.done;

  @override
  EmblaSessionState currentState() => state;

  // Server-driven events

  void sendPartial(String text) => config.onSpeechTextReceived?.call(text, false, const {});

  /// Mirrors embla_core: a final result stops the session (and thus fires
  /// onDone), an empty one cancels it.
  Future<void> sendFinal(String text) async {
    config.onSpeechTextReceived?.call(text, true, const {});
    if (text.isEmpty) {
      await cancel();
    } else {
      await stop();
    }
  }

  void sendError(String message) => config.onError?.call(message);
}

RatatoskurStreamingAsr build(void Function(FakeEmblaSession) capture,
    {bool playSounds = true, String? engine = 'Azure', bool privateMode = false}) {
  return RatatoskurStreamingAsr(
    serverURL: 'https://api.greynir.is',
    apiKey: 'test-api-key',
    engine: engine,
    privateMode: privateMode,
    clientID: 'client-1',
    clientType: 'flutter_test',
    clientVersion: '2.0.0',
    playSounds: playSounds,
    sessionFactory: (EmblaSessionConfig config) {
      final FakeEmblaSession session = FakeEmblaSession(config);
      capture(session);
      return session;
    },
  );
}

void main() {
  group('RatatoskurStreamingAsr', () {
    test('reports its id and capabilities', () {
      final RatatoskurStreamingAsr asr = build((_) {});
      expect(asr.id, 'ratatoskur');
      expect(asr.emitsPartials, true);
      expect(asr.needsManualStop, false);
      expect(asr.currentSession, isNull);
    });

    test('configures an ASR-only session', () {
      late FakeEmblaSession session;
      final RatatoskurStreamingAsr asr = build((FakeEmblaSession s) => session = s);
      asr.listen();
      final EmblaSessionConfig config = session.config;
      expect(config.ratatoskurServer, 'https://api.greynir.is');
      expect(config.socketURL, 'wss://api.greynir.is/rat/v1/short_asr');
      expect(config.apiKey, 'test-api-key');
      expect(config.engine, 'azure'); // lower-cased for the server
      expect(config.query, false);
      expect(config.tts, false);
      expect(config.audio, true);
      expect(config.privateMode, false);
      expect(config.clientID, 'client-1');
      expect(config.clientType, 'flutter_test');
      expect(config.clientVersion, '2.0.0');
      expect(session.startCount, 1);
      expect(asr.currentSession, same(session));
    });

    test('leaves the engine unset when none is given, and can mute sounds', () {
      late FakeEmblaSession session;
      final RatatoskurStreamingAsr asr =
          build((FakeEmblaSession s) => session = s, engine: null, playSounds: false);
      asr.listen();
      expect(session.config.engine, isNull);
      expect(session.config.audio, false);
    });

    test('maps partials and a final transcript, then closes the stream', () async {
      late FakeEmblaSession session;
      final RatatoskurStreamingAsr asr = build((FakeEmblaSession s) => session = s);
      final Future<List<AsrEvent>> events = asr.listen().toList();

      session.sendPartial('hvað');
      session.sendPartial('hvað er');
      await session.sendFinal('Hvað er klukkan?');

      final List<AsrEvent> result = await events;
      expect(result, hasLength(3));
      expect((result[0] as AsrPartial).text, 'hvað');
      expect((result[1] as AsrPartial).text, 'hvað er');
      expect((result[2] as AsrFinal).text, 'Hvað er klukkan?');
    });

    test('turns an empty final result into an empty final event', () async {
      late FakeEmblaSession session;
      final RatatoskurStreamingAsr asr = build((FakeEmblaSession s) => session = s);
      final Future<List<AsrEvent>> events = asr.listen().toList();

      await session.sendFinal('');

      final List<AsrEvent> result = await events;
      expect(result, hasLength(1));
      expect((result.single as AsrFinal).text, '');
    });

    test('reports an empty final when the session ends without a transcript', () async {
      late FakeEmblaSession session;
      final RatatoskurStreamingAsr asr = build((FakeEmblaSession s) => session = s);
      final Future<List<AsrEvent>> events = asr.listen().toList();

      await session.stop(); // Server timeout / socket closed.

      final List<AsrEvent> result = await events;
      expect(result, hasLength(1));
      expect((result.single as AsrFinal).text, '');
    });

    test('does not emit a second final when onDone follows a real transcript', () async {
      late FakeEmblaSession session;
      final RatatoskurStreamingAsr asr = build((FakeEmblaSession s) => session = s);
      final Future<List<AsrEvent>> events = asr.listen().toList();

      await session.sendFinal('já');
      await session.stop(); // Late onDone must be ignored.

      final List<AsrEvent> result = await events;
      expect(result, hasLength(1));
      expect((result.single as AsrFinal).text, 'já');
    });

    test('maps session errors', () async {
      late FakeEmblaSession session;
      final RatatoskurStreamingAsr asr = build((FakeEmblaSession s) => session = s);
      final Future<List<AsrEvent>> events = asr.listen().toList();

      session.sendError('Missing session token!');
      session.sendPartial('too late'); // Ignored after close.

      final List<AsrEvent> result = await events;
      expect(result, hasLength(1));
      expect((result.single as AsrError).message, 'Missing session token!');
    });

    test('reports a synchronous start failure', () async {
      late FakeEmblaSession session;
      final RatatoskurStreamingAsr asr = build((FakeEmblaSession s) {
        session = s;
        s.startError = Exception('no microphone');
      });
      final List<AsrEvent> result = await asr.listen().toList();
      expect(session.startCount, 1);
      expect(result, hasLength(1));
      expect((result.single as AsrError).message, contains('no microphone'));
    });

    test('cancel stops the session silently and emits nothing', () async {
      late FakeEmblaSession session;
      final RatatoskurStreamingAsr asr = build((FakeEmblaSession s) => session = s);
      final Future<List<AsrEvent>> events = asr.listen().toList();

      await asr.cancel();

      expect(await events, isEmpty);
      // stop(), not cancel(): the caller owns the cancel sound.
      expect(session.stopCount, 1);
      expect(session.cancelCount, 0);
    });

    test('finish is a no-op while streaming', () async {
      late FakeEmblaSession session;
      final RatatoskurStreamingAsr asr = build((FakeEmblaSession s) => session = s);
      final Future<List<AsrEvent>> events = asr.listen().toList();

      await asr.finish();
      expect(session.stopCount, 0);
      expect(session.isActive(), true);

      await session.sendFinal('halló');
      expect((await events).single, isA<AsrFinal>());
    });

    test('builds a fresh single-use session per listen()', () async {
      final List<FakeEmblaSession> sessions = <FakeEmblaSession>[];
      final RatatoskurStreamingAsr asr = build(sessions.add);

      final Future<List<AsrEvent>> first = asr.listen().toList();
      await sessions.first.sendFinal('eitt');
      await first;

      final Future<List<AsrEvent>> second = asr.listen().toList();
      await sessions.last.sendFinal('tvö');
      expect((await second).single, isA<AsrFinal>());

      expect(sessions, hasLength(2));
      expect(sessions.first, isNot(same(sessions.last)));
      expect(asr.currentSession, same(sessions.last));
    });
  });
}

// Tests for the mapping from AssistantState to session button appearance,
// and for the session button widget itself.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:embla/asr/asr_engine.dart';
import 'package:embla/assistant/assistant_session.dart';
import 'package:embla/assistant/session_sounds.dart';
import 'package:embla/button.dart';
import 'package:embla/llm/llm_client.dart';
import 'package:embla/tools/tool.dart';
import 'package:embla/tts/tts_engine.dart';

/// Engines that do nothing at all, so an AssistantSession can be
/// constructed in a unit test.
class FakeAsrEngine implements AsrEngine {
  @override
  final bool needsManualStop;
  FakeAsrEngine({this.needsManualStop = false});
  @override
  String get id => 'fake';
  @override
  bool get emitsPartials => true;
  @override
  Stream<AsrEvent> listen() => const Stream<AsrEvent>.empty();
  @override
  Future<void> finish() async {}
  @override
  Future<void> cancel() async {}
}

class FakeLlmClient implements LlmClient {
  @override
  String get id => 'fake';
  @override
  String get model => 'fake-model';
  @override
  Future<LlmResponse> complete(LlmRequest request,
          {Duration timeout = const Duration(seconds: 30)}) async =>
      const LlmResponse(text: '');
}

class FakeTtsEngine implements TtsEngine {
  @override
  String get id => 'fake';
  @override
  List<String> get voices => const <String>[];
  @override
  Future<void> speak(String text,
      {required String voice,
      required double speed,
      required void Function(bool err) onDone}) async {
    onDone(false);
  }

  @override
  void stop() {}
}

AssistantSession makeFakeSession({bool needsManualStop = false, Conversation? conversation}) {
  final AssistantSessionConfig cfg = AssistantSessionConfig(
    asr: FakeAsrEngine(needsManualStop: needsManualStop),
    llm: FakeLlmClient(),
    tts: FakeTtsEngine(),
    tools: ToolRegistry(),
    conversation: conversation ?? Conversation(),
    sounds: SilentSessionSounds(),
    buildSystemPrompt: () => 'prufa',
    buildToolContext: () => ToolContext(now: DateTime.now()),
  );
  return AssistantSession(cfg);
}

void main() {
  group('AssistantState', () {
    test('only in-flight states count as active', () {
      const Map<AssistantState, bool> expected = {
        AssistantState.idle: false,
        AssistantState.listening: true,
        AssistantState.transcribing: true,
        AssistantState.thinking: true,
        AssistantState.acting: true,
        AssistantState.speaking: true,
        AssistantState.done: false,
        AssistantState.error: false,
      };
      for (final AssistantState s in AssistantState.values) {
        expect(s.isActive, expected[s], reason: 'isActive for $s');
      }
    });

    test('the waveform is only shown while listening', () {
      for (final AssistantState s in AssistantState.values) {
        expect(s.showsWaveform, s == AssistantState.listening, reason: 'showsWaveform for $s');
      }
    });

    test('the logo animation runs from transcribing through speaking', () {
      const Set<AssistantState> animated = {
        AssistantState.transcribing,
        AssistantState.thinking,
        AssistantState.acting,
        AssistantState.speaking,
      };
      for (final AssistantState s in AssistantState.values) {
        expect(s.showsAnimation, animated.contains(s), reason: 'showsAnimation for $s');
      }
      // Waveform and animation are mutually exclusive
      for (final AssistantState s in AssistantState.values) {
        expect(s.showsWaveform && s.showsAnimation, false);
      }
    });
  });

  group('AssistantSession', () {
    test('starts out idle and inactive', () {
      final AssistantSession session = makeFakeSession();
      expect(session.state, AssistantState.idle);
      expect(session.isActive(), false);
    });

    test('empty typed input ends the turn without calling the engines', () async {
      bool done = false;
      final AssistantSession session = makeFakeSession();
      session.config.onDone = () => done = true;
      await session.submitText('   ');
      expect(done, true);
      expect(session.state, AssistantState.done);
      expect(session.isActive(), false);
      expect(session.config.conversation.turns, isEmpty);
    });

    test('the route can tell whether the ASR engine needs a manual stop', () {
      expect(makeFakeSession().config.asr.needsManualStop, false);
      expect(makeFakeSession(needsManualStop: true).config.asr.needsManualStop, true);
    });
  });

  group('SessionButtonWidget', () {
    testWidgets('renders without a session', (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Builder(
                  builder: (BuildContext context) =>
                      SessionButtonWidget(context, null, () {})))));
      await tester.pumpAndSettle();
      expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
    });

    testWidgets('taps are forwarded', (tester) async {
      int taps = 0;
      final AssistantSession session = makeFakeSession();
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Builder(
                  builder: (BuildContext context) =>
                      SessionButtonWidget(context, session, () => taps += 1)))));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(GestureDetector));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });
}

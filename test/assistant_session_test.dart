// Tests for the AssistantSession orchestrator, driven entirely by fakes so
// that no platform plugin (audio, prefs, location) is ever touched.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:embla/asr/asr_engine.dart';
import 'package:embla/assistant/assistant_session.dart';
import 'package:embla/assistant/session_sounds.dart';
import 'package:embla/llm/llm_client.dart';
import 'package:embla/tools/tool.dart';
import 'package:embla/tts/tts_engine.dart';

// ---------------------------------------------------------------------
// Fakes

class FakeAsr implements AsrEngine {
  FakeAsr([this.events = const []]);

  final List<AsrEvent> events;
  int cancelCount = 0;
  int finishCount = 0;

  @override
  String get id => 'fake';
  @override
  bool get emitsPartials => true;
  @override
  bool get needsManualStop => false;

  @override
  Stream<AsrEvent> listen() => Stream<AsrEvent>.fromIterable(events);

  @override
  Future<void> finish() async => finishCount++;

  @override
  Future<void> cancel() async => cancelCount++;
}

class FakeLlm implements LlmClient {
  FakeLlm(this.responses);

  final List<LlmResponse> responses;
  final List<LlmRequest> requests = [];

  /// When set, `complete()` waits for this before returning.
  Completer<void>? gate;

  int get calls => requests.length;

  @override
  String get id => 'fake';
  @override
  String get model => 'fake-model';

  @override
  Future<LlmResponse> complete(LlmRequest request,
      {Duration timeout = const Duration(seconds: 30)}) async {
    requests.add(request);
    final Completer<void>? g = gate;
    if (g != null) {
      await g.future;
    }
    return responses[requests.length - 1];
  }
}

class FakeTts implements TtsEngine {
  final List<String> spoken = [];
  bool fail = false;
  int stopCount = 0;

  @override
  String get id => 'fake';
  @override
  List<String> get voices => const ['Guðrún'];

  @override
  Future<void> speak(
    String text, {
    required String voice,
    required double speed,
    required void Function(bool err) onDone,
  }) async {
    spoken.add(text);
    onDone(fail);
  }

  @override
  void stop() => stopCount++;
}

class CountingSounds extends SilentSessionSounds {
  int dunnoCount = 0;
  int errorCount = 0;
  int confirmCount = 0;
  int cancelCount = 0;

  @override
  String? playDunno({
    required String voiceID,
    required double speed,
    required void Function() onDone,
  }) {
    dunnoCount++;
    super.playDunno(voiceID: voiceID, speed: speed, onDone: onDone);
    return 'Ég veit það ekki.';
  }

  @override
  void playError({required String voiceID, required double speed}) => errorCount++;
  @override
  void playConfirm() => confirmCount++;
  @override
  void playCancel() => cancelCount++;
}

class EchoTool extends Tool {
  EchoTool();

  final List<Map<String, dynamic>> invocations = [];

  @override
  String get name => 'echo';
  @override
  String get description => 'Skilar því sem sent er inn.';
  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'q': {'type': 'string', 'description': 'Texti'}
        },
        'required': ['q'],
        'additionalProperties': false,
      };
  @override
  String? get activityLabel => 'Prófa verkfæri…';

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    invocations.add(args);
    return ToolResult.success({'echo': args['q']});
  }
}

// ---------------------------------------------------------------------

const String kAnswerJSON =
    '{"kind":"answer","speech":"Það er sól í Reykjavík.","display":"Sól, 12°C."}';

class Harness {
  Harness({
    required this.llm,
    FakeAsr? asr,
    ToolRegistry? tools,
  })  : asr = asr ?? FakeAsr(),
        tools = tools ?? ToolRegistry();

  final FakeLlm llm;
  final FakeAsr asr;
  final ToolRegistry tools;
  final FakeTts tts = FakeTts();
  final CountingSounds sounds = CountingSounds();
  final Conversation conversation = Conversation();

  final List<AssistantState> states = [];
  final List<String> partials = [];
  final List<String> finals = [];
  final List<Turn> replies = [];
  final List<String> activities = [];
  final List<Uri> openedURLs = [];
  final List<String> errors = [];
  int doneCount = 0;

  AssistantSession build() => AssistantSession(AssistantSessionConfig(
        asr: asr,
        llm: llm,
        tts: tts,
        tools: tools,
        conversation: conversation,
        sounds: sounds,
        buildSystemPrompt: () => 'kerfisboð',
        buildToolContext: () => ToolContext(now: DateTime.utc(2026, 9, 2, 14, 35)),
        voiceID: 'Guðrún',
        voiceSpeed: 1.0,
      )
        ..onStateChanged = states.add
        ..onPartialTranscript = partials.add
        ..onFinalTranscript = finals.add
        ..onReply = replies.add
        ..onToolActivity = activities.add
        ..onOpenURL = openedURLs.add
        ..onError = errors.add
        ..onDone = () => doneCount++);
}

void main() {
  test('typed turn: reply is spoken and the turn completes', () async {
    final h = Harness(llm: FakeLlm([const LlmResponse(text: kAnswerJSON)]));
    final session = h.build();

    await session.submitText('hvernig er veðrið í Reykjavík?');

    expect(h.llm.calls, 1);
    expect(h.llm.requests.single.instructions, 'kerfisboð');
    expect(h.llm.requests.single.responseSchema, isNotNull);

    expect(h.tts.spoken, ['Það er sól í Reykjavík.']);
    expect(h.replies.single.text, 'Sól, 12°C.');
    expect(h.errors, isEmpty);
    expect(h.doneCount, 1);
    expect(session.state, AssistantState.done);

    expect(h.conversation.turns.map((t) => t.role),
        [TurnRole.user, TurnRole.assistant]);
    expect(h.conversation.history.length, 2);
    expect(h.conversation.history.first, isA<UserMessage>());
    expect(h.conversation.history.last, isA<AssistantMessage>());
    expect(h.states, contains(AssistantState.thinking));
    expect(h.states, contains(AssistantState.speaking));
  });

  test('typed turn: whitespace-only input ends the turn without an LLM call', () async {
    final h = Harness(llm: FakeLlm(const []));
    final session = h.build();

    await session.submitText('   ');

    expect(h.llm.calls, 0);
    expect(h.doneCount, 1);
    expect(h.conversation.turns, isEmpty);
  });

  test('tool loop: tool call, tool result, then the final reply', () async {
    final tool = EchoTool();
    final registry = ToolRegistry()..register(tool);
    final h = Harness(
      llm: FakeLlm([
        const LlmResponse(
          text: 'Ég athuga það.',
          toolCalls: [ToolCall(id: 'call_1', name: 'echo', arguments: {'q': 'halló'})],
        ),
        const LlmResponse(text: kAnswerJSON),
      ]),
      tools: registry,
    );
    final session = h.build();

    await session.submitText('prófaðu verkfærið');

    expect(tool.invocations, [
      {'q': 'halló'}
    ]);
    expect(h.llm.calls, 2);
    expect(h.activities, ['Prófa verkfæri…']);

    // The second request must carry the tool call and its result.
    final List<ChatMessage> second = h.llm.requests[1].messages;
    expect(second.length, 3);
    expect(second[0], isA<UserMessage>());
    final assistant = second[1] as AssistantMessage;
    expect(assistant.toolCalls.single.name, 'echo');
    final result = second[2] as ToolResultMessage;
    expect(result.callId, 'call_1');
    expect(result.outputJson, contains('"echo":"halló"'));

    // The tools the model was offered came from the registry.
    expect(h.llm.requests.first.tools.single.name, 'echo');

    expect(h.tts.spoken, ['Það er sól í Reykjavík.']);
    expect(h.doneCount, 1);
    expect(h.errors, isEmpty);
  });

  test('unknown reply plays the canned clip instead of TTS', () async {
    final h = Harness(
      llm: FakeLlm([
        const LlmResponse(
            text: '{"kind":"unknown","speech":"Ég veit ekki.","display":"Ekkert svar."}')
      ]),
    );
    final session = h.build();

    await session.submitText('hvað er handan alheimsins?');

    expect(h.sounds.dunnoCount, 1);
    expect(h.tts.spoken, isEmpty);
    expect(h.replies.single.text, 'Ég veit það ekki.');
    expect(h.doneCount, 1);
    expect(h.errors, isEmpty);
  });

  test('cancel while thinking emits no reply', () async {
    final h = Harness(llm: FakeLlm([const LlmResponse(text: kAnswerJSON)]));
    h.llm.gate = Completer<void>();
    final session = h.build();

    final Future<void> turn = session.submitText('hvernig er veðrið?');
    await Future<void>.delayed(Duration.zero);
    expect(session.state, AssistantState.thinking);

    await session.cancel();
    h.llm.gate!.complete();
    await turn;

    expect(h.replies, isEmpty);
    expect(h.tts.spoken, isEmpty);
    expect(h.errors, isEmpty);
    expect(h.asr.cancelCount, 1);
    expect(h.tts.stopCount, greaterThanOrEqualTo(1));
    expect(h.doneCount, 1);
    expect(session.state, AssistantState.done);
  });

  test('voice turn with an empty final transcript ends without an LLM call', () async {
    final h = Harness(
      llm: FakeLlm(const []),
      asr: FakeAsr(const [AsrPartial('hvernig'), AsrFinal('')]),
    );
    final session = h.build();

    await session.startVoice();

    expect(h.partials, ['hvernig']);
    expect(h.finals, isEmpty);
    expect(h.sounds.confirmCount, 0);
    expect(h.llm.calls, 0);
    expect(h.tts.spoken, isEmpty);
    expect(h.doneCount, 1);
    expect(session.state, AssistantState.done);
  });

  test('voice turn with a transcript runs the full pipeline', () async {
    final h = Harness(
      llm: FakeLlm([const LlmResponse(text: kAnswerJSON)]),
      asr: FakeAsr(const [AsrPartial('hvernig er'), AsrFinal('hvernig er veðrið?')]),
    );
    final session = h.build();

    await session.startVoice();

    expect(h.partials, ['hvernig er']);
    expect(h.finals, ['hvernig er veðrið?']);
    expect(h.sounds.confirmCount, 1);
    expect(h.llm.calls, 1);
    expect(h.tts.spoken, ['Það er sól í Reykjavík.']);
    expect(h.doneCount, 1);
    expect(h.states.first, AssistantState.listening);
  });

  test('an ASR error is reported without the session error sound', () async {
    final h = Harness(
      llm: FakeLlm(const []),
      asr: FakeAsr(const [AsrError('hljóðnemi ekki tiltækur')]),
    );
    final session = h.build();

    await session.startVoice();

    expect(h.errors.single, contains('hljóðnemi ekki tiltækur'));
    expect(h.sounds.errorCount, 0); // ASR engines play their own error cue
    expect(h.llm.calls, 0);
    expect(session.state, AssistantState.error);
  });

  test('an LLM failure is reported as an error', () async {
    final h = Harness(llm: _FailingLlm());
    final session = h.build();

    await session.submitText('halló');

    expect(h.errors.single, contains('401'));
    expect(h.sounds.errorCount, 1);
    expect(h.replies, isEmpty);
    expect(session.state, AssistantState.error);
  });

  test('a tool openURL is handed to the UI after the reply is spoken', () async {
    final registry = ToolRegistry()..register(_LinkTool());
    final h = Harness(
      llm: FakeLlm([
        const LlmResponse(toolCalls: [
          ToolCall(id: 'call_2', name: 'link', arguments: {})
        ]),
        const LlmResponse(text: kAnswerJSON),
      ]),
      tools: registry,
    );
    final session = h.build();

    await session.submitText('opnaðu embla.is');

    expect(h.openedURLs.single.toString(), 'https://embla.is/');
    expect(h.doneCount, 1);
  });
}

class _FailingLlm extends FakeLlm {
  _FailingLlm() : super(const []);

  @override
  Future<LlmResponse> complete(LlmRequest request,
          {Duration timeout = const Duration(seconds: 30)}) async =>
      throw const LlmException('Incorrect API key', statusCode: 401);
}

class _LinkTool extends Tool {
  @override
  String get name => 'link';
  @override
  String get description => 'Skilar hlekk.';
  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': <String, dynamic>{},
        'required': <String>[],
        'additionalProperties': false,
      };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async =>
      ToolResult.success({'url': 'https://embla.is/'},
          openURL: Uri.parse('https://embla.is/'), endsTurn: true);
}

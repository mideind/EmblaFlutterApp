// Tests for the Gemini client, which differs from the OpenAI path in that it
// takes recorded audio directly and speaks a different schema dialect.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' show MockClient;

import 'package:embla/llm/gemini_client.dart';
import 'package:embla/llm/llm_client.dart';

http.Response _ok(Object body) => http.Response(jsonEncode(body), 200,
    headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> _reply(String text) => {
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': text}
            ]
          }
        }
      ]
    };

void main() {
  const Map<String, dynamic> replySchema = {
    'type': 'object',
    'properties': {
      'kind': {
        'type': 'string',
        'enum': ['answer', 'unknown']
      },
      'speech': {'type': 'string'},
    },
    'required': ['kind', 'speech'],
    'additionalProperties': false,
  };

  test('audio is sent inline, and the text part asks for a transcription', () async {
    http.Request? captured;
    final client = MockClient((req) async {
      captured = req;
      return _ok(_reply('{"transcript":"hvað er klukkan","kind":"answer","speech":"Klukkan er fimm."}'));
    });
    final engine = GeminiClient(apiKey: 'k', client: client);

    final audio = Uint8List.fromList([1, 2, 3, 4]);
    final res = await engine.complete(LlmRequest(
      instructions: 'Þú ert Embla.',
      messages: [UserAudioMessage(audio)],
      tools: const [],
      responseSchema: replySchema,
    ));

    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    final parts = (body['contents'] as List).first['parts'] as List;
    expect(parts.first['inline_data']['mime_type'], 'audio/wav');
    expect(parts.first['inline_data']['data'], base64Encode(audio));
    expect(captured!.headers['x-goog-api-key'], 'k');
    // The transcript is pulled back out of the structured reply.
    expect(res.transcript, 'hvað er klukkan');
  });

  test('an audio turn asks for the transcript first, so words precede intent', () async {
    http.Request? captured;
    final client = MockClient((req) async {
      captured = req;
      return _ok(_reply('{}'));
    });
    await GeminiClient(apiKey: 'k', client: client).complete(LlmRequest(
      instructions: 'x',
      messages: [UserAudioMessage(Uint8List.fromList([0]))],
      tools: const [],
      responseSchema: replySchema,
    ));

    final cfg = (jsonDecode(captured!.body) as Map)['generationConfig'] as Map;
    expect(cfg['responseMimeType'], 'application/json');
    // Ordering is the mechanism: transcribe, then interpret.
    expect((cfg['responseSchema']['propertyOrdering'] as List).first, 'transcript');
    expect(cfg['responseSchema']['required'], contains('transcript'));
    // Reasoning tokens are off.
    expect(cfg['thinkingConfig']['thinkingBudget'], 0);
  });

  test('tools and a response schema are never sent together', () async {
    http.Request? captured;
    final client = MockClient((req) async {
      captured = req;
      return _ok(_reply('ok'));
    });
    await GeminiClient(apiKey: 'k', client: client).complete(const LlmRequest(
      instructions: 'x',
      messages: [UserMessage('hæ')],
      tools: [
        ToolSpec(
            name: 'get_datetime',
            description: 'Skilar tíma.',
            parameters: {'type': 'object', 'properties': {}, 'required': []}),
      ],
      responseSchema: replySchema,
    ));

    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    // Gemini rejects a response schema alongside function declarations.
    expect(body['tools'][0]['function_declarations'][0]['name'], 'get_datetime');
    expect((body['generationConfig'] as Map).containsKey('responseSchema'), isFalse);
  });

  test('function calls come back as tool calls with unique ids', () async {
    final client = MockClient((req) async => _ok({
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'functionCall': {
                      'name': 'set_timer',
                      'args': {'seconds': 300}
                    }
                  },
                  {
                    'functionCall': {'name': 'get_datetime', 'args': {}}
                  },
                ]
              }
            }
          ]
        }));
    final res = await GeminiClient(apiKey: 'k', client: client).complete(const LlmRequest(instructions: 'x', messages: [UserMessage('teljari')], tools: []));

    expect(res.hasToolCalls, isTrue);
    expect(res.toolCalls.map((c) => c.name), ['set_timer', 'get_datetime']);
    expect(res.toolCalls.first.arguments['seconds'], 300);
    // Gemini issues no ids of its own; they only need to be unique per turn.
    expect(res.toolCalls.map((c) => c.id).toSet().length, 2);
  });

  test('tool results go back as functionResponse objects', () async {
    http.Request? captured;
    final client = MockClient((req) async {
      captured = req;
      return _ok(_reply('ok'));
    });
    await GeminiClient(apiKey: 'k', client: client).complete(const LlmRequest(
      instructions: 'x',
      messages: [
        UserMessage('teljari'),
        AssistantMessage(
            toolCalls: [ToolCall(id: 'gemini_0', name: 'set_timer', arguments: {})]),
        ToolResultMessage(
            callId: 'gemini_0', name: 'set_timer', outputJson: '{"ok":true}'),
      ],
      tools: [],
    ));

    final contents = (jsonDecode(captured!.body) as Map)['contents'] as List;
    expect(contents[1]['role'], 'model');
    expect(contents[1]['parts'][0]['functionCall']['name'], 'set_timer');
    expect(contents[2]['parts'][0]['functionResponse']['response'], {'ok': true});
  });

  group('schema translation', () {
    test('nullable unions become nullable, types are upper-cased', () {
      final out = geminiSchema({
        'type': 'object',
        'properties': {
          'title': {'type': 'string', 'description': 'Heiti'},
          'note': {
            'type': ['string', 'null'],
            'description': 'Nánar'
          },
          'items': {
            'type': 'array',
            'items': {'type': 'string'}
          },
        },
        'required': ['title', 'note', 'items'],
        'additionalProperties': false,
      });

      expect(out['type'], 'OBJECT');
      expect(out['properties']['title']['type'], 'STRING');
      expect(out['properties']['note']['type'], 'STRING');
      expect(out['properties']['note']['nullable'], isTrue);
      expect(out['properties']['items']['type'], 'ARRAY');
      expect(out['properties']['items']['items']['type'], 'STRING');
      // Gemini has no additionalProperties; carrying it over would be rejected.
      expect(out.containsKey('additionalProperties'), isFalse);
      expect(out['propertyOrdering'], ['title', 'note', 'items']);
    });
  });

  test('a missing key fails before any request is made', () async {
    var called = false;
    final client = MockClient((req) async {
      called = true;
      return _ok(_reply('x'));
    });
    await expectLater(
      GeminiClient(apiKey: '', client: client)
          .complete(const LlmRequest(instructions: 'x', messages: [UserMessage('hæ')], tools: [])),
      throwsA(isA<LlmException>()),
    );
    expect(called, isFalse);
  });

  test('a non-2xx response surfaces as LlmException with the status', () async {
    final client = MockClient((req) async => http.Response('{"error":"nope"}', 429));
    await expectLater(
      GeminiClient(apiKey: 'k', client: client)
          .complete(const LlmRequest(instructions: 'x', messages: [UserMessage('hæ')], tools: [])),
      throwsA(isA<LlmException>().having((e) => e.statusCode, 'statusCode', 429)),
    );
  });
}

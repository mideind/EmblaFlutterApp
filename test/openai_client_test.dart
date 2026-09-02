// Tests for the OpenAI Responses API adapter: how the provider-neutral
// request is mapped onto the wire format, and how the wire response is
// mapped back. No network access; everything goes through MockClient.

import 'dart:convert' show jsonDecode, jsonEncode, utf8;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' show MockClient;

import 'package:embla/common.dart' show kOpenAIResponsesURL;
import 'package:embla/llm/llm_client.dart';
import 'package:embla/llm/openai_responses_client.dart';

http.Response _jsonResponse(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  group('request body', () {
    test('maps all three message kinds onto Responses API input items', () async {
      Map<String, dynamic>? sent;
      Uri? sentURL;
      Map<String, String>? sentHeaders;

      final client = OpenAIResponsesClient(
        apiKey: 'sk-test',
        client: MockClient((http.Request req) async {
          sentURL = req.url;
          sentHeaders = req.headers;
          sent = jsonDecode(req.body) as Map<String, dynamic>;
          return _jsonResponse({'output': <dynamic>[]});
        }),
      );

      await client.complete(const LlmRequest(
        instructions: 'Þú ert Embla.',
        messages: [
          UserMessage('hvernig er veðrið?'),
          AssistantMessage(text: 'Ég athuga það.', toolCalls: [
            ToolCall(id: 'call_1', name: 'greynir_query', arguments: {'q': 'veðrið í Reykjavík'}),
          ]),
          ToolResultMessage(
            callId: 'call_1',
            name: 'greynir_query',
            outputJson: '{"ok":true,"valid":true,"answer":"Sól"}',
          ),
        ],
      ));

      expect(sentURL.toString(), kOpenAIResponsesURL);
      expect(sentHeaders?['authorization'], 'Bearer sk-test');

      expect(sent!['instructions'], 'Þú ert Embla.');
      expect(sent!['store'], false);
      expect(sent!['max_output_tokens'], 2000);
      expect((sent!['reasoning'] as Map)['effort'], 'none');

      final List<dynamic> input = sent!['input'] as List<dynamic>;
      expect(input.length, 4);
      expect(input[0], {'role': 'user', 'content': 'hvernig er veðrið?'});
      expect(input[1], {
        'type': 'message',
        'role': 'assistant',
        'content': [
          {'type': 'output_text', 'text': 'Ég athuga það.'}
        ],
      });
      expect(input[2], {
        'type': 'function_call',
        'call_id': 'call_1',
        'name': 'greynir_query',
        'arguments': '{"q":"veðrið í Reykjavík"}',
      });
      expect(input[3], {
        'type': 'function_call_output',
        'call_id': 'call_1',
        'output': '{"ok":true,"valid":true,"answer":"Sól"}',
      });
    });

    test('omits the assistant message item when there is no text', () {
      final client = OpenAIResponsesClient(apiKey: 'sk-test');
      final body = client.buildRequestBody(const LlmRequest(
        instructions: '',
        messages: [
          AssistantMessage(toolCalls: [
            ToolCall(id: 'call_9', name: 'get_datetime', arguments: {}),
          ]),
        ],
      ));

      final List<dynamic> input = body['input'] as List<dynamic>;
      expect(input.length, 1);
      expect((input[0] as Map)['type'], 'function_call');
      expect((input[0] as Map)['arguments'], '{}');
      // No tools and no schema requested.
      expect(body.containsKey('tools'), false);
      expect(body.containsKey('text'), false);
    });

    test('declares tools strictly and requests a json_schema reply', () {
      final client = OpenAIResponsesClient(
        apiKey: 'sk-test',
        model: 'gpt-test',
        reasoningEffort: 'medium',
      );
      final body = client.buildRequestBody(const LlmRequest(
        instructions: 'x',
        messages: [UserMessage('halló')],
        tools: [
          ToolSpec(
            name: 'get_location',
            description: 'Skilar staðsetningu.',
            parameters: {
              'type': 'object',
              'properties': <String, dynamic>{},
              'required': <String>[],
              'additionalProperties': false,
            },
          ),
        ],
        responseSchema: {
          'type': 'object',
          'properties': {
            'kind': {'type': 'string'}
          },
          'required': ['kind'],
          'additionalProperties': false,
        },
      ));

      expect(body['model'], 'gpt-test');
      expect((body['reasoning'] as Map)['effort'], 'medium');

      final Map tool = (body['tools'] as List).single as Map;
      expect(tool['type'], 'function');
      expect(tool['name'], 'get_location');
      expect(tool['description'], 'Skilar staðsetningu.');
      expect(tool['strict'], true);
      expect((tool['parameters'] as Map)['additionalProperties'], false);

      final Map format = (body['text'] as Map)['format'] as Map;
      expect(format['type'], 'json_schema');
      expect(format['name'], 'embla_reply');
      expect(format['strict'], true);
      expect(((format['schema'] as Map)['required'] as List), ['kind']);
    });
  });

  group('response parsing', () {
    test('parses function_call items into tool calls', () async {
      final client = OpenAIResponsesClient(
        apiKey: 'sk-test',
        client: MockClient((_) async => _jsonResponse({
              'output': [
                {
                  'type': 'reasoning',
                  'summary': <dynamic>[],
                },
                {
                  'type': 'function_call',
                  'id': 'fc_abc',
                  'call_id': 'call_abc',
                  'name': 'greynir_query',
                  'arguments': '{"q":"hvað er klukkan"}',
                },
              ],
              'usage': {'input_tokens': 12, 'output_tokens': 3},
            })),
      );

      final resp = await client.complete(
          const LlmRequest(instructions: '', messages: [UserMessage('hvað er klukkan')]));

      expect(resp.hasToolCalls, true);
      expect(resp.text, isNull);
      final call = resp.toolCalls.single;
      expect(call.id, 'call_abc');
      expect(call.name, 'greynir_query');
      expect(call.arguments, {'q': 'hvað er klukkan'});
      expect(resp.usage?['input_tokens'], 12);
    });

    test('concatenates output_text blocks of message items', () async {
      final client = OpenAIResponsesClient(
        apiKey: 'sk-test',
        client: MockClient((_) async => _jsonResponse({
              'output': [
                {
                  'type': 'message',
                  'role': 'assistant',
                  'content': [
                    {'type': 'output_text', 'text': '{"kind":"answer",'},
                    {'type': 'output_text', 'text': '"speech":"Sól.","display":"Sól."}'},
                  ],
                },
              ],
            })),
      );

      final resp = await client.complete(const LlmRequest(instructions: '', messages: []));
      expect(resp.hasToolCalls, false);
      expect(resp.text, '{"kind":"answer","speech":"Sól.","display":"Sól."}');
      expect(jsonDecode(resp.text!), {'kind': 'answer', 'speech': 'Sól.', 'display': 'Sól.'});
    });

    test('turns a refusal block into an unknown reply', () async {
      final client = OpenAIResponsesClient(
        apiKey: 'sk-test',
        client: MockClient((_) async => _jsonResponse({
              'output': [
                {
                  'type': 'message',
                  'role': 'assistant',
                  'content': [
                    {'type': 'refusal', 'refusal': 'I cannot help with that.'},
                  ],
                },
              ],
            })),
      );

      final resp = await client.complete(const LlmRequest(instructions: '', messages: []));
      expect(resp.hasToolCalls, false);
      expect(jsonDecode(resp.text!), {
        'kind': 'unknown',
        'speech': 'Ég get ekki hjálpað með þetta.',
        'display': 'Beiðni hafnað.',
      });
    });

    test('throws LlmException with status and body snippet on HTTP 401', () async {
      final client = OpenAIResponsesClient(
        apiKey: 'bad-key',
        client: MockClient((_) async => _jsonResponse({
              'error': {'message': 'Incorrect API key provided'}
            }, 401)),
      );

      await expectLater(
        client.complete(const LlmRequest(instructions: '', messages: [])),
        throwsA(isA<LlmException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.message, 'message', contains('Incorrect API key provided'))),
      );
    });

    test('throws LlmException when the transport fails', () async {
      final client = OpenAIResponsesClient(
        apiKey: 'sk-test',
        client: MockClient((_) async => throw http.ClientException('no route to host')),
      );

      await expectLater(
        client.complete(const LlmRequest(instructions: '', messages: [])),
        throwsA(isA<LlmException>()),
      );
    });

    test('survives a malformed function_call arguments string', () {
      final resp = OpenAIResponsesClient.parseResponseBody({
        'output': [
          {
            'type': 'function_call',
            'call_id': 'call_x',
            'name': 'open_url',
            'arguments': 'not json',
          },
        ],
      });
      expect(resp.toolCalls.single.arguments, isEmpty);
    });
  });
}

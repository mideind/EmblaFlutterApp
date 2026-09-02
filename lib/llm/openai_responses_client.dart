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

// OpenAI Responses API adapter (POST /v1/responses).
//
// The Responses API keeps tool calls and tool results as flat items in the
// `input` array rather than nesting them in messages, so the provider-neutral
// [ChatMessage] history is expanded into one or more items per message.
// Structured output for the final reply is requested via `text.format`.

import 'dart:async' show TimeoutException;
import 'dart:convert' show jsonDecode, jsonEncode, utf8;

import 'package:http/http.dart' as http;

import '../common.dart' show dlog, kDefaultOpenAIModel, kOpenAIResponsesURL;
import 'llm_client.dart';

// Generous enough for a reply plus low-effort reasoning tokens.
const int _kMaxOutputTokens = 2000;

// Returned instead of the model's text when the model refuses the request.
// Shaped like an AssistantReply so the normal parsing path can handle it.
const String kRefusalReplyJSON = '{"kind":"unknown",'
    '"speech":"Ég get ekki hjálpað með þetta.",'
    '"display":"Beiðni hafnað."}';

class OpenAIResponsesClient implements LlmClient {
  OpenAIResponsesClient({
    required this.apiKey,
    this.model = kDefaultOpenAIModel,
    http.Client? client,
    // The Swift MVP runs with effort 'none': same accuracy on its test set and
    // roughly a second faster. Our tool loop asks more of the model than its
    // single classification does, so revert to 'low' if relative dates
    // ("eftir hálftíma", "á morgun") start being misread.
    this.reasoningEffort = 'none',
  }) : _client = client ?? http.Client();

  final String apiKey;

  @override
  final String model;

  /// `minimal`, `low`, `medium` or `high`.
  final String reasoningEffort;

  final http.Client _client;

  @override
  String get id => 'openai';

  @override
  Future<LlmResponse> complete(LlmRequest request,
      {Duration timeout = const Duration(seconds: 30)}) async {
    final String body = jsonEncode(buildRequestBody(request));
    dlog('OpenAI request to $kOpenAIResponsesURL: $body');

    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(kOpenAIResponsesURL),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: body,
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const LlmException('Mállíkanið svaraði ekki í tæka tíð');
    } catch (e) {
      throw LlmException('Villa í samskiptum við mállíkan: $e');
    }

    final String payload = utf8.decode(response.bodyBytes);
    dlog('OpenAI response (${response.statusCode}): $payload');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LlmException(_snippet(payload), statusCode: response.statusCode);
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(payload);
    } catch (e) {
      throw const LlmException('Ólæsilegt svar frá mállíkani');
    }
    if (decoded is! Map) {
      throw const LlmException('Ólæsilegt svar frá mállíkani');
    }
    return parseResponseBody(Map<String, dynamic>.from(decoded));
  }

  // ---------------------------------------------------------------------
  // Request

  /// Builds the JSON request body. Public for testing.
  Map<String, dynamic> buildRequestBody(LlmRequest request) {
    final Map<String, dynamic> body = {
      'model': model,
      'instructions': request.instructions,
      'input': mapMessages(request.messages),
      'reasoning': {'effort': reasoningEffort},
      'store': false,
      'max_output_tokens': _kMaxOutputTokens,
    };

    if (request.tools.isNotEmpty) {
      body['tools'] = [
        for (final ToolSpec t in request.tools)
          {
            'type': 'function',
            'name': t.name,
            'description': t.description,
            'parameters': t.parameters,
            'strict': true,
          }
      ];
    }

    final Map<String, dynamic>? schema = request.responseSchema;
    if (schema != null) {
      body['text'] = {
        'format': {
          'type': 'json_schema',
          'name': 'embla_reply',
          'strict': true,
          'schema': schema,
        }
      };
    }
    return body;
  }

  /// Maps provider-neutral history onto Responses API input items.
  static List<Map<String, dynamic>> mapMessages(List<ChatMessage> messages) {
    final List<Map<String, dynamic>> items = [];
    for (final ChatMessage m in messages) {
      switch (m) {
        case UserAudioMessage():
          // The Responses API takes text; audio input is the fused Gemini
          // path's job. Failing loudly beats silently dropping the turn.
          throw const LlmException(
              'OpenAI tekur ekki við hljóði; notaðu Gemini fyrir sameinaða hljóðleið');
        case UserMessage(:final text):
          items.add({'role': 'user', 'content': text});
        case AssistantMessage(:final text, :final toolCalls):
          if (text != null && text.trim().isNotEmpty) {
            items.add({
              'type': 'message',
              'role': 'assistant',
              'content': [
                {'type': 'output_text', 'text': text}
              ],
            });
          }
          for (final ToolCall c in toolCalls) {
            items.add({
              'type': 'function_call',
              'call_id': c.id,
              'name': c.name,
              'arguments': jsonEncode(c.arguments),
            });
          }
        case ToolResultMessage(:final callId, :final outputJson):
          items.add({
            'type': 'function_call_output',
            'call_id': callId,
            'output': outputJson,
          });
      }
    }
    return items;
  }

  // ---------------------------------------------------------------------
  // Response

  /// Parses a decoded Responses API body. Public for testing.
  static LlmResponse parseResponseBody(Map<String, dynamic> json) {
    final List<ToolCall> toolCalls = [];
    final StringBuffer text = StringBuffer();
    bool refused = false;

    final dynamic output = json['output'];
    if (output is List) {
      for (final dynamic item in output) {
        if (item is! Map) {
          continue;
        }
        switch (item['type']) {
          case 'function_call':
            final dynamic name = item['name'];
            if (name is! String || name.isEmpty) {
              break;
            }
            toolCalls.add(ToolCall(
              id: (item['call_id'] ?? item['id'] ?? '').toString(),
              name: name,
              arguments: _decodeArguments(item['arguments']),
            ));
          case 'message':
            final dynamic content = item['content'];
            if (content is! List) {
              break;
            }
            for (final dynamic block in content) {
              if (block is! Map) {
                continue;
              }
              switch (block['type']) {
                case 'output_text':
                  text.write(block['text']?.toString() ?? '');
                case 'refusal':
                  refused = true;
              }
            }
        }
      }
    }

    final String? finalText =
        refused ? kRefusalReplyJSON : (text.isEmpty ? null : text.toString());
    final dynamic usage = json['usage'];

    return LlmResponse(
      text: finalText,
      toolCalls: List.unmodifiable(toolCalls),
      usage: usage is Map ? Map<String, dynamic>.from(usage) : null,
    );
  }

  static Map<String, dynamic> _decodeArguments(dynamic raw) {
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final dynamic decoded = jsonDecode(raw);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (e) {
        dlog('Could not decode tool call arguments: $e');
      }
    }
    return <String, dynamic>{};
  }

  static String _snippet(String body, [int max = 300]) {
    final String s = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s.length <= max ? s : '${s.substring(0, max)}…';
  }
}

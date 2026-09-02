/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2026 Miðeind ehf. <mideind@mideind.is>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

// Gemini client. Unlike the OpenAI path this one accepts recorded audio
// directly, so one call can replace both the ASR request and the LLM request.

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../common.dart' show dlog, kDefaultGeminiModel, kGeminiBaseURL;
import 'llm_client.dart';

/// Gemini's schema dialect uses upper-case type names, has no
/// `additionalProperties`, and expresses optionality with `nullable`.
Map<String, dynamic> geminiSchema(Map<String, dynamic> jsonSchema) {
  final Object? rawType = jsonSchema['type'];
  bool nullable = false;
  String type;
  if (rawType is List) {
    nullable = rawType.contains('null');
    type = rawType.firstWhere((dynamic t) => t != 'null', orElse: () => 'string') as String;
  } else {
    type = (rawType as String?) ?? 'string';
  }

  final Map<String, dynamic> out = <String, dynamic>{'type': type.toUpperCase()};
  if (nullable) out['nullable'] = true;
  if (jsonSchema['description'] != null) out['description'] = jsonSchema['description'];
  if (jsonSchema['enum'] != null) out['enum'] = jsonSchema['enum'];

  final Object? props = jsonSchema['properties'];
  if (props is Map) {
    final Map<String, dynamic> converted = <String, dynamic>{};
    props.forEach((dynamic k, dynamic v) {
      converted[k.toString()] = geminiSchema((v as Map).cast<String, dynamic>());
    });
    out['properties'] = converted;
    // Ordering is meaningful: it is what makes the model transcribe before it
    // interprets, rather than deciding an action and back-filling the words.
    out['propertyOrdering'] = converted.keys.toList(growable: false);
    final Object? required = jsonSchema['required'];
    if (required is List && required.isNotEmpty) {
      out['required'] = required.map((dynamic e) => e.toString()).toList(growable: false);
    }
  }
  final Object? items = jsonSchema['items'];
  if (items is Map) {
    out['items'] = geminiSchema(items.cast<String, dynamic>());
  }
  return out;
}

class GeminiClient implements LlmClient {
  GeminiClient({
    required this.apiKey,
    this.model = kDefaultGeminiModel,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiKey;
  @override
  final String model;
  final http.Client _client;

  @override
  String get id => 'gemini';

  @override
  Future<LlmResponse> complete(LlmRequest request,
      {Duration timeout = const Duration(seconds: 30)}) async {
    if (apiKey.isEmpty) {
      throw const LlmException('Gemini API lykil vantar', statusCode: 401);
    }
    final bool hasAudio = request.messages.any((m) => m is UserAudioMessage);

    final Map<String, dynamic> body = <String, dynamic>{
      'contents': _contents(request.messages),
      'system_instruction': <String, dynamic>{
        'parts': <dynamic>[
          <String, dynamic>{'text': request.instructions}
        ],
      },
      // Reasoning tokens buy little on this task and cost latency.
      'generationConfig': <String, dynamic>{
        'thinkingConfig': <String, dynamic>{'thinkingBudget': 0},
      },
    };

    if (request.tools.isNotEmpty) {
      body['tools'] = <dynamic>[
        <String, dynamic>{
          'function_declarations': request.tools
              .map((ToolSpec t) => <String, dynamic>{
                    'name': t.name,
                    'description': t.description,
                    'parameters': geminiSchema(t.parameters),
                  })
              .toList(growable: false),
        }
      ];
    } else if (request.responseSchema != null) {
      // Gemini refuses a response schema alongside function declarations, so
      // structured output is only requested on turns with no tools. On tool
      // turns the reply contract is carried by the system prompt instead and
      // AssistantReply.parse falls back to treating plain text as an answer.
      final Map<String, dynamic> schema = geminiSchema(request.responseSchema!);
      if (hasAudio) {
        schema['properties'] = <String, dynamic>{
          'transcript': <String, dynamic>{
            'type': 'STRING',
            'description': 'Nákvæm umritun þess sem notandinn sagði.',
          },
          ...(schema['properties'] as Map).cast<String, dynamic>(),
        };
        schema['propertyOrdering'] = (schema['properties'] as Map).keys.toList(growable: false);
        schema['required'] = <String>[
          'transcript',
          ...((schema['required'] as List?)?.cast<String>() ?? const <String>[]),
        ];
      }
      (body['generationConfig'] as Map<String, dynamic>)
        ..['responseMimeType'] = 'application/json'
        ..['responseSchema'] = schema;
    }

    final Uri url = Uri.parse('$kGeminiBaseURL/$model:generateContent');
    dlog('Gemini request to $url (${hasAudio ? 'audio' : 'text'})');

    final http.Response resp;
    try {
      resp = await _client
          .post(url,
              headers: <String, String>{
                'x-goog-api-key': apiKey,
                'Content-Type': 'application/json',
              },
              body: jsonEncode(body))
          .timeout(timeout);
    } catch (e) {
      throw LlmException('Gemini beiðni mistókst: $e');
    }

    if (resp.statusCode < 200 || resp.statusCode > 299) {
      dlog('Gemini response (${resp.statusCode}): ${resp.body}');
      throw LlmException(resp.body, statusCode: resp.statusCode);
    }
    return _parse(utf8.decode(resp.bodyBytes));
  }

  List<Map<String, dynamic>> _contents(List<ChatMessage> messages) {
    final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];
    for (final ChatMessage m in messages) {
      switch (m) {
        case UserAudioMessage(:final bytes, :final mimeType):
          out.add(<String, dynamic>{
            'role': 'user',
            'parts': <dynamic>[
              <String, dynamic>{
                'inline_data': <String, dynamic>{
                  'mime_type': mimeType,
                  'data': base64Encode(bytes),
                }
              },
              <String, dynamic>{
                'text': 'Umritaðu raddskipunina og svaraðu henni.',
              },
            ],
          });
        case UserMessage(:final text):
          out.add(<String, dynamic>{
            'role': 'user',
            'parts': <dynamic>[
              <String, dynamic>{'text': text}
            ],
          });
        case AssistantMessage(:final text, :final toolCalls):
          final List<dynamic> parts = <dynamic>[];
          if (text != null && text.isNotEmpty) {
            parts.add(<String, dynamic>{'text': text});
          }
          for (final ToolCall c in toolCalls) {
            parts.add(<String, dynamic>{
              'functionCall': <String, dynamic>{'name': c.name, 'args': c.arguments},
            });
          }
          if (parts.isNotEmpty) {
            out.add(<String, dynamic>{'role': 'model', 'parts': parts});
          }
        case ToolResultMessage(:final name, :final outputJson):
          Map<String, dynamic> payload;
          try {
            final Object? decoded = jsonDecode(outputJson);
            payload = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{'result': decoded};
          } catch (_) {
            payload = <String, dynamic>{'result': outputJson};
          }
          out.add(<String, dynamic>{
            'role': 'user',
            'parts': <dynamic>[
              <String, dynamic>{
                'functionResponse': <String, dynamic>{'name': name, 'response': payload},
              }
            ],
          });
      }
    }
    return out;
  }

  LlmResponse _parse(String rawBody) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(rawBody) as Map<String, dynamic>;
    } catch (e) {
      throw LlmException('Ógilt svar frá Gemini: $e');
    }
    final List<dynamic> candidates = (json['candidates'] as List?) ?? const <dynamic>[];
    if (candidates.isEmpty) {
      throw const LlmException('Gemini skilaði engu svari');
    }
    final Map<String, dynamic> content =
        ((candidates.first as Map)['content'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
    final List<dynamic> parts = (content['parts'] as List?) ?? const <dynamic>[];

    final StringBuffer text = StringBuffer();
    final List<ToolCall> calls = <ToolCall>[];
    for (final dynamic p in parts) {
      if (p is! Map) continue;
      final Object? fc = p['functionCall'];
      if (fc is Map) {
        calls.add(ToolCall(
          // Gemini does not issue call ids; the loop only needs them to be
          // unique within a turn when pairing results back up.
          id: 'gemini_${calls.length}',
          name: fc['name']?.toString() ?? '',
          arguments: (fc['args'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
        ));
        continue;
      }
      if (p['text'] != null) text.write(p['text']);
    }

    final String? out = text.isEmpty ? null : text.toString();
    return LlmResponse(
      text: out,
      toolCalls: calls,
      transcript: _transcript(out),
      usage: (json['usageMetadata'] as Map?)?.cast<String, dynamic>(),
    );
  }

  /// The transcript rides along inside the structured reply, so it has to be
  /// read back out of the JSON rather than from a field of its own.
  String? _transcript(String? text) {
    if (text == null) return null;
    try {
      final Object? decoded = jsonDecode(text);
      if (decoded is Map && decoded['transcript'] is String) {
        final String t = (decoded['transcript'] as String).trim();
        return t.isEmpty ? null : t;
      }
    } catch (_) {
      // Plain text reply, no transcript to recover.
    }
    return null;
  }
}

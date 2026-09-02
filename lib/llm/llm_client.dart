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

// Provider-neutral LLM client contract.
//
// Concrete implementations (OpenAI Responses API, Anthropic Messages API, ...)
// map these types onto their wire format. History is kept stateless and
// provider-neutral so that adapters can be swapped without touching the
// conversation model.

import 'dart:convert' show jsonEncode;

import 'dart:typed_data' show Uint8List;

/// A message in the LLM-facing conversation history.
sealed class ChatMessage {
  const ChatMessage();
}

/// Text typed or spoken by the user.
class UserMessage extends ChatMessage {
  final String text;
  const UserMessage(this.text);
}

/// Recorded speech handed to the model directly, instead of being transcribed
/// first. Only providers that accept audio input can consume this; the others
/// throw, since silently dropping the user's turn would be worse.
class UserAudioMessage extends ChatMessage {
  final Uint8List bytes;
  final String mimeType;
  const UserAudioMessage(this.bytes, {this.mimeType = 'audio/wav'});
}

/// A reply from the model: free text and/or tool calls.
class AssistantMessage extends ChatMessage {
  final String? text;
  final List<ToolCall> toolCalls;
  const AssistantMessage({this.text, this.toolCalls = const []});
}

/// The result of executing a tool call, fed back to the model.
class ToolResultMessage extends ChatMessage {
  final String callId;
  final String name;

  /// JSON-encoded result payload.
  final String outputJson;
  const ToolResultMessage({required this.callId, required this.name, required this.outputJson});
}

/// Declaration of a tool the model may call.
class ToolSpec {
  final String name;
  final String description;

  /// JSON schema for the arguments object. Should be strict-compatible:
  /// `additionalProperties: false`, every property listed in `required`
  /// (use `["string", "null"]` types for optional values).
  final Map<String, dynamic> parameters;
  const ToolSpec({required this.name, required this.description, required this.parameters});
}

/// A tool call requested by the model.
class ToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;
  const ToolCall({required this.id, required this.name, required this.arguments});

  @override
  String toString() => 'ToolCall($name ${jsonEncode(arguments)})';
}

/// One request to the model.
class LlmRequest {
  /// System prompt / instructions, rebuilt every turn.
  final String instructions;

  /// Full history including tool calls and results.
  final List<ChatMessage> messages;
  final List<ToolSpec> tools;

  /// Optional strict JSON schema the final text reply must conform to.
  final Map<String, dynamic>? responseSchema;
  const LlmRequest({
    required this.instructions,
    required this.messages,
    this.tools = const [],
    this.responseSchema,
  });
}

/// The model's response to one request.
class LlmResponse {
  /// Final text (JSON string when a response schema was requested), if any.
  final String? text;
  final List<ToolCall> toolCalls;

  /// Provider-specific usage info, for debug logging only.
  final Map<String, dynamic>? usage;

  /// What the model heard, when the turn was sent as audio rather than text.
  /// Null for text turns and for providers that do not transcribe.
  final String? transcript;
  const LlmResponse(
      {this.text, this.toolCalls = const [], this.usage, this.transcript});

  bool get hasToolCalls => toolCalls.isNotEmpty;
}

class LlmException implements Exception {
  final String message;
  final int? statusCode;
  const LlmException(this.message, {this.statusCode});
  @override
  String toString() => 'LlmException($statusCode): $message';
}

abstract class LlmClient {
  /// Provider identifier, e.g. `openai`, `anthropic`.
  String get id;

  /// Model identifier used for requests.
  String get model;

  Future<LlmResponse> complete(LlmRequest request, {Duration timeout = const Duration(seconds: 30)});
}

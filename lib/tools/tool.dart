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

// Tool (function calling) contract and registry.

import 'dart:convert' show jsonEncode;

import '../common.dart' show dlog;
import '../llm/llm_client.dart' show ToolCall, ToolSpec;

/// Ambient information tools may need. Never taken from the model.
class ToolContext {
  /// WGS84 [latitude, longitude] if the user shares location, else null.
  final List<double>? location;
  final DateTime now;
  final String voiceID;
  final bool privateMode;
  final String? clientID;
  final String? clientType;
  final String? clientVersion;
  const ToolContext({
    required this.now,
    this.location,
    this.voiceID = '',
    this.privateMode = false,
    this.clientID,
    this.clientType,
    this.clientVersion,
  });
}

class ToolResult {
  final bool ok;

  /// Payload sent back to the model as JSON. Keep it compact.
  final Map<String, dynamic> data;

  /// Optional image to show in the transcript.
  final String? imageURL;

  /// Optional URL the UI should open after the spoken reply.
  final Uri? openURL;

  /// When true the turn ends here: the session speaks [speech] and never asks
  /// the model to phrase a confirmation. Set by tools that hand off to another
  /// app, where the user is already looking at the result.
  final bool endsTurn;

  /// Spoken Icelandic confirmation, used only when [endsTurn] is true. The
  /// `summary` in [data] is written for the model and reads like a log line,
  /// so it is not suitable for speech.
  final String? speech;

  const ToolResult({
    required this.ok,
    required this.data,
    this.imageURL,
    this.openURL,
    this.endsTurn = false,
    this.speech,
  });

  factory ToolResult.success(Map<String, dynamic> data,
          {String? imageURL, Uri? openURL, bool endsTurn = false, String? speech}) =>
      ToolResult(
          ok: true,
          data: {'ok': true, ...data},
          imageURL: imageURL,
          openURL: openURL,
          endsTurn: endsTurn,
          speech: speech);

  factory ToolResult.failure(String error) => ToolResult(ok: false, data: {'ok': false, 'error': error});

  String toJson() => jsonEncode(data);
}

abstract class Tool {
  String get name;

  /// Icelandic description shown to the model.
  String get description;

  /// Strict JSON schema for the arguments object.
  Map<String, dynamic> get parameters;

  /// Short Icelandic label shown in the transcript while running,
  /// e.g. "Leita í Greynir…". Null for silent tools.
  String? get activityLabel => null;

  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx);

  ToolSpec get spec => ToolSpec(name: name, description: description, parameters: parameters);
}

class ToolRegistry {
  final Map<String, Tool> _tools = {};

  void register(Tool tool) {
    _tools[tool.name] = tool;
  }

  void registerAll(Iterable<Tool> tools) => tools.forEach(register);

  Tool? lookup(String name) => _tools[name];

  List<Tool> get tools => _tools.values.toList(growable: false);

  List<ToolSpec> specs() => _tools.values.map((t) => t.spec).toList(growable: false);

  /// Runs a tool call, converting unknown tools and exceptions into failures.
  Future<ToolResult> dispatch(ToolCall call, ToolContext ctx) async {
    final tool = _tools[call.name];
    if (tool == null) {
      return ToolResult.failure('Óþekkt verkfæri: ${call.name}');
    }
    try {
      return await tool.call(call.arguments, ctx);
    } catch (e) {
      dlog('Tool ${call.name} failed: $e');
      return ToolResult.failure(e.toString());
    }
  }
}

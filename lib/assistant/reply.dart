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

// Structured final reply from the model.

import 'dart:convert' show jsonDecode;

enum ReplyKind { answer, actionDone, clarify, unknown }

class AssistantReply {
  final ReplyKind kind;

  /// Short spoken text (the only thing sent to TTS).
  final String speech;

  /// Richer text shown in the transcript.
  final String display;

  const AssistantReply({required this.kind, required this.speech, required this.display});

  /// Strict JSON schema for the reply, shared by all LLM adapters.
  static const Map<String, dynamic> schema = {
    'type': 'object',
    'properties': {
      'kind': {
        'type': 'string',
        'enum': ['answer', 'action_done', 'clarify', 'unknown'],
        'description': 'answer: svar við spurningu; action_done: aðgerð framkvæmd; '
            'clarify: vantar upplýsingar frá notanda; unknown: veit ekki / ekki hægt.'
      },
      'speech': {
        'type': 'string',
        'description': 'Það sem lesið verður upp. Ein til tvær stuttar setningar á íslensku, '
            'tölur og dagsetningar skrifaðar með bókstöfum, engir hlekkir.'
      },
      'display': {
        'type': 'string',
        'description': 'Texti til að sýna á skjá. Má innihalda tölur, hlekki og heimild.'
      },
    },
    'required': ['kind', 'speech', 'display'],
    'additionalProperties': false,
  };

  static ReplyKind _kindFromString(String? s) => switch (s) {
        'action_done' => ReplyKind.actionDone,
        'clarify' => ReplyKind.clarify,
        'unknown' => ReplyKind.unknown,
        _ => ReplyKind.answer,
      };

  /// Parses the model's final text. Non-JSON text is treated as a plain answer.
  static AssistantReply parse(String text) {
    final trimmed = text.trim();
    try {
      final obj = jsonDecode(trimmed);
      if (obj is Map<String, dynamic>) {
        final speech = (obj['speech'] ?? obj['display'] ?? '').toString();
        final display = (obj['display'] ?? obj['speech'] ?? '').toString();
        return AssistantReply(kind: _kindFromString(obj['kind']?.toString()), speech: speech, display: display);
      }
    } catch (_) {
      // Not JSON: fall through.
    }
    return AssistantReply(kind: ReplyKind.answer, speech: trimmed, display: trimmed);
  }
}

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

// Multi-turn conversation model shared by the UI and the LLM pipeline.

import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../common.dart' show kConversationIdleReset, kMaxConversationUserTurns;
import '../llm/llm_client.dart';

enum TurnRole { user, assistant, tool }

/// A UI-facing entry in the transcript.
class Turn {
  final TurnRole role;
  final String text;
  final String? imageURL;
  final DateTime at;
  Turn(this.role, this.text, {this.imageURL}) : at = DateTime.now();
}

class Conversation extends ChangeNotifier {
  Conversation();

  /// App-wide conversation instance.
  static final Conversation shared = Conversation();

  /// LLM-facing history (includes tool calls and results).
  final List<ChatMessage> history = [];

  /// UI-facing transcript.
  final List<Turn> turns = [];

  DateTime? lastActivity;

  bool get isEmpty => turns.isEmpty;

  void addUser(String text) {
    history.add(UserMessage(text));
    turns.add(Turn(TurnRole.user, text));
    _touch();
  }

  /// Adds the model's displayable reply. The LLM-facing message must be
  /// added separately via [addHistory] (it may be JSON, tool calls, etc.).
  void addAssistant(String display, {String? imageURL}) {
    turns.add(Turn(TurnRole.assistant, display, imageURL: imageURL));
    _touch();
  }

  /// Small status line in the transcript, e.g. "Leita í Greynir…".
  /// Not sent to the model.
  void addToolActivity(String label) {
    turns.add(Turn(TurnRole.tool, label));
    _touch();
  }

  void addHistory(ChatMessage message) {
    history.add(message);
    trim();
  }

  /// Keeps at most [maxUserTurns] user turns of history (and their
  /// following assistant/tool messages).
  void trim({int maxUserTurns = kMaxConversationUserTurns}) {
    int userCount = history.whereType<UserMessage>().length;
    while (userCount > maxUserTurns && history.isNotEmpty) {
      final removed = history.removeAt(0);
      if (removed is UserMessage) {
        userCount--;
      }
      // Drop orphaned assistant/tool messages before the next user message.
      while (history.isNotEmpty && history.first is! UserMessage) {
        history.removeAt(0);
      }
    }
  }

  void reset() {
    history.clear();
    turns.clear();
    lastActivity = null;
    notifyListeners();
  }

  /// Starts a fresh conversation if the last activity is older than [idle].
  void resetIfStale({Duration idle = kConversationIdleReset}) {
    final last = lastActivity;
    if (last != null && DateTime.now().difference(last) > idle) {
      reset();
    }
  }

  void _touch() {
    lastActivity = DateTime.now();
    notifyListeners();
  }
}

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

// Multi-turn transcript view and the typed-text input bar.
//
// The transcript renders a [Conversation] and rebuilds itself whenever the
// conversation changes, so the session route does not have to hold the
// dialogue text in its own state.

import 'package:flutter/material.dart';

import './assistant/conversation.dart' show Conversation, Turn, TurnRole;
import './theme.dart' show defaultFontSize, sessionTextStyle;

// UI strings
const String kTextInputHint = 'Skrifaðu skipun…';
const String kSendCommandLabel = 'Senda skipun';
const String kNewConversationLabel = 'Ný samræða';

// Text styles for the transcript
const TextStyle kTranscriptUserTextStyle =
    TextStyle(fontSize: defaultFontSize, fontWeight: FontWeight.bold);
const TextStyle kTranscriptToolTextStyle =
    TextStyle(fontSize: defaultFontSize * 0.75, fontStyle: FontStyle.italic);

/// Scrollable view of the conversation so far. Shows [emptyMessage] when
/// there are no turns yet. Long-pressing it starts a new conversation.
class TranscriptView extends StatefulWidget {
  final Conversation conversation;
  final String emptyMessage;

  /// Optional externally owned controller, so the route can scroll the
  /// transcript when a reply arrives.
  final ScrollController? scrollController;
  final void Function()? onNewConversation;

  const TranscriptView({
    super.key,
    required this.conversation,
    this.emptyMessage = '',
    this.scrollController,
    this.onNewConversation,
  });

  @override
  State<TranscriptView> createState() => _TranscriptViewState();
}

class _TranscriptViewState extends State<TranscriptView> {
  ScrollController? _ownController;
  int _lastTurnCount = -1;

  ScrollController get _controller =>
      widget.scrollController ?? (_ownController ??= ScrollController());

  @override
  void dispose() {
    _ownController?.dispose();
    super.dispose();
  }

  // Scroll to the newest turn once the new content has been laid out
  void _scrollToBottomAfterBuild() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted == false) {
        return;
      }
      final ScrollController c = _controller;
      if (c.hasClients == false) {
        return;
      }
      c.jumpTo(c.position.maxScrollExtent);
    });
  }

  // The image of the most recent assistant turn that has one, if any
  String? _lastImageURL(List<Turn> turns) {
    for (final Turn t in turns.reversed) {
      if (t.role == TurnRole.assistant) {
        return t.imageURL;
      }
    }
    return null;
  }

  Widget _turnWidget(Turn turn) {
    switch (turn.role) {
      case TurnRole.user:
        return Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 2),
            child: SizedBox(
                width: double.infinity,
                child: SelectableText(turn.text,
                    textAlign: TextAlign.right, style: kTranscriptUserTextStyle)));
      case TurnRole.assistant:
        return Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 8),
            child: SizedBox(
                width: double.infinity, child: SelectableText(turn.text, style: sessionTextStyle)));
      case TurnRole.tool:
        return Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 2),
            child: SizedBox(
                width: double.infinity, child: Text(turn.text, style: kTranscriptToolTextStyle)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: widget.conversation,
        builder: (BuildContext context, Widget? child) {
          final List<Turn> turns = widget.conversation.turns;
          if (turns.length != _lastTurnCount) {
            _lastTurnCount = turns.length;
            _scrollToBottomAfterBuild();
          }

          final List<Widget> subWidgets = <Widget>[];
          if (turns.isEmpty) {
            // No conversation yet, show the intro message
            subWidgets.add(FractionallySizedBox(
                widthFactor: 1.0,
                child: SelectableText(widget.emptyMessage, style: sessionTextStyle)));
          } else {
            subWidgets.addAll(turns.map(_turnWidget));
            final String? imageURL = _lastImageURL(turns);
            if (imageURL != null) {
              subWidgets.add(Padding(
                  padding: const EdgeInsets.only(top: 10),
                  // Network images are automatically cached for us
                  child: Image.network(imageURL,
                      errorBuilder: (BuildContext c, Object e, StackTrace? s) =>
                          const SizedBox.shrink())));
            }
          }

          // Wrap the scroll view in a ShaderMask to create a linear gradient fade effect
          return GestureDetector(
              onLongPress: widget.onNewConversation,
              child: ShaderMask(
                  shaderCallback: (Rect rect) {
                    return const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      // Purple color is not used concretely, only for the fractions of the vector
                      colors: [Colors.purple, Colors.transparent, Colors.transparent, Colors.purple],
                      stops: [0.0, 0.05, 0.95, 1.0],
                    ).createShader(rect);
                  },
                  blendMode: BlendMode.dstOut,
                  child: SingleChildScrollView(
                      controller: _controller,
                      scrollDirection: Axis.vertical,
                      clipBehavior: Clip.antiAlias,
                      padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 0),
                      child: Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Column(children: subWidgets)))));
        });
  }
}

/// Text field for typing commands instead of speaking them. The controller is
/// owned by the parent route so that frequent rebuilds don't lose the text.
class TextInputBar extends StatelessWidget {
  final TextEditingController controller;
  final void Function(String text) onSubmit;

  /// False while a session is active.
  final bool enabled;
  final void Function()? onNewConversation;

  const TextInputBar({
    super.key,
    required this.controller,
    required this.onSubmit,
    this.enabled = true,
    this.onNewConversation,
  });

  void _submit() {
    final String text = controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    controller.clear();
    onSubmit(text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.only(left: 20, right: 8),
        child: Row(children: <Widget>[
          Expanded(
              child: TextField(
            controller: controller,
            enabled: enabled,
            textInputAction: TextInputAction.send,
            style: const TextStyle(fontSize: defaultFontSize),
            decoration: const InputDecoration(
                hintText: kTextInputHint, border: InputBorder.none, isDense: true),
            onSubmitted: (String _) => _submit(),
          )),
          Semantics(
              label: kSendCommandLabel,
              child: IconButton(
                  icon: const Icon(Icons.send), onPressed: enabled ? _submit : null)),
          if (onNewConversation != null)
            Semantics(
                label: kNewConversationLabel,
                child: IconButton(
                    icon: const Icon(Icons.add_comment_outlined),
                    onPressed: onNewConversation)),
        ]));
  }
}

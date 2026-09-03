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

// Lets a Shortcut run one Embla turn and read the result.
//
// The result contract mirrors the embla-2.0 Swift MVP so shortcuts written
// against that app keep working: every outcome is a dictionary with an
// `action` of `done` or `none`, and a failure is `none` with a `reason`
// rather than an error. A shortcut that throws mid-run leaves the user with
// nothing, so this end never throws.

import 'dart:async';

import 'package:flutter/services.dart' show MethodCall, MethodChannel;

import './common.dart' show dlog;
import './tools/device_actions_channel.dart' show kDeviceActionsChannelName;

/// Starts one voice turn. Returns as soon as capture has begun.
typedef VoiceTurnStarter = Future<void> Function();

/// How long a shortcut-driven turn may take before it gives up. Long enough
/// for record, transcribe, a tool call and speech.
const Duration kShortcutTurnTimeout = Duration(seconds: 45);

class ShortcutsBridge {
  ShortcutsBridge._();
  static final ShortcutsBridge _instance = ShortcutsBridge._();
  factory ShortcutsBridge() => _instance;

  final MethodChannel _channel = const MethodChannel(kDeviceActionsChannelName);
  VoiceTurnStarter? _startTurn;
  Completer<Map<String, dynamic>>? _pending;

  /// Wired by the session route, which owns the assistant session.
  void register(VoiceTurnStarter startTurn) {
    _startTurn = startTurn;
    _channel.setMethodCallHandler(_handle);
  }

  void unregister() {
    _startTurn = null;
    _channel.setMethodCallHandler(null);
  }

  Future<Object?> _handle(MethodCall call) async {
    switch (call.method) {
      case 'runVoiceTurn':
        return _runVoiceTurn();
      default:
        return null;
    }
  }

  Future<Map<String, dynamic>> _runVoiceTurn() async {
    final VoiceTurnStarter? start = _startTurn;
    if (start == null) {
      return _none('Embla er ekki tilbúin');
    }
    // A shortcut fired twice should not leave the first caller hanging.
    _pending?.complete(_none('Ný skipun tók við'));
    final Completer<Map<String, dynamic>> pending = Completer<Map<String, dynamic>>();
    _pending = pending;
    try {
      await start();
    } catch (e) {
      _pending = null;
      return _none('Ekki tókst að hefja hlustun: $e');
    }
    try {
      return await pending.future.timeout(kShortcutTurnTimeout);
    } on TimeoutException {
      return _none('Embla svaraði ekki í tæka tíð');
    } finally {
      _pending = null;
    }
  }

  /// Called by the session route when a turn produced an answer.
  void reportReply({required String speech, required String display, String? transcript}) {
    _settle(<String, dynamic>{
      'action': 'done',
      'speech': speech,
      'display': display,
      if (transcript != null) 'transcript': transcript,
    });
  }

  /// Hands an action to the shortcut to carry out with its own actions, for
  /// what the app cannot do or cannot do visibly: send an SMS, or put a timer
  /// or alarm in the Clock app. [result] carries the `action` name and its
  /// fields, mirroring the embla-2.0 contract. Returns false when no shortcut
  /// is waiting, so the caller does the in-app version instead.
  bool handOff(Map<String, dynamic> result) {
    if (!isAwaitingTurn) {
      return false;
    }
    _settle(result);
    return true;
  }

  /// Called when the turn ended without an answer: nothing heard, cancelled,
  /// or an error. Never an exception, so the shortcut can branch on `reason`.
  void reportNone(String reason) => _settle(_none(reason));

  bool get isAwaitingTurn => _pending?.isCompleted == false;

  void _settle(Map<String, dynamic> result) {
    final Completer<Map<String, dynamic>>? pending = _pending;
    if (pending == null || pending.isCompleted) {
      return;
    }
    dlog('Shortcut turn result: ${result['action']}');
    pending.complete(result);
  }

  static Map<String, dynamic> _none(String reason) =>
      <String, dynamic>{'action': 'none', 'reason': reason};
}

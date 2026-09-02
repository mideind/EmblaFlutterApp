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

// Method channel for device actions that have no Flutter plugin.
//
// Implemented natively in ios/Runner/EmblaActions.swift: EventKit reminders
// and AlarmKit timers/alarms. There is no Android implementation; the tools
// fall back to intents and calendar events there.

import 'package:flutter/services.dart' show MethodChannel, MissingPluginException, PlatformException;

import '../common.dart' show dlog;
import 'tool_args.dart' show formatLocalISO8601;

const String kDeviceActionsChannelName = 'is.mideind.embla/actions';

/// Error code the native side returns when the OS is too old for the API.
const String kDeviceActionUnsupported = 'unsupported';

/// Error code used when the native side is not there at all.
const String kDeviceActionUnimplemented = 'unimplemented';

/// A failure reported by the native side.
class DeviceActionsException implements Exception {
  /// Platform error code, e.g. `unsupported`, `permission_denied`.
  final String code;
  final String message;
  const DeviceActionsException(this.code, this.message);

  /// True when the device's OS version lacks the underlying API.
  bool get isUnsupported => code == kDeviceActionUnsupported || code == kDeviceActionUnimplemented;

  @override
  String toString() => 'DeviceActionsException($code): $message';
}

/// Native device actions. Faked in tests.
abstract class DeviceActions {
  /// Creates a reminder in the system reminders app (iOS only).
  Future<void> addReminder({required String title, DateTime? due});

  /// Starts a countdown timer.
  Future<void> setTimer({required int seconds, String? title});

  /// Sets an alarm for an absolute local time.
  Future<void> setAlarm({required DateTime start, String? title});
}

class DeviceActionsChannel implements DeviceActions {
  final MethodChannel _channel;

  DeviceActionsChannel({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(kDeviceActionsChannelName);

  @override
  Future<void> addReminder({required String title, DateTime? due}) {
    return _invoke('addReminder', <String, dynamic>{
      'title': title,
      'due': due == null ? null : formatLocalISO8601(due),
    });
  }

  @override
  Future<void> setTimer({required int seconds, String? title}) {
    return _invoke('setTimer', <String, dynamic>{'seconds': seconds, 'title': title});
  }

  @override
  Future<void> setAlarm({required DateTime start, String? title}) {
    return _invoke('setAlarm', <String, dynamic>{
      'start': formatLocalISO8601(start),
      'title': title,
    });
  }

  Future<void> _invoke(String method, Map<String, dynamic> args) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on PlatformException catch (e) {
      dlog('Device action $method failed: $e');
      throw DeviceActionsException(e.code, e.message ?? e.code);
    } on MissingPluginException catch (e) {
      dlog('Device action $method unimplemented: $e');
      throw const DeviceActionsException(
          kDeviceActionUnimplemented, 'Aðgerðin er ekki tiltæk í þessari útgáfu appsins');
    }
  }
}

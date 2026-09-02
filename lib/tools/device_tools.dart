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

// Assembly of the device action tools for the platform we are running on.

import 'package:add_2_calendar/add_2_calendar.dart' show Add2Calendar;
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;

import '../common.dart' show dlog;
import 'alarm_tool.dart';
import 'calendar_tool.dart';
import 'device_actions_channel.dart';
import 'message_tool.dart';
import 'reminder_tool.dart';
import 'tool.dart' show Tool;

/// Builds the device action tools appropriate for [platform].
///
/// Everything that touches the OS is injectable so the tools can be unit
/// tested without plugins. Returns an empty list on platforms where none of
/// the underlying plugins work (desktop, web), so the model is never told
/// about actions that cannot happen.
List<Tool> buildDeviceTools({
  TargetPlatform? platform,
  DeviceActions? actions,
  AddToCalendar? addToCalendar,
  LaunchAndroidIntent? launchIntent,
  LaunchUri? launchUri,
}) {
  final TargetPlatform target = platform ?? defaultTargetPlatform;
  final bool isIOS = target == TargetPlatform.iOS;
  final bool isAndroid = target == TargetPlatform.android;
  if (!isIOS && !isAndroid) {
    dlog('No device action tools available on $target');
    return const <Tool>[];
  }

  final DeviceActions deviceActions = actions ?? DeviceActionsChannel();
  final AddToCalendar calendar = addToCalendar ?? Add2Calendar.addEvent2Cal;

  return <Tool>[
    AddCalendarEventTool(addToCalendar: calendar),
    AddReminderTool(
      actions: deviceActions,
      addToCalendar: calendar,
      useNativeReminders: isIOS,
    ),
    SetTimerTool(
      actions: deviceActions,
      useNativeAlarms: isIOS,
      launchIntent: launchIntent,
    ),
    SetAlarmTool(
      actions: deviceActions,
      useNativeAlarms: isIOS,
      launchIntent: launchIntent,
    ),
    DraftMessageTool(isIOS: isIOS, launchUri: launchUri),
  ];
}

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
import '../prefs.dart' show Prefs;
import '../shortcuts_bridge.dart' show ShortcutsBridge;
import 'alarm_tool.dart';
import 'calendar_tool.dart';
import 'device_actions_channel.dart';
import 'device_contacts.dart';
import 'directions_tool.dart';
import 'message_tool.dart';
import 'reminder_tool.dart';
import 'shopping_tool.dart';
import 'spotify_tools.dart';
import '../spotify_client.dart' show SpotifyClient;
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
  LookupContacts? lookupContacts,
  SpotifyClient? spotify,
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
    AddCalendarEventTool(
      addToCalendar: calendar,
      actions: deviceActions,
      useNativeCalendar: isIOS,
    ),
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
      handOff: ShortcutsBridge().handOff,
    ),
    DraftMessageTool(
      isIOS: isIOS,
      launchUri: launchUri,
      lookupContacts: lookupContacts ?? deviceContacts,
      handOff: ShortcutsBridge().handOff,
    ),
    // Android hands alarms to the clock app via an intent, so there is nothing
    // to read back or cancel; only offer these where AlarmKit owns them.
    // Apple Maps cannot auto-start navigation from a URL, so Android (and
    // anyone who opts in) gets the Google form, which can.
    GetDirectionsTool(
      launchUri: launchUri,
      preferGoogleMaps: () => !isIOS || Prefs().boolForKey('use_google_maps'),
    ),
    // Reminders lists are an Apple concept; Android has no equivalent target.
    if (isIOS) AddShoppingTool(actions: deviceActions),
    // Spotify needs the iOS SDK for playback and a client ID in the build.
    if (isIOS) ...spotifyTools(spotify ?? SpotifyClient.fromKeys(actions: deviceActions)),
    if (isIOS) ListAlarmsTool(actions: deviceActions),
    if (isIOS) CancelAlarmsTool(actions: deviceActions),
  ];
}

List<Tool> spotifyTools(SpotifyClient spotify) => spotify.isConfigured
    ? <Tool>[PlayMusicTool(spotify), QueueMusicTool(spotify), ControlMusicTool(spotify)]
    : const <Tool>[];

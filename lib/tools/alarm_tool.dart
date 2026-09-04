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

// set_timer and set_alarm.
//
// Android: the standard AlarmClock intents, handled by whichever clock app is
// installed. SKIP_UI keeps the user in Embla.
// iOS: AlarmKit through our own method channel, which requires iOS 26. On
// older versions the channel returns `unsupported` and we say so.
//
// AlarmKit alarms belong to the app and never show in Apple's Clock app. A
// timer is still visible: its countdown is a Live Activity (Dynamic Island and
// Lock Screen, with a stop button) drawn by the EmblaAlarmWidget extension. A
// fixed alarm has no such surface until it fires, so in a shortcut-driven turn
// set_alarm hands the alarm to the shortcut, whose Clock "Create Alarm" action
// makes one the user can see and cancel in Clock.

import 'package:android_intent_plus/android_intent.dart' show AndroidIntent;

import 'device_actions_channel.dart' show DeviceActions, DeviceActionsException;
import 'tool.dart' show ShortcutHandoff, Tool, ToolContext, ToolResult, noShortcutHandoff;
import 'tool_args.dart';

/// Injectable side effect: fires an Android intent.
typedef LaunchAndroidIntent = Future<void> Function(AndroidIntent intent);

Future<void> defaultLaunchAndroidIntent(AndroidIntent intent) => intent.launch();

// AlarmClock intent actions and extras.
// See https://developer.android.com/reference/android/provider/AlarmClock
const String kSetTimerAction = 'android.intent.action.SET_TIMER';
const String kSetAlarmAction = 'android.intent.action.SET_ALARM';
const String kAlarmExtraLength = 'android.intent.extra.alarm.LENGTH';
const String kAlarmExtraHour = 'android.intent.extra.alarm.HOUR';
const String kAlarmExtraMinutes = 'android.intent.extra.alarm.MINUTES';
const String kAlarmExtraMessage = 'android.intent.extra.alarm.MESSAGE';
const String kAlarmExtraSkipUI = 'android.intent.extra.alarm.SKIP_UI';

/// Shown when the device runs an iOS version without AlarmKit.
const String kIOSAlarmUnsupportedMessage = 'Vekjarar og teljarar krefjast iOS 26';

const String kDefaultTimerTitle = 'Teljari';
const String kDefaultAlarmTitle = 'Vekjari';

/// Longest timer we pass on, one day. Anything more is a misparse.
const int kMaxTimerSeconds = 24 * 60 * 60;

String _alarmFailureMessage(DeviceActionsException e) =>
    e.isUnsupported ? kIOSAlarmUnsupportedMessage : e.message;

class SetTimerTool extends Tool {
  final DeviceActions actions;
  final LaunchAndroidIntent launchIntent;

  /// True on iOS, where timers go through AlarmKit instead of an intent.
  final bool useNativeAlarms;

  SetTimerTool({
    required this.actions,
    required this.useNativeAlarms,
    LaunchAndroidIntent? launchIntent,
  }) : launchIntent = launchIntent ?? defaultLaunchAndroidIntent;

  @override
  String get name => 'set_timer';

  @override
  String get description =>
      'Ræsir niðurteljara sem hringir eftir tilgreindan tíma. Notaðu þetta þegar '
      'notandinn nefnir lengd, t.d. „settu teljara á fimm mínútur“. Ef notandinn '
      'nefnir tiltekinn tíma dags skal nota set_alarm í staðinn.';

  @override
  String? get activityLabel => 'Stilli teljara…';

  @override
  Map<String, dynamic> get parameters => strictObjectSchema(<String, Map<String, dynamic>>{
        'seconds': integerProperty('Lengd teljarans í sekúndum.'),
        'title': optionalStringProperty('Heiti teljarans, t.d. „pasta“. '
            'Skilaðu null ef ekkert heiti er nefnt.'),
      });

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final int? seconds = parseInt(args['seconds']);
    if (seconds == null || seconds <= 0) {
      return ToolResult.failure('Vantar lengd teljarans í sekúndum (seconds).');
    }
    if (seconds > kMaxTimerSeconds) {
      return ToolResult.failure('Teljarinn má ekki vera lengri en einn dagur.');
    }
    final String title = optionalString(args['title']) ?? kDefaultTimerTitle;
    if (useNativeAlarms) {
      try {
        await actions.setTimer(seconds: seconds, title: title);
      } on DeviceActionsException catch (e) {
        return ToolResult.failure(_alarmFailureMessage(e));
      }
    } else {
      await launchIntent(AndroidIntent(
        action: kSetTimerAction,
        arguments: <String, dynamic>{
          kAlarmExtraLength: seconds,
          kAlarmExtraMessage: title,
          kAlarmExtraSkipUI: true,
        },
      ));
    }
    return ToolResult.success(<String, dynamic>{
      'summary': 'Teljari ræstur: ${formatIcelandicDuration(seconds)}',
    });
  }
}

class SetAlarmTool extends Tool {
  final DeviceActions actions;
  final LaunchAndroidIntent launchIntent;

  /// True on iOS, where alarms go through AlarmKit instead of an intent.
  final bool useNativeAlarms;
  final ShortcutHandoff handOff;

  SetAlarmTool({
    required this.actions,
    required this.useNativeAlarms,
    LaunchAndroidIntent? launchIntent,
    ShortcutHandoff? handOff,
  })  : launchIntent = launchIntent ?? defaultLaunchAndroidIntent,
        handOff = handOff ?? noShortcutHandoff;

  @override
  String get name => 'set_alarm';

  @override
  String get description =>
      'Setur vekjaraklukku á tiltekinn tíma dags. Notaðu þetta þegar notandinn '
      'nefnir klukkutíma, t.d. „vektu mig klukkan sjö“. Ef notandinn nefnir '
      'lengd í staðinn skal nota set_timer.';

  @override
  String? get activityLabel => 'Stilli vekjara…';

  @override
  Map<String, dynamic> get parameters => strictObjectSchema(<String, Map<String, dynamic>>{
        'time': stringProperty('Tími dags á sniðinu HH:mm, 24 klukkustunda kerfi, t.d. 07:30.'),
        'title': optionalStringProperty('Heiti vekjarans. Skilaðu null ef ekkert heiti er nefnt.'),
        'date': optionalStringProperty('Dagsetning á sniðinu ÁÁÁÁ-MM-DD ef vekjarinn á ekki að '
            'hringja næst þegar þessi tími dags kemur. Skilaðu null annars.'),
      });

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final ({int hour, int minute})? time = parseClockTime(optionalString(args['time']));
    if (time == null) {
      return ToolResult.failure('Vantar eða ógildur tími (time). Notaðu sniðið 07:30.');
    }
    final String title = optionalString(args['title']) ?? kDefaultAlarmTitle;

    final String? rawDate = optionalString(args['date']);
    DateTime? day;
    if (rawDate != null) {
      day = parseLocalDateTime(rawDate);
      if (day == null) {
        return ToolResult.failure('Ógild dagsetning (date). Notaðu sniðið 2026-08-24.');
      }
    }
    // The next occurrence of that time of day, unless a date was given.
    DateTime start = day == null
        ? DateTime(ctx.now.year, ctx.now.month, ctx.now.day, time.hour, time.minute)
        : DateTime(day.year, day.month, day.day, time.hour, time.minute);
    if (day == null && !start.isAfter(ctx.now)) {
      start = start.add(const Duration(days: 1));
    }
    final String when = formatIcelandicDateTime(start);

    // Clock's Create Alarm takes a time of day, so a dated alarm still fires
    // the next time that hour comes round; `date` is passed for a shortcut
    // that wants to do better.
    if (handOff(<String, dynamic>{
      'action': 'set_alarm',
      'time': '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      if (rawDate != null) 'date': rawDate,
      'title': title,
    })) {
      return ToolResult.success(<String, dynamic>{'summary': 'Vekjari ($when) afhentur flýtileið'},
          endsTurn: true, speech: 'Ég setti vekjara á $when.');
    }

    if (useNativeAlarms) {
      try {
        await actions.setAlarm(start: start, title: title);
      } on DeviceActionsException catch (e) {
        return ToolResult.failure(_alarmFailureMessage(e));
      }
    } else {
      // SET_ALARM only carries a time of day; the clock app picks the next
      // occurrence, which is what we computed above anyway.
      await launchIntent(AndroidIntent(
        action: kSetAlarmAction,
        arguments: <String, dynamic>{
          kAlarmExtraHour: time.hour,
          kAlarmExtraMinutes: time.minute,
          kAlarmExtraMessage: title,
          kAlarmExtraSkipUI: true,
        },
      ));
    }
    return ToolResult.success(<String, dynamic>{
      'summary': 'Vekjari settur á $when',
    });
  }
}

/// Lists the timers and alarms this app has scheduled and not yet cancelled.
/// iOS only: on Android alarms are handed to the clock app via an intent and
/// cannot be read back.
class ListAlarmsTool extends Tool {
  final DeviceActions actions;

  ListAlarmsTool({required this.actions});

  @override
  String get name => 'list_alarms';

  @override
  String get description =>
      'Skilar þeim niðurteljurum og vekjurum sem Embla hefur stillt og eru enn virkir. '
      'Notaðu þetta þegar notandinn spyr hvað sé í gangi, eða til að finna réttan '
      'teljara áður en þú hættir við hann.';

  @override
  String? get activityLabel => 'Athuga vekjara…';

  @override
  Map<String, dynamic> get parameters => strictObjectSchema(const <String, Map<String, dynamic>>{});

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    try {
      final List<Map<String, dynamic>> alarms = await actions.listAlarms();
      return ToolResult.success(<String, dynamic>{
        'count': alarms.length,
        'alarms': alarms,
      });
    } on DeviceActionsException catch (e) {
      return ToolResult.failure(e.message);
    }
  }
}

/// Cancels a pending timer or alarm. With no id, cancels all of them.
class CancelAlarmsTool extends Tool {
  final DeviceActions actions;

  CancelAlarmsTool({required this.actions});

  @override
  String get name => 'cancel_alarms';

  @override
  String get description =>
      'Hættir við niðurteljara eða vekjara sem Embla stillti. Skildu id eftir tómt '
      'til að hætta við allt sem er virkt. Ef fleiri en eitt er virkt og notandinn '
      'á við eitthvað eitt skaltu fyrst kalla á list_alarms og senda rétt id.';

  @override
  String? get activityLabel => 'Hætti við vekjara…';

  @override
  Map<String, dynamic> get parameters => strictObjectSchema(<String, Map<String, dynamic>>{
        'id': optionalStringProperty(
            'Auðkenni þess sem á að hætta við, úr list_alarms. Skilaðu null til að '
            'hætta við allt sem er virkt.'),
      });

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    try {
      final List<String> cancelled = await actions.cancelAlarms(id: optionalString(args['id']));
      if (cancelled.isEmpty) {
        return ToolResult.success(const <String, dynamic>{
          'cancelled': 0,
          'summary': 'Enginn virkur teljari eða vekjari fannst til að hætta við',
        });
      }
      return ToolResult.success(<String, dynamic>{
        'cancelled': cancelled.length,
        'ids': cancelled,
      });
    } on DeviceActionsException catch (e) {
      return ToolResult.failure(e.message);
    }
  }
}

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

// add_reminder: creates a reminder.
//
// iOS has a system reminders database (EventKit), reached through our own
// method channel. Android has no equivalent, so a timed calendar event is the
// closest thing; an untimed reminder has nowhere to go there and fails.

import 'package:add_2_calendar/add_2_calendar.dart' show Event, IOSParams;

import 'calendar_tool.dart' show AddToCalendar;
import 'device_actions_channel.dart' show DeviceActions, DeviceActionsException;
import 'tool.dart' show Tool, ToolContext, ToolResult;
import 'tool_args.dart';

/// Length of the Android fallback calendar event.
const Duration kReminderEventDuration = Duration(minutes: 30);

class AddReminderTool extends Tool {
  final DeviceActions actions;
  final AddToCalendar addToCalendar;

  /// True on iOS, where the native reminders channel is available.
  final bool useNativeReminders;

  AddReminderTool({
    required this.actions,
    required this.addToCalendar,
    required this.useNativeReminders,
  });

  @override
  String get name => 'add_reminder';

  @override
  String get description =>
      'Býr til áminningu um eitthvað sem notandinn þarf að gera. Notaðu þetta '
      'þegar notandinn vill láta minna sig á eitthvað, en ekki fyrir viðburði '
      'sem hafa upphaf og lok. Tímasetning er á ISO 8601 sniði á staðartíma án '
      'tímabeltis, t.d. 2026-08-24T14:00:00.';

  @override
  String? get activityLabel => 'Bý til áminningu…';

  @override
  Map<String, dynamic> get parameters => strictObjectSchema(<String, Map<String, dynamic>>{
        'title': stringProperty('Það sem á að minna notandann á, t.d. „kaupa mjólk“.'),
        'due': optionalStringProperty('Tímasetning áminningarinnar á ISO 8601 sniði á staðartíma, '
            't.d. 2026-08-24T14:00:00. Skilaðu null ef engin tímasetning er nefnd.'),
      });

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final String? title = optionalString(args['title']);
    if (title == null) {
      return ToolResult.failure('Vantar heiti áminningarinnar (title).');
    }
    final String? rawDue = optionalString(args['due']);
    final DateTime? due = parseLocalDateTime(rawDue);
    if (rawDue != null && due == null) {
      return ToolResult.failure('Ógild tímasetning (due). Notaðu sniðið 2026-08-24T14:00:00.');
    }

    if (useNativeReminders) {
      try {
        await actions.addReminder(title: title, due: due);
      } on DeviceActionsException catch (e) {
        return ToolResult.failure(e.message);
      }
      final String when = due == null ? '' : ' ${formatIcelandicDateTime(due)}';
      return ToolResult.success(<String, dynamic>{
        'summary': 'Áminning „$title“$when búin til',
      });
    }

    // Android: no reminders app, so use a short calendar event with an alert.
    if (due == null) {
      return ToolResult.failure('Áminningar á Android þurfa tímasetningu. '
          'Spyrðu notandann hvenær hann vill láta minna sig á þetta.');
    }
    final Event event = Event(
      title: title,
      startDate: due,
      endDate: due.add(kReminderEventDuration),
      // Only used on iOS, harmless here, but keeps the event self-describing.
      iosParams: const IOSParams(reminder: Duration.zero),
    );
    // As in add_calendar_event, false here means the user dismissed the sheet
    // just as often as it means it failed to open.
    final bool saved = await addToCalendar(event);
    if (!saved) {
      return ToolResult.success(
        <String, dynamic>{
          'saved': false,
          'summary': 'Notandinn lokaði dagatalinu án þess að vista áminninguna „$title“.',
        },
        endsTurn: true,
        speech: 'Allt í lagi, ég vistaði hana ekki.',
      );
    }
    return ToolResult.success(
      <String, dynamic>{
        'saved': true,
        'summary': 'Áminning „$title“ ${formatIcelandicDateTime(due)} vistuð í dagatali',
      },
      endsTurn: true,
      speech: 'Áminningin „$title“ er komin í dagatalið.',
    );
  }
}

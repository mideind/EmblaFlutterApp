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

// add_calendar_event: puts an event in the user's calendar.
//
// Uses add_2_calendar, which opens the system calendar editor prefilled on
// both platforms. That means no calendar permission prompt and no risk of
// writing something the user did not want, at the cost of handing the user
// over to another app (hence endsTurn).

import 'package:add_2_calendar/add_2_calendar.dart' show Add2Calendar, Event;

import 'device_actions_channel.dart';
import 'tool.dart' show Tool, ToolContext, ToolResult;
import 'tool_args.dart';

/// Injectable side effect: opens the system calendar editor for [event].
typedef AddToCalendar = Future<bool> Function(Event event);

/// Default event length when the model does not give an end time.
const Duration kDefaultEventDuration = Duration(hours: 1);

class AddCalendarEventTool extends Tool {
  final AddToCalendar addToCalendar;
  final DeviceActions? actions;

  /// When true the event is written straight to the default calendar through
  /// EventKit, with no editor to confirm. Hands-free is the point, but it also
  /// means a misheard command lands in the calendar unreviewed. Android has no
  /// equivalent silent path, so it keeps the editor.
  final bool useNativeCalendar;

  AddCalendarEventTool({
    AddToCalendar? addToCalendar,
    this.actions,
    this.useNativeCalendar = false,
  }) : addToCalendar = addToCalendar ?? Add2Calendar.addEvent2Cal;

  @override
  String get name => 'add_calendar_event';

  @override
  String get description =>
      'Setur viðburð í dagatal notandans. Dagatalsforritið opnast með útfylltum '
      'viðburði sem notandinn vistar sjálfur. Tímar eru á ISO 8601 sniði á '
      'staðartíma án tímabeltis, t.d. 2026-08-24T14:00:00. Ef enginn endatími '
      'er tilgreindur verður viðburðurinn klukkustundarlangur.';

  @override
  String? get activityLabel => 'Set í dagatal…';

  @override
  Map<String, dynamic> get parameters => strictObjectSchema(<String, Map<String, dynamic>>{
        'title': stringProperty('Heiti viðburðarins.'),
        'start': stringProperty('Upphafstími á ISO 8601 sniði á staðartíma, t.d. 2026-08-24T14:00:00.'),
        'end': optionalStringProperty('Endatími á sama sniði. Skilaðu null ef hann er ekki nefndur; '
            'þá verður viðburðurinn klukkustundarlangur.'),
        'notes': optionalStringProperty('Nánari lýsing á viðburðinum, annars null.'),
        'location': optionalStringProperty('Staðsetning viðburðarins, annars null.'),
      });

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final String? title = optionalString(args['title']);
    if (title == null) {
      return ToolResult.failure('Vantar heiti viðburðarins (title).');
    }
    final DateTime? start = parseLocalDateTime(optionalString(args['start']));
    if (start == null) {
      return ToolResult.failure(
          'Vantar eða ógildur upphafstími (start). Notaðu sniðið 2026-08-24T14:00:00.');
    }
    DateTime end = parseLocalDateTime(optionalString(args['end'])) ?? start.add(kDefaultEventDuration);
    if (!end.isAfter(start)) {
      end = start.add(kDefaultEventDuration);
    }

    if (useNativeCalendar && actions != null) {
      try {
        await actions!.addCalendarEvent(
          title: title,
          start: start,
          end: end,
          notes: optionalString(args['notes']),
          location: optionalString(args['location']),
        );
      } on DeviceActionsException catch (e) {
        return ToolResult.failure(e.message);
      }
      // Nothing was handed off to another app, so the model phrases the
      // confirmation and can mention what it actually understood.
      return ToolResult.success(<String, dynamic>{
        'saved': true,
        'summary': 'Viðburður „$title“ ${formatIcelandicRange(start, end)} vistaður í dagatali',
      });
    }

    final Event event = Event(
      title: title,
      description: optionalString(args['notes']),
      location: optionalString(args['location']),
      startDate: start,
      endDate: end,
    );
    // add_2_calendar reports the *outcome* of the edit sheet on iOS:
    // .saved -> true, .canceled/.deleted -> false. A dismissed sheet is a
    // deliberate user choice, not a failure, so say so plainly instead of
    // claiming the calendar could not be opened.
    final bool saved = await addToCalendar(event);
    if (!saved) {
      return ToolResult.success(
        <String, dynamic>{
          'saved': false,
          'summary': 'Notandinn lokaði dagatalinu án þess að vista viðburðinn '
              '„$title“. Staðfestu einungis að hann hafi ekki verið vistaður.',
        },
        endsTurn: true,
        speech: 'Allt í lagi, ég vistaði hann ekki.',
      );
    }
    return ToolResult.success(
      <String, dynamic>{
        'saved': true,
        'summary': 'Viðburður „$title“ ${formatIcelandicRange(start, end)} vistaður í dagatali',
      },
      endsTurn: true,
      speech: 'Viðburðurinn „$title“ er kominn í dagatalið.',
    );
  }
}

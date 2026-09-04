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

// Tests for the device action tools. No real plugin is ever touched: every
// platform side effect is injected as a fake.

import 'package:add_2_calendar/add_2_calendar.dart' show Event;
import 'package:android_intent_plus/android_intent.dart' show AndroidIntent;
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter/services.dart' show MethodChannel, MissingPluginException, PlatformException;
import 'package:flutter_test/flutter_test.dart';

import 'package:embla/tools/alarm_tool.dart';
import 'package:embla/tools/calendar_tool.dart';
import 'package:embla/tools/contact_match.dart';
import 'package:embla/tools/device_actions_channel.dart';
import 'package:embla/tools/directions_tool.dart';
import 'package:embla/tools/device_tools.dart';
import 'package:embla/tools/message_tool.dart';
import 'package:embla/tools/reminder_tool.dart';
import 'package:embla/tools/shopping_tool.dart';
import 'package:embla/tools/tool.dart';
import 'package:embla/tools/tool_args.dart';

// Fakes

class FakeCalendar {
  final List<Event> events = <Event>[];
  bool result = true;

  Future<bool> add(Event event) async {
    events.add(event);
    return result;
  }

  Event get last => events.last;
}

class FakeIntents {
  final List<AndroidIntent> launched = <AndroidIntent>[];

  Future<void> launch(AndroidIntent intent) async {
    launched.add(intent);
  }

  AndroidIntent get last => launched.last;
}

class FakeUriLauncher {
  final List<Uri> launched = <Uri>[];
  bool result = true;

  Future<bool> launch(Uri uri) async {
    launched.add(uri);
    return result;
  }

  Uri get last => launched.last;
}

class FakeDeviceActions implements DeviceActions {
  final List<(String, Map<String, dynamic>)> calls = <(String, Map<String, dynamic>)>[];

  /// When set, every call throws this instead of recording.
  DeviceActionsException? error;

  void _maybeThrow() {
    final DeviceActionsException? e = error;
    if (e != null) {
      throw e;
    }
  }

  @override
  Future<void> addCalendarEvent({
    required String title,
    required DateTime start,
    required DateTime end,
    String? notes,
    String? location,
  }) async {
    _maybeThrow();
    calls.add(('addCalendarEvent', <String, dynamic>{
      'title': title,
      'start': start,
      'end': end,
      'notes': notes,
      'location': location,
    }));
  }

  @override
  Future<int> addShopping({required List<String> items, required String list}) async {
    _maybeThrow();
    calls.add(('addShopping', <String, dynamic>{'items': items, 'list': list}));
    return items.length;
  }

  /// Pending alarms returned by [listAlarms].
  List<Map<String, dynamic>> pending = <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> listAlarms() async {
    _maybeThrow();
    calls.add(('listAlarms', <String, dynamic>{}));
    return pending;
  }

  @override
  Future<List<String>> cancelAlarms({String? id}) async {
    _maybeThrow();
    calls.add(('cancelAlarms', <String, dynamic>{'id': id}));
    final List<Map<String, dynamic>> hit =
        id == null ? pending : pending.where((a) => a['id'] == id).toList();
    pending = pending.where((a) => !hit.contains(a)).toList();
    return hit.map((a) => a['id'].toString()).toList();
  }

  @override
  Future<void> addReminder({required String title, DateTime? due}) async {
    _maybeThrow();
    calls.add(('addReminder', <String, dynamic>{'title': title, 'due': due}));
  }

  @override
  Future<void> setTimer({required int seconds, String? title}) async {
    _maybeThrow();
    calls.add(('setTimer', <String, dynamic>{'seconds': seconds, 'title': title}));
  }

  @override
  Future<void> setAlarm({required DateTime start, String? title}) async {
    _maybeThrow();
    calls.add(('setAlarm', <String, dynamic>{'start': start, 'title': title}));
  }

  String get lastMethod => calls.last.$1;
  Map<String, dynamic> get lastArgs => calls.last.$2;
}

final ToolContext ctx = ToolContext(now: DateTime(2026, 9, 3, 8, 30));

void main() {
  group('strict schemas', () {
    final List<Tool> allTools = <Tool>[
      ...buildDeviceTools(platform: TargetPlatform.iOS),
      ...buildDeviceTools(platform: TargetPlatform.android),
    ];

    test('both platforms get the action tools; only iOS can read alarms back', () {
      final Set<String> ios =
          buildDeviceTools(platform: TargetPlatform.iOS).map((Tool t) => t.name).toSet();
      final Set<String> android =
          buildDeviceTools(platform: TargetPlatform.android).map((Tool t) => t.name).toSet();
      const Set<String> shared = <String>{
        'add_calendar_event',
        'add_reminder',
        'set_timer',
        'set_alarm',
        'draft_message',
        'get_directions',
      };
      expect(android, shared);
      // AlarmKit owns the alarms it schedules, so they can be listed and
      // cancelled. Android hands them to the clock app via an intent, which is
      // fire-and-forget -- offering the tools there would promise more than the
      // platform can do.
      // add_shopping writes to a Reminders list, which Android has no
      // equivalent of.
      expect(ios, shared.union(<String>{'add_shopping', 'list_alarms', 'cancel_alarms'}));
    });

    test('set_alarm hands a time of day to a waiting shortcut', () async {
      final FakeDeviceActions actions = FakeDeviceActions();
      Map<String, dynamic>? handed;
      final ToolResult res = await SetAlarmTool(
        actions: actions,
        useNativeAlarms: true,
        handOff: (Map<String, dynamic> r) {
          handed = r;
          return true;
        },
      ).call(<String, dynamic>{'time': '7:30', 'title': null, 'date': null}, ctx);
      expect(handed, {'action': 'set_alarm', 'time': '07:30', 'title': kDefaultAlarmTitle});
      expect(actions.calls, isEmpty);
      expect(res.endsTurn, isTrue);
    });

    test('list_alarms reports what is pending', () async {
      final FakeDeviceActions actions = FakeDeviceActions()
        ..pending = [
          <String, dynamic>{'id': 'a1', 'kind': 'timer', 'title': 'Teljari'},
          <String, dynamic>{'id': 'a2', 'kind': 'alarm', 'title': 'Vekjari'},
        ];
      final ToolResult res = await ListAlarmsTool(actions: actions).call(const {}, ctx);
      expect(res.ok, isTrue);
      expect(res.data['count'], 2);
      expect((res.data['alarms'] as List).first['id'], 'a1');
    });

    test('cancel_alarms cancels one by id, or all without one', () async {
      final FakeDeviceActions actions = FakeDeviceActions()
        ..pending = [
          <String, dynamic>{'id': 'a1', 'kind': 'timer'},
          <String, dynamic>{'id': 'a2', 'kind': 'alarm'},
        ];
      final CancelAlarmsTool tool = CancelAlarmsTool(actions: actions);

      final ToolResult one = await tool.call(<String, dynamic>{'id': 'a1'}, ctx);
      expect(one.data['cancelled'], 1);
      expect(one.data['ids'], <String>['a1']);

      final ToolResult rest = await tool.call(<String, dynamic>{'id': null}, ctx);
      expect(rest.data['cancelled'], 1);
      expect(actions.pending, isEmpty);
    });

    test('cancel_alarms says so when there is nothing to cancel', () async {
      final ToolResult res =
          await CancelAlarmsTool(actions: FakeDeviceActions()).call(<String, dynamic>{'id': null}, ctx);
      expect(res.ok, isTrue);
      expect(res.data['cancelled'], 0);
      expect(res.data['summary'], contains('Enginn virkur'));
    });

    test('draft_message resolves a declined recipient name to a number', () async {
      final List<Uri> opened = <Uri>[];
      final tool = DraftMessageTool(
        isIOS: true,
        launchUri: (Uri u) async {
          opened.add(u);
          return true;
        },
        lookupContacts: () async => const [
          ContactCandidate(displayName: 'Kári Steinn', phoneNumbers: ['5551234']),
          ContactCandidate(displayName: 'Jón Jónsson', phoneNumbers: ['5559999']),
        ],
      );

      final ToolResult res = await tool.call(<String, dynamic>{
        'recipient_name': 'Kára Steini',
        'phone_number': null,
        'body': 'ég kem heim eftir hálftíma',
      }, ctx);

      expect(res.ok, isTrue);
      expect(opened.single.toString(), contains('5551234'));
      expect(res.speech, contains('Kári Steinn'));
    });

    test('draft_message hands the message to a waiting shortcut instead of the composer', () async {
      final List<Uri> opened = <Uri>[];
      Map<String, dynamic>? handed;
      final tool = DraftMessageTool(
        isIOS: true,
        launchUri: (Uri u) async {
          opened.add(u);
          return true;
        },
        lookupContacts: () async => const [
          ContactCandidate(displayName: 'Kári Steinn', phoneNumbers: ['5551234']),
        ],
        handOff: (Map<String, dynamic> result) {
          handed = result;
          return true;
        },
      );

      final ToolResult res = await tool.call(<String, dynamic>{
        'recipient_name': 'Kára Steini',
        'phone_number': null,
        'body': 'ég kem heim eftir hálftíma',
      }, ctx);

      expect(res.ok, isTrue);
      expect(res.endsTurn, isTrue);
      expect(res.speech, contains('sendi'));
      // The shortcut's Find Contacts wants the nominative, and the number
      // lets it skip the lookup altogether.
      expect(handed, {
        'action': 'send_message',
        'recipient_name': 'Kári Steinn',
        'phone_number': '5551234',
        'body': 'ég kem heim eftir hálftíma',
      });
      expect(opened, isEmpty);
    });

    test('draft_message with no recipient at all falls back to the composer even under a shortcut', () async {
      final List<Uri> opened = <Uri>[];
      final tool = DraftMessageTool(
        isIOS: true,
        launchUri: (Uri u) async {
          opened.add(u);
          return true;
        },
        handOff: (Map<String, dynamic> result) => true,
      );
      await tool.call(<String, dynamic>{'recipient_name': null, 'phone_number': null, 'body': 'hæ'}, ctx);
      // A shortcut cannot send to nobody, so the user picks the recipient.
      expect(opened, hasLength(1));
    });

    test('draft_message asks which contact rather than guessing', () async {
      final List<Uri> opened = <Uri>[];
      final tool = DraftMessageTool(
        isIOS: true,
        launchUri: (Uri u) async {
          opened.add(u);
          return true;
        },
        lookupContacts: () async => const [
          ContactCandidate(displayName: 'Jón Jónsson', phoneNumbers: ['111']),
          ContactCandidate(displayName: 'Jón Sigurðsson', phoneNumbers: ['222']),
        ],
      );

      final ToolResult res = await tool.call(<String, dynamic>{
        'recipient_name': 'Jóni',
        'phone_number': null,
        'body': 'hæ',
      }, ctx);

      expect(res.data['ambiguous'], isTrue);
      expect(res.data['candidates'], hasLength(2));
      // The composer must not open, or the user could send to the wrong person.
      expect(opened, isEmpty);
      expect(res.endsTurn, isFalse);
    });

    test('an explicit phone number skips contact lookup entirely', () async {
      var looked = false;
      final tool = DraftMessageTool(
        isIOS: true,
        launchUri: (Uri u) async => true,
        lookupContacts: () async {
          looked = true;
          return const [];
        },
      );
      await tool.call(<String, dynamic>{
        'recipient_name': 'Kára',
        'phone_number': '555-1234',
        'body': 'hæ',
      }, ctx);
      expect(looked, isFalse);
    });

    test('no matching contact still opens the composer', () async {
      final List<Uri> opened = <Uri>[];
      final tool = DraftMessageTool(
        isIOS: true,
        launchUri: (Uri u) async {
          opened.add(u);
          return true;
        },
        lookupContacts: () async => const [ContactCandidate(displayName: 'Jón Jónsson')],
      );
      final ToolResult res = await tool.call(<String, dynamic>{
        'recipient_name': 'Kára',
        'phone_number': null,
        'body': 'hæ',
      }, ctx);
      // Degrades to today's behaviour: the user picks the recipient.
      expect(res.ok, isTrue);
      expect(opened, hasLength(1));
    });

    test('get_directions picks the map URL its platform can actually navigate', () async {
      final List<Uri> opened = <Uri>[];
      Future<bool> launch(Uri u) async {
        opened.add(u);
        return true;
      }

      final ToolResult apple = await GetDirectionsTool(
              launchUri: launch, preferGoogleMaps: () => false)
          .call(<String, dynamic>{'destination': 'Harpa'}, ctx);
      expect(apple.ok, isTrue);
      expect(apple.endsTurn, isTrue);
      expect(opened.last.toString(), 'maps://?daddr=Harpa&dirflg=d');

      await GetDirectionsTool(launchUri: launch, preferGoogleMaps: () => true)
          .call(<String, dynamic>{'destination': 'Kringlan'}, ctx);
      // dir_action=navigate is the reason Google is offered at all: the Apple
      // URL cannot start turn-by-turn on its own.
      expect(opened.last.toString(), contains('dir_action=navigate'));
      expect(opened.last.toString(), contains('destination=Kringlan'));
    });

    test('add_shopping batches items onto the configured list', () async {
      final FakeDeviceActions actions = FakeDeviceActions();
      final ToolResult res = await AddShoppingTool(
              actions: actions, listName: () => 'Innkaupalisti')
          .call(<String, dynamic>{
        'items': <dynamic>['mjólk', '  egg  ', '', null]
      }, ctx);
      expect(res.ok, isTrue);
      expect(res.data['count'], 2);
      expect(res.data['list'], 'Innkaupalisti');
      // Blank and null entries are dropped rather than written as empty items.
      expect(actions.calls.single.$2['items'], <String>['mjólk', 'egg']);
    });

    test('add_shopping fails cleanly with nothing to add', () async {
      final ToolResult res = await AddShoppingTool(actions: FakeDeviceActions())
          .call(<String, dynamic>{'items': <dynamic>[]}, ctx);
      expect(res.ok, isFalse);
    });

    test('no device tools on unsupported platforms', () {
      expect(buildDeviceTools(platform: TargetPlatform.macOS), isEmpty);
      expect(buildDeviceTools(platform: TargetPlatform.linux), isEmpty);
    });

    test('schemas are strict', () {
      expect(allTools, isNotEmpty);
      for (final Tool tool in allTools) {
        final Map<String, dynamic> schema = tool.parameters;
        expect(schema['type'], 'object', reason: tool.name);
        expect(schema['additionalProperties'], false, reason: tool.name);
        final Map<String, dynamic> props = schema['properties'] as Map<String, dynamic>;
        final List<dynamic> required = schema['required'] as List<dynamic>;
        expect(required.toSet(), props.keys.toSet(),
            reason: 'every property of ${tool.name} must be required');
        for (final MapEntry<String, dynamic> e in props.entries) {
          final Map<String, dynamic> prop = e.value as Map<String, dynamic>;
          expect(prop['description'], isA<String>(), reason: '${tool.name}.${e.key}');
          // Optional arguments must be nullable rather than absent.
          final dynamic type = prop['type'];
          expect(type is String || (type is List && type.contains('null')), isTrue,
              reason: '${tool.name}.${e.key} has type $type');
        }
      }
    });

    test('descriptions and labels are non-empty', () {
      for (final Tool tool in allTools) {
        expect(tool.description.length, greaterThan(20), reason: tool.name);
        expect(tool.activityLabel, isNotNull, reason: tool.name);
        expect(tool.spec.name, tool.name);
      }
    });
  });

  group('parseLocalDateTime', () {
    test('local ISO 8601 without offset', () {
      expect(parseLocalDateTime('2026-08-24T14:00:00'), DateTime(2026, 8, 24, 14));
    });

    test('missing seconds and space separator', () {
      expect(parseLocalDateTime('2026-08-24T14:05'), DateTime(2026, 8, 24, 14, 5));
      expect(parseLocalDateTime(' 2026-08-24 14:05:06 '), DateTime(2026, 8, 24, 14, 5, 6));
    });

    test('date only means midnight', () {
      expect(parseLocalDateTime('2026-08-24'), DateTime(2026, 8, 24));
    });

    test('fractional seconds', () {
      expect(parseLocalDateTime('2026-08-24T14:00:00.500'), DateTime(2026, 8, 24, 14));
    });

    test('offsets are converted to local time', () {
      final DateTime? d = parseLocalDateTime('2026-08-24T14:00:00Z');
      expect(d, isNotNull);
      expect(d!.isUtc, isFalse);
      expect(d.toUtc(), DateTime.utc(2026, 8, 24, 14));
      expect(parseLocalDateTime('2026-08-24T16:00:00+02:00')!.toUtc(), DateTime.utc(2026, 8, 24, 14));
    });

    test('rejects junk', () {
      expect(parseLocalDateTime(null), isNull);
      expect(parseLocalDateTime(''), isNull);
      expect(parseLocalDateTime('á morgun'), isNull);
      expect(parseLocalDateTime('2026-13-01T00:00:00'), isNull);
      expect(parseLocalDateTime('2026-08-24T25:00:00'), isNull);
    });
  });

  group('other parsing helpers', () {
    test('parseClockTime', () {
      expect(parseClockTime('07:30'), (hour: 7, minute: 30));
      expect(parseClockTime('7:30'), (hour: 7, minute: 30));
      expect(parseClockTime('23:59:00'), (hour: 23, minute: 59));
      expect(parseClockTime('24:00'), isNull);
      expect(parseClockTime('sjö'), isNull);
      expect(parseClockTime(null), isNull);
    });

    test('parseInt coerces JSON numbers and strings', () {
      expect(parseInt(300), 300);
      expect(parseInt(300.0), 300);
      expect(parseInt('300'), 300);
      expect(parseInt('300.4'), 300);
      expect(parseInt(null), isNull);
      expect(parseInt('fimm'), isNull);
    });

    test('optionalString trims and nulls out blanks', () {
      expect(optionalString('  Fundur '), 'Fundur');
      expect(optionalString(''), isNull);
      expect(optionalString('   '), isNull);
      expect(optionalString(null), isNull);
    });

    test('Icelandic formatting', () {
      expect(formatIcelandicDateTime(DateTime(2026, 9, 3, 9)), '3. september 09:00');
      expect(
          formatIcelandicRange(DateTime(2026, 9, 3, 9), DateTime(2026, 9, 3, 10)),
          '3. september 09:00–10:00');
      expect(formatIcelandicRange(DateTime(2026, 9, 3, 23), DateTime(2026, 9, 4)),
          '3. september 23:00 – 4. september 00:00');
      expect(formatIcelandicDuration(300), '5 mínútur');
      expect(formatIcelandicDuration(60), '1 mínúta');
      expect(formatIcelandicDuration(30), '30 sekúndur');
      expect(formatIcelandicDuration(5400), '1 klukkustund og 30 mínútur');
      expect(formatIcelandicDuration(90), '1 mínúta og 30 sekúndur');
      expect(formatLocalISO8601(DateTime(2026, 9, 3, 9, 5)), '2026-09-03T09:05:00');
    });
  });

  group('add_calendar_event', () {
    test('fills in the event and defaults the end time', () async {
      final FakeCalendar cal = FakeCalendar();
      final AddCalendarEventTool tool = AddCalendarEventTool(addToCalendar: cal.add);
      final ToolResult res = await tool.call(<String, dynamic>{
        'title': 'Fundur',
        'start': '2026-09-03T09:00:00',
        'end': null,
        'notes': null,
        'location': 'Kaffi Vest',
      }, ctx);

      expect(res.ok, isTrue);
      expect(res.endsTurn, isTrue);
      expect(res.data['saved'], isTrue);
      expect(res.data['summary'], 'Viðburður „Fundur“ 3. september 09:00–10:00 vistaður í dagatali');
      expect(cal.last.title, 'Fundur');
      expect(cal.last.startDate, DateTime(2026, 9, 3, 9));
      expect(cal.last.endDate, DateTime(2026, 9, 3, 10));
      expect(cal.last.location, 'Kaffi Vest');
      expect(cal.last.description, isNull);
    });

    test('honours an explicit end time and notes', () async {
      final FakeCalendar cal = FakeCalendar();
      final ToolResult res = await AddCalendarEventTool(addToCalendar: cal.add).call(
        <String, dynamic>{
          'title': 'Tannlæknir',
          'start': '2026-09-04T14:00:00',
          'end': '2026-09-04T14:30:00',
          'notes': 'Taka röntgen',
          'location': null,
        },
        ctx,
      );
      expect(res.ok, isTrue);
      expect(cal.last.endDate, DateTime(2026, 9, 4, 14, 30));
      expect(cal.last.description, 'Taka röntgen');
    });

    test('an end time before the start falls back to one hour', () async {
      final FakeCalendar cal = FakeCalendar();
      await AddCalendarEventTool(addToCalendar: cal.add).call(<String, dynamic>{
        'title': 'Fundur',
        'start': '2026-09-03T09:00:00',
        'end': '2026-09-03T08:00:00',
        'notes': null,
        'location': null,
      }, ctx);
      expect(cal.last.endDate, DateTime(2026, 9, 3, 10));
    });

    test('missing title or bad start fails without touching the calendar', () async {
      final FakeCalendar cal = FakeCalendar();
      final AddCalendarEventTool tool = AddCalendarEventTool(addToCalendar: cal.add);
      final ToolResult noTitle = await tool.call(
          <String, dynamic>{'title': null, 'start': '2026-09-03T09:00:00'}, ctx);
      expect(noTitle.ok, isFalse);
      final ToolResult badStart =
          await tool.call(<String, dynamic>{'title': 'Fundur', 'start': 'á morgun'}, ctx);
      expect(badStart.ok, isFalse);
      expect(badStart.data['error'], contains('start'));
      expect(cal.events, isEmpty);
    });

    test('iOS writes the event silently through EventKit, no editor', () async {
      final FakeDeviceActions actions = FakeDeviceActions();
      final FakeCalendar cal = FakeCalendar();
      final ToolResult res = await AddCalendarEventTool(
        addToCalendar: cal.add,
        actions: actions,
        useNativeCalendar: true,
      ).call(<String, dynamic>{
        'title': 'Fundur',
        'start': '2026-09-03T09:00:00',
        'end': null,
        'notes': null,
        'location': 'Kaffi Vest',
      }, ctx);

      expect(res.ok, isTrue);
      expect(res.data['saved'], isTrue);
      // The editor is never opened on this path.
      expect(cal.events, isEmpty);
      expect(actions.calls.single.$1, 'addCalendarEvent');
      expect(actions.calls.single.$2['end'], DateTime(2026, 9, 3, 10));
      expect(actions.calls.single.$2['location'], 'Kaffi Vest');
      // Nothing was handed off, so the model phrases the confirmation.
      expect(res.endsTurn, isFalse);
      expect(res.speech, isNull);
    });

    test('a permission failure on the silent path is reported, not swallowed', () async {
      final FakeDeviceActions actions = FakeDeviceActions()
        ..error = const DeviceActionsException('permission_denied', 'Aðgangur ekki leyfður');
      final ToolResult res = await AddCalendarEventTool(
        addToCalendar: FakeCalendar().add,
        actions: actions,
        useNativeCalendar: true,
      ).call(<String, dynamic>{'title': 'Fundur', 'start': '2026-09-03T09:00:00'}, ctx);
      expect(res.ok, isFalse);
    });

    test('a dismissed calendar sheet is reported as not saved, not as an error', () async {
      // add_2_calendar returns false for .canceled/.deleted as well as for a
      // sheet that never opened. Treating that as an error made the model fall
      // back to "Ég veit það ekki" when the user simply declined to save.
      final FakeCalendar cal = FakeCalendar()..result = false;
      final ToolResult res = await AddCalendarEventTool(addToCalendar: cal.add).call(
          <String, dynamic>{'title': 'Fundur', 'start': '2026-09-03T09:00:00'}, ctx);
      expect(res.ok, isTrue);
      expect(res.data['saved'], isFalse);
      expect(res.data['summary'], contains('án þess að vista'));
    });
  });

  group('add_reminder', () {
    AddReminderTool iosTool(FakeDeviceActions actions, FakeCalendar cal) => AddReminderTool(
        actions: actions, addToCalendar: cal.add, useNativeReminders: true);
    AddReminderTool androidTool(FakeDeviceActions actions, FakeCalendar cal) => AddReminderTool(
        actions: actions, addToCalendar: cal.add, useNativeReminders: false);

    test('iOS goes through the channel, with and without a due date', () async {
      final FakeDeviceActions actions = FakeDeviceActions();
      final FakeCalendar cal = FakeCalendar();
      final ToolResult timed = await iosTool(actions, cal).call(
          <String, dynamic>{'title': 'Kaupa mjólk', 'due': '2026-09-03T17:00:00'}, ctx);
      expect(timed.ok, isTrue);
      expect(timed.endsTurn, isFalse);
      expect(actions.lastMethod, 'addReminder');
      expect(actions.lastArgs['title'], 'Kaupa mjólk');
      expect(actions.lastArgs['due'], DateTime(2026, 9, 3, 17));
      expect(timed.data['summary'], 'Áminning „Kaupa mjólk“ 3. september 17:00 búin til');

      final ToolResult untimed = await iosTool(actions, cal)
          .call(<String, dynamic>{'title': 'Kaupa mjólk', 'due': null}, ctx);
      expect(untimed.ok, isTrue);
      expect(actions.lastArgs['due'], isNull);
      expect(untimed.data['summary'], 'Áminning „Kaupa mjólk“ búin til');
      expect(cal.events, isEmpty);
    });

    test('iOS channel errors surface as failures', () async {
      final FakeDeviceActions actions = FakeDeviceActions()
        ..error = const DeviceActionsException('permission_denied', 'Aðgangur ekki leyfður');
      final ToolResult res = await iosTool(actions, FakeCalendar())
          .call(<String, dynamic>{'title': 'Kaupa mjólk', 'due': null}, ctx);
      expect(res.ok, isFalse);
      expect(res.data['error'], 'Aðgangur ekki leyfður');
    });

    test('Android falls back to a calendar event', () async {
      final FakeDeviceActions actions = FakeDeviceActions();
      final FakeCalendar cal = FakeCalendar();
      final ToolResult res = await androidTool(actions, cal).call(
          <String, dynamic>{'title': 'Kaupa mjólk', 'due': '2026-09-03T17:00:00'}, ctx);
      expect(res.ok, isTrue);
      expect(res.endsTurn, isTrue);
      expect(actions.calls, isEmpty);
      expect(cal.last.title, 'Kaupa mjólk');
      expect(cal.last.startDate, DateTime(2026, 9, 3, 17));
      expect(cal.last.endDate, DateTime(2026, 9, 3, 17, 30));
      expect(res.data['saved'], isTrue);
      expect(res.data['summary'], 'Áminning „Kaupa mjólk“ 3. september 17:00 vistuð í dagatali');
      expect(res.speech, 'Áminningin „Kaupa mjólk“ er komin í dagatalið.');
    });

    test('Android without a due date fails', () async {
      final FakeCalendar cal = FakeCalendar();
      final ToolResult res = await androidTool(FakeDeviceActions(), cal)
          .call(<String, dynamic>{'title': 'Kaupa mjólk', 'due': null}, ctx);
      expect(res.ok, isFalse);
      expect(cal.events, isEmpty);
    });

    test('a malformed due date fails rather than being dropped', () async {
      final FakeDeviceActions actions = FakeDeviceActions();
      final ToolResult res = await iosTool(actions, FakeCalendar())
          .call(<String, dynamic>{'title': 'Kaupa mjólk', 'due': 'seinna í dag'}, ctx);
      expect(res.ok, isFalse);
      expect(actions.calls, isEmpty);
    });
  });

  group('set_timer', () {
    test('Android fires SET_TIMER with the documented extras', () async {
      final FakeIntents intents = FakeIntents();
      final ToolResult res = await SetTimerTool(
        actions: FakeDeviceActions(),
        useNativeAlarms: false,
        launchIntent: intents.launch,
      ).call(<String, dynamic>{'seconds': 300, 'title': null}, ctx);

      expect(res.ok, isTrue);
      expect(res.endsTurn, isFalse);
      expect(res.data['summary'], 'Teljari ræstur: 5 mínútur');
      expect(intents.last.action, 'android.intent.action.SET_TIMER');
      expect(intents.last.arguments, <String, dynamic>{
        'android.intent.extra.alarm.LENGTH': 300,
        'android.intent.extra.alarm.MESSAGE': 'Teljari',
        'android.intent.extra.alarm.SKIP_UI': true,
      });
    });

    test('a title is passed through as the intent message', () async {
      final FakeIntents intents = FakeIntents();
      await SetTimerTool(
        actions: FakeDeviceActions(),
        useNativeAlarms: false,
        launchIntent: intents.launch,
      ).call(<String, dynamic>{'seconds': '90', 'title': 'pasta'}, ctx);
      expect(intents.last.arguments!['android.intent.extra.alarm.MESSAGE'], 'pasta');
      expect(intents.last.arguments!['android.intent.extra.alarm.LENGTH'], 90);
    });

    test('iOS goes through the channel', () async {
      final FakeDeviceActions actions = FakeDeviceActions();
      final FakeIntents intents = FakeIntents();
      final ToolResult res = await SetTimerTool(
        actions: actions,
        useNativeAlarms: true,
        launchIntent: intents.launch,
      ).call(<String, dynamic>{'seconds': 300, 'title': 'pasta'}, ctx);

      expect(res.ok, isTrue);
      expect(intents.launched, isEmpty);
      expect(actions.lastMethod, 'setTimer');
      expect(actions.lastArgs, <String, dynamic>{'seconds': 300, 'title': 'pasta'});
    });

    test('iOS below 26 reports the AlarmKit requirement', () async {
      final FakeDeviceActions actions = FakeDeviceActions()
        ..error = const DeviceActionsException('unsupported', 'AlarmKit requires iOS 26');
      final ToolResult res = await SetTimerTool(actions: actions, useNativeAlarms: true)
          .call(<String, dynamic>{'seconds': 300, 'title': null}, ctx);
      expect(res.ok, isFalse);
      expect(res.data['error'], 'Vekjarar og teljarar krefjast iOS 26');
    });

    test('bad durations fail', () async {
      final FakeIntents intents = FakeIntents();
      final SetTimerTool tool = SetTimerTool(
        actions: FakeDeviceActions(),
        useNativeAlarms: false,
        launchIntent: intents.launch,
      );
      expect((await tool.call(<String, dynamic>{'seconds': null}, ctx)).ok, isFalse);
      expect((await tool.call(<String, dynamic>{'seconds': 0}, ctx)).ok, isFalse);
      expect((await tool.call(<String, dynamic>{'seconds': -5}, ctx)).ok, isFalse);
      expect((await tool.call(<String, dynamic>{'seconds': 200000}, ctx)).ok, isFalse);
      expect(intents.launched, isEmpty);
    });
  });

  group('set_alarm', () {
    test('Android fires SET_ALARM with hour and minutes', () async {
      final FakeIntents intents = FakeIntents();
      final ToolResult res = await SetAlarmTool(
        actions: FakeDeviceActions(),
        useNativeAlarms: false,
        launchIntent: intents.launch,
      ).call(<String, dynamic>{'time': '07:30', 'title': null, 'date': null}, ctx);

      expect(res.ok, isTrue);
      expect(intents.last.action, 'android.intent.action.SET_ALARM');
      expect(intents.last.arguments, <String, dynamic>{
        'android.intent.extra.alarm.HOUR': 7,
        'android.intent.extra.alarm.MINUTES': 30,
        'android.intent.extra.alarm.MESSAGE': 'Vekjari',
        'android.intent.extra.alarm.SKIP_UI': true,
      });
      // 07:30 has already passed at 08:30, so it is tomorrow.
      expect(res.data['summary'], 'Vekjari settur á 4. september 07:30');
    });

    test('a time later today stays today', () async {
      final FakeDeviceActions actions = FakeDeviceActions();
      final ToolResult res = await SetAlarmTool(actions: actions, useNativeAlarms: true)
          .call(<String, dynamic>{'time': '17:00', 'title': 'lúr', 'date': null}, ctx);
      expect(res.ok, isTrue);
      expect(actions.lastMethod, 'setAlarm');
      expect(actions.lastArgs['start'], DateTime(2026, 9, 3, 17));
      expect(actions.lastArgs['title'], 'lúr');
      expect(res.data['summary'], 'Vekjari settur á 3. september 17:00');
    });

    test('an explicit date is used verbatim', () async {
      final FakeDeviceActions actions = FakeDeviceActions();
      final ToolResult res = await SetAlarmTool(actions: actions, useNativeAlarms: true)
          .call(<String, dynamic>{'time': '07:30', 'title': null, 'date': '2026-12-24'}, ctx);
      expect(res.ok, isTrue);
      expect(actions.lastArgs['start'], DateTime(2026, 12, 24, 7, 30));
      expect(res.data['summary'], 'Vekjari settur á 24. desember 07:30');
    });

    test('iOS below 26 reports the AlarmKit requirement', () async {
      final FakeDeviceActions actions = FakeDeviceActions()
        ..error = const DeviceActionsException('unsupported', 'AlarmKit requires iOS 26');
      final ToolResult res = await SetAlarmTool(actions: actions, useNativeAlarms: true)
          .call(<String, dynamic>{'time': '07:30'}, ctx);
      expect(res.ok, isFalse);
      expect(res.data['error'], 'Vekjarar og teljarar krefjast iOS 26');
    });

    test('bad times and dates fail', () async {
      final FakeIntents intents = FakeIntents();
      final SetAlarmTool tool = SetAlarmTool(
        actions: FakeDeviceActions(),
        useNativeAlarms: false,
        launchIntent: intents.launch,
      );
      expect((await tool.call(<String, dynamic>{'time': null}, ctx)).ok, isFalse);
      expect((await tool.call(<String, dynamic>{'time': 'sjö'}, ctx)).ok, isFalse);
      expect(
          (await tool.call(<String, dynamic>{'time': '07:30', 'date': 'aðfangadag'}, ctx)).ok,
          isFalse);
      expect(intents.launched, isEmpty);
    });
  });

  group('draft_message', () {
    test('Android uses a query separator, iOS an ampersand', () async {
      final FakeUriLauncher android = FakeUriLauncher();
      await DraftMessageTool(isIOS: false, launchUri: android.launch).call(<String, dynamic>{
        'recipient_name': null,
        'phone_number': '588 4747',
        'body': 'Ég kem heim eftir hálftíma',
      }, ctx);
      expect(android.last.toString(), 'sms:5884747?body=%C3%89g%20kem%20heim%20eftir%20h%C3%A1lft%C3%ADma');

      final FakeUriLauncher ios = FakeUriLauncher();
      await DraftMessageTool(isIOS: true, launchUri: ios.launch).call(<String, dynamic>{
        'recipient_name': null,
        'phone_number': '+354 588 4747',
        'body': 'Halló',
      }, ctx);
      expect(ios.last.toString(), 'sms:+3545884747&body=Hall%C3%B3');
    });

    test('a name without a number opens an empty recipient and says so', () async {
      final FakeUriLauncher launcher = FakeUriLauncher();
      final ToolResult res =
          await DraftMessageTool(isIOS: true, launchUri: launcher.launch).call(<String, dynamic>{
        'recipient_name': 'María',
        'phone_number': null,
        'body': 'Ég kem heim eftir hálftíma',
      }, ctx);

      expect(res.ok, isTrue);
      expect(res.endsTurn, isTrue);
      expect(launcher.last.scheme, 'sms');
      expect(launcher.last.toString(), startsWith('sms:&body='));
      expect(res.data['summary'], contains('María'));
      expect(res.data['summary'], startsWith('Skilaboð opnuð í skilaboðaforriti'));
    });

    test('no recipient at all', () async {
      final FakeUriLauncher launcher = FakeUriLauncher();
      final ToolResult res =
          await DraftMessageTool(isIOS: false, launchUri: launcher.launch).call(<String, dynamic>{
        'recipient_name': null,
        'phone_number': null,
        'body': 'Halló',
      }, ctx);
      expect(res.data['summary'], 'Skilaboð opnuð í skilaboðaforriti');
    });

    test('a number is echoed in the summary', () async {
      final FakeUriLauncher launcher = FakeUriLauncher();
      final ToolResult res =
          await DraftMessageTool(isIOS: false, launchUri: launcher.launch).call(<String, dynamic>{
        'recipient_name': 'María',
        'phone_number': '5884747',
        'body': 'Halló',
      }, ctx);
      expect(res.data['summary'], 'Skilaboð til 5884747 opnuð í skilaboðaforriti');
    });

    test('an empty body fails and nothing is launched', () async {
      final FakeUriLauncher launcher = FakeUriLauncher();
      final ToolResult res = await DraftMessageTool(isIOS: false, launchUri: launcher.launch)
          .call(<String, dynamic>{'recipient_name': 'María', 'phone_number': null, 'body': '  '}, ctx);
      expect(res.ok, isFalse);
      expect(launcher.launched, isEmpty);
    });

    test('a messaging app that will not open is reported as a failure', () async {
      final FakeUriLauncher launcher = FakeUriLauncher()..result = false;
      final ToolResult res = await DraftMessageTool(isIOS: false, launchUri: launcher.launch)
          .call(<String, dynamic>{'body': 'Halló'}, ctx);
      expect(res.ok, isFalse);
    });

    test('phone numbers are sanitized', () {
      expect(sanitizePhoneNumber('588-4747'), '5884747');
      expect(sanitizePhoneNumber('(354) 588 4747'), '3545884747');
      expect(sanitizePhoneNumber('+354 588 4747'), '+3545884747');
      expect(sanitizePhoneNumber('ekki númer'), isNull);
      expect(sanitizePhoneNumber(null), isNull);
    });
  });

  group('DeviceActionsChannel', () {
    test('serializes due dates and times as local ISO 8601', () async {
      final List<(String, Object?)> calls = <(String, Object?)>[];
      final DeviceActionsChannel channel =
          DeviceActionsChannel(channel: _RecordingChannel(calls));

      await channel.addReminder(title: 'Kaupa mjólk', due: DateTime(2026, 9, 3, 17));
      expect(calls.last.$1, 'addReminder');
      expect(calls.last.$2, <String, dynamic>{'title': 'Kaupa mjólk', 'due': '2026-09-03T17:00:00'});

      await channel.addReminder(title: 'Kaupa mjólk');
      expect(calls.last.$2, <String, dynamic>{'title': 'Kaupa mjólk', 'due': null});

      await channel.setTimer(seconds: 300, title: 'pasta');
      expect(calls.last.$1, 'setTimer');
      expect(calls.last.$2, <String, dynamic>{'seconds': 300, 'title': 'pasta'});

      await channel.setAlarm(start: DateTime(2026, 9, 4, 7, 30), title: null);
      expect(calls.last.$1, 'setAlarm');
      expect(calls.last.$2, <String, dynamic>{'start': '2026-09-04T07:30:00', 'title': null});
    });

    test('platform errors become DeviceActionsException', () async {
      final DeviceActionsChannel channel = DeviceActionsChannel(
          channel: _ThrowingChannel(PlatformException(code: 'unsupported', message: 'iOS 26')));
      await expectLater(
        channel.setTimer(seconds: 1),
        throwsA(isA<DeviceActionsException>()
            .having((DeviceActionsException e) => e.code, 'code', 'unsupported')
            .having((DeviceActionsException e) => e.isUnsupported, 'isUnsupported', isTrue)),
      );
    });

    test('a missing native side is unsupported too', () async {
      final DeviceActionsChannel channel =
          DeviceActionsChannel(channel: _ThrowingChannel(MissingPluginException('no channel')));
      await expectLater(
        channel.setTimer(seconds: 1),
        throwsA(isA<DeviceActionsException>()
            .having((DeviceActionsException e) => e.isUnsupported, 'isUnsupported', isTrue)),
      );
    });

    test('channel name matches the native handler', () {
      expect(kDeviceActionsChannelName, 'is.mideind.embla/actions');
    });
  });
}

// Method channel stand-ins. The Flutter test binding is not started, so the
// real message codec is never involved.

class _RecordingChannel extends MethodChannel {
  final List<(String, Object?)> calls;
  _RecordingChannel(this.calls) : super(kDeviceActionsChannelName);

  @override
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async {
    calls.add((method, arguments));
    return null;
  }
}

class _ThrowingChannel extends MethodChannel {
  final Object error;
  _ThrowingChannel(this.error) : super(kDeviceActionsChannelName);

  @override
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async {
    throw error;
  }
}

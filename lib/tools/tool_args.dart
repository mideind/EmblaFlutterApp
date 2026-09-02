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

// Tolerant argument parsing and Icelandic formatting helpers for tools.
//
// The model is instructed to send ISO 8601 local times without a timezone
// offset (e.g. 2026-08-24T14:00:00) but in practice it also emits offsets,
// space separators, missing seconds and date-only values, so parsing is
// deliberately forgiving.

// ISO 8601-ish date/time. Groups:
// 1 year, 2 month, 3 day, 4 hour, 5 minute, 6 second, 7 timezone offset.
final RegExp _isoDateTimeRe = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})'
    r'(?:[T ](\d{1,2}):(\d{2})(?::(\d{2}))?(?:\.\d+)?)?'
    r'([Zz]|[+-]\d{2}:?\d{2})?$');

// 24 hour clock time, e.g. 7:30 or 07:30 (seconds tolerated and ignored).
final RegExp _clockTimeRe = RegExp(r'^(\d{1,2})[:.](\d{2})(?::\d{2})?$');

/// Parses an ISO 8601 date/time into a local [DateTime].
///
/// Times without an offset are taken to be local wall-clock times. Times with
/// an offset (or a trailing `Z`) are converted to local time. Date-only values
/// yield midnight. Returns null when the string is missing or unparseable.
DateTime? parseLocalDateTime(String? raw) {
  if (raw == null) {
    return null;
  }
  final String s = raw.trim();
  if (s.isEmpty) {
    return null;
  }
  final RegExpMatch? m = _isoDateTimeRe.firstMatch(s);
  if (m == null) {
    return null;
  }
  final String? offset = m.group(7);
  if (offset != null && offset.isNotEmpty) {
    // An absolute instant. Let the SDK deal with the offset arithmetic.
    return DateTime.tryParse(s.replaceFirst(' ', 'T'))?.toLocal();
  }
  final int year = int.parse(m.group(1)!);
  final int month = int.parse(m.group(2)!);
  final int day = int.parse(m.group(3)!);
  final int hour = m.group(4) == null ? 0 : int.parse(m.group(4)!);
  final int minute = m.group(5) == null ? 0 : int.parse(m.group(5)!);
  final int second = m.group(6) == null ? 0 : int.parse(m.group(6)!);
  // Reject nonsense instead of letting DateTime silently roll it over.
  if (month < 1 || month > 12 || day < 1 || day > 31 || hour > 23 || minute > 59 || second > 59) {
    return null;
  }
  return DateTime(year, month, day, hour, minute, second);
}

/// Parses a 24 hour clock time such as `07:30`.
({int hour, int minute})? parseClockTime(String? raw) {
  if (raw == null) {
    return null;
  }
  final RegExpMatch? m = _clockTimeRe.firstMatch(raw.trim());
  if (m == null) {
    return null;
  }
  final int hour = int.parse(m.group(1)!);
  final int minute = int.parse(m.group(2)!);
  if (hour > 23 || minute > 59) {
    return null;
  }
  return (hour: hour, minute: minute);
}

/// Coerces a JSON value to an int. Accepts ints, doubles and numeric strings.
int? parseInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.isFinite ? value.round() : null;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    final String s = value.trim();
    return int.tryParse(s) ?? double.tryParse(s)?.round();
  }
  return null;
}

/// Coerces a JSON value to a non-empty trimmed string, else null.
///
/// Strict schemas force the model to send every property, so optional
/// arguments arrive as `null` or, occasionally, as an empty string.
String? optionalString(dynamic value) {
  if (value == null) {
    return null;
  }
  final String s = value is String ? value.trim() : value.toString().trim();
  return s.isEmpty ? null : s;
}

/// Builds a strict JSON schema object: no extra properties, everything
/// required. Optional arguments must therefore be declared nullable, see
/// [optionalStringProperty] and [optionalIntegerProperty].
Map<String, dynamic> strictObjectSchema(Map<String, Map<String, dynamic>> properties) {
  return <String, dynamic>{
    'type': 'object',
    'additionalProperties': false,
    'properties': properties,
    'required': properties.keys.toList(growable: false),
  };
}

Map<String, dynamic> stringProperty(String description) {
  return <String, dynamic>{'type': 'string', 'description': description};
}

Map<String, dynamic> optionalStringProperty(String description) {
  return <String, dynamic>{
    'type': <String>['string', 'null'],
    'description': description,
  };
}

Map<String, dynamic> integerProperty(String description) {
  return <String, dynamic>{'type': 'integer', 'description': description};
}

Map<String, dynamic> optionalIntegerProperty(String description) {
  return <String, dynamic>{
    'type': <String>['integer', 'null'],
    'description': description,
  };
}

// Icelandic formatting

const List<String> kIcelandicMonths = <String>[
  'janúar',
  'febrúar',
  'mars',
  'apríl',
  'maí',
  'júní',
  'júlí',
  'ágúst',
  'september',
  'október',
  'nóvember',
  'desember',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// e.g. `3. september`
String formatIcelandicDate(DateTime d) => '${d.day}. ${kIcelandicMonths[d.month - 1]}';

/// e.g. `09:00`
String formatIcelandicTime(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

/// e.g. `3. september 09:00`
String formatIcelandicDateTime(DateTime d) => '${formatIcelandicDate(d)} ${formatIcelandicTime(d)}';

/// e.g. `3. september 09:00–10:00`, or the full date twice when the event
/// spans midnight.
String formatIcelandicRange(DateTime start, DateTime end) {
  final bool sameDay = start.year == end.year && start.month == end.month && start.day == end.day;
  if (sameDay) {
    return '${formatIcelandicDateTime(start)}–${formatIcelandicTime(end)}';
  }
  return '${formatIcelandicDateTime(start)} – ${formatIcelandicDateTime(end)}';
}

// Icelandic uses the singular after numbers ending in 1, except 11.
bool _singular(int n) => n % 10 == 1 && n % 100 != 11;

String _unit(int n, String singular, String plural) => '$n ${_singular(n) ? singular : plural}';

/// e.g. `5 mínútur`, `1 klukkustund og 30 mínútur`
String formatIcelandicDuration(int seconds) {
  final int hours = seconds ~/ 3600;
  final int minutes = (seconds % 3600) ~/ 60;
  final int rest = seconds % 60;
  final List<String> parts = <String>[];
  if (hours > 0) {
    parts.add(_unit(hours, 'klukkustund', 'klukkustundir'));
  }
  if (minutes > 0) {
    parts.add(_unit(minutes, 'mínúta', 'mínútur'));
  }
  if (rest > 0 || parts.isEmpty) {
    parts.add(_unit(rest, 'sekúnda', 'sekúndur'));
  }
  return parts.join(' og ');
}

/// ISO 8601 local time without an offset, the format the native side parses.
String formatLocalISO8601(DateTime d) {
  return '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}'
      'T${_two(d.hour)}:${_two(d.minute)}:${_two(d.second)}';
}

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

// Tool returning the current date and time. The system prompt already
// carries the time of the turn; this exists so the model can double-check
// after a long turn and so it never has to compute dates from memory.

import '../assistant/prompt.dart' show formatIcelandicDateTime, kIcelandicWeekdays;
import '../common.dart' show kTimeZoneName;
import 'tool.dart';

class DateTimeTool extends Tool {
  DateTimeTool();

  @override
  String get name => 'get_datetime';

  @override
  String get description =>
      'Skilar núverandi dagsetningu og klukkutíma í tímabelti notandans '
      '($kTimeZoneName). Notaðu þetta þegar reikna þarf út dagsetningu eða tíma.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': <String, dynamic>{},
        'required': <String>[],
        'additionalProperties': false,
      };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final DateTime now = ctx.now.toUtc();
    return ToolResult.success({
      'iso': now.toIso8601String(),
      'text': formatIcelandicDateTime(now),
      'weekday': kIcelandicWeekdays[now.weekday - 1],
      'timezone': kTimeZoneName,
    });
  }
}

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

// Tool returning the user's coordinates. The location never comes from the
// model: it is taken from the ambient [ToolContext], and suppressed entirely
// while private mode is on.

import 'tool.dart';

class LocationTool extends Tool {
  LocationTool();

  @override
  String get name => 'get_location';

  @override
  String get description =>
      'Skilar staðsetningu notandans (WGS84 hnitum) ef hún er þekkt. '
      'Skilar known=false ef staðsetning er óþekkt eða notandinn deilir henni '
      'ekki; spyrðu hann þá hvar hann er.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': <String, dynamic>{},
        'required': <String>[],
        'additionalProperties': false,
      };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final List<double>? loc = ctx.location;
    if (ctx.privateMode || loc == null || loc.length < 2) {
      return ToolResult.success({'known': false});
    }
    return ToolResult.success({
      'known': true,
      'latitude': loc[0],
      'longitude': loc[1],
    });
  }
}

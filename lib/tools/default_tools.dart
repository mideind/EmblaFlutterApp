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

// The platform-independent tool set. Device actions (calendar, reminders,
// alarms, messages) are registered on top of this by the platform layer.

import 'package:http/http.dart' as http;

import 'datetime_tool.dart';
import 'greynir_query_tool.dart';
import 'location_tool.dart';
import 'open_url_tool.dart';
import 'tool.dart';

export 'datetime_tool.dart';
export 'greynir_query_tool.dart';
export 'location_tool.dart';
export 'open_url_tool.dart';

/// Builds a registry with the tools that work on every platform.
ToolRegistry buildDefaultToolRegistry({
  required String serverURL,
  required String apiKey,
  http.Client? client,
}) {
  final ToolRegistry registry = ToolRegistry();
  registry.registerAll([
    GreynirQueryTool(serverURL: serverURL, apiKey: apiKey, client: client),
    DateTimeTool(),
    LocationTool(),
    OpenURLTool(),
  ]);
  return registry;
}

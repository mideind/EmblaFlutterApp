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

// Tool asking the UI to open a web page. The tool itself launches nothing:
// it validates the URL and hands it back through `ToolResult.openURL`, and
// the session route opens it (via `onOpenURL`) once the reply has been
// spoken. That keeps this file free of platform plugins and testable.

import 'tool.dart';

class OpenURLTool extends Tool {
  OpenURLTool();

  @override
  String get name => 'open_url';

  @override
  String get description =>
      'Opnar vefsíðu í vafra notandans eftir að svarið hefur verið lesið upp. '
      'Notaðu þetta einungis þegar notandinn biður um að sjá eða opna vefsíðu. '
      'Slóðin verður að vera algild http- eða https-slóð.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'url': {
            'type': 'string',
            'description': 'Algild slóð sem á að opna, t.d. https://embla.is',
          },
        },
        'required': ['url'],
        'additionalProperties': false,
      };

  @override
  String? get activityLabel => 'Opna vefsíðu…';

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final String raw = (args['url'] ?? '').toString().trim();
    if (raw.isEmpty) {
      return ToolResult.failure('Slóðina (url) vantar');
    }
    final Uri? uri = Uri.tryParse(raw);
    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return ToolResult.failure('Ógild slóð: $raw');
    }
    return ToolResult.success(
      {'url': uri.toString()},
      openURL: uri,
      endsTurn: true,
    );
  }
}

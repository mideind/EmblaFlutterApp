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

// Tool wrapping Greynir's query engine (POST /rat/v1/query).
//
// Greynir owns the live, local data: weather, public transport, exchange
// rates, opening hours, news. Speech synthesis is disabled (tts:false) since
// the LLM rewrites the answer before it reaches the TTS engine.

import 'dart:convert' show jsonDecode, jsonEncode, utf8;

import 'package:http/http.dart' as http;

import '../common.dart' show dlog, kQueryPath;
import 'tool.dart';

class GreynirQueryTool extends Tool {
  GreynirQueryTool({
    required this.serverURL,
    required this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String serverURL;
  final String apiKey;
  final http.Client _client;

  final Duration timeout = const Duration(seconds: 10);

  @override
  String get name => 'greynir_query';

  @override
  String get description =>
      'Sendir spurningu á íslensku til Greynis, fyrirspurnavélar Miðeindar. '
      'Notaðu þetta fyrir veður og veðurspár, almenningssamgöngur, gengi, '
      'opnunartíma, fréttir, flugupplýsingar og annað sem er staðbundið eða '
      'breytist með tímanum. Skilar valid=false ef Greynir kann ekki svarið.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'q': {
            'type': 'string',
            'description': 'Spurningin á náttúrulegri íslensku, '
                't.d. "hvernig er veðrið í Reykjavík".',
          },
        },
        'required': ['q'],
        'additionalProperties': false,
      };

  @override
  String? get activityLabel => 'Leita hjá Greyni…';

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final String query = (args['q'] ?? '').toString().trim();
    if (query.isEmpty) {
      return ToolResult.failure('Spurningin (q) vantar');
    }

    final Map<String, dynamic> options = {};
    if (ctx.clientID != null) {
      options['client_id'] = ctx.clientID;
    }
    if (ctx.clientType != null) {
      options['client_type'] = ctx.clientType;
    }
    if (ctx.clientVersion != null) {
      options['client_version'] = ctx.clientVersion;
    }
    final List<double>? loc = ctx.location;
    if (loc != null && loc.length >= 2 && !ctx.privateMode) {
      options['latitude'] = loc[0];
      options['longitude'] = loc[1];
    }

    final String url = '$serverURL$kQueryPath';
    final String body = jsonEncode({'q': query, 'options': options, 'tts': false});
    dlog('Greynir query to $url: $body');

    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(url),
            headers: {
              'X-API-Key': apiKey,
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: body,
          )
          .timeout(timeout);
    } catch (e) {
      dlog('Greynir query failed: $e');
      return ToolResult.failure('Náði ekki sambandi við Greyni: $e');
    }

    if (response.statusCode != 200) {
      return ToolResult.failure('Greynir svaraði með kóða ${response.statusCode}');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (e) {
      return ToolResult.failure('Ólæsilegt svar frá Greyni');
    }
    if (decoded is! Map) {
      return ToolResult.failure('Ólæsilegt svar frá Greyni');
    }

    final bool valid = decoded['valid'] == true;
    final dynamic answer = decoded['answer'];
    if (!valid || answer == null) {
      // Greynir has no answer; let the model answer from its own knowledge.
      return ToolResult.success({'valid': false});
    }

    final Map<String, dynamic> data = {'valid': true, 'answer': answer.toString()};
    final dynamic source = decoded['source'];
    if (source != null) {
      data['source'] = source.toString();
    }
    final dynamic qtype = decoded['qtype'];
    if (qtype != null) {
      data['qtype'] = qtype.toString();
    }

    return ToolResult.success(
      data,
      imageURL: _nonEmptyString(decoded['image']),
      openURL: _absoluteURL(decoded['open_url']),
    );
  }

  static String? _nonEmptyString(dynamic v) {
    if (v is String && v.trim().isNotEmpty) {
      return v.trim();
    }
    return null;
  }

  static Uri? _absoluteURL(dynamic v) {
    final String? s = _nonEmptyString(v);
    if (s == null) {
      return null;
    }
    final Uri? uri = Uri.tryParse(s);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return null;
    }
    return uri;
  }
}

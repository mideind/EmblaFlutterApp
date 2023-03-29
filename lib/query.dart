/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2020-2023 Miðeind ehf. <mideind@mideind.is>
 * Original author: Sveinbjorn Thordarson
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

// Network communication with query server

import 'dart:convert' show json;

import 'package:http/http.dart' show Response;
import 'package:http/http.dart' as http;

import './common.dart';
import './prefs.dart' show Prefs;
import './util.dart' show readQueryServerKey;
import './version.dart' show getVersion, getUniqueIdentifier, getClientType;

const kRequestTimeout = Duration(seconds: 25); // Seconds

// Send a request to query server
Future<Response?> _makeRequest(String path, Map<String, dynamic> qargs, [Function? handler]) async {
  String apiURL = Prefs().stringForKey('query_server') ?? kDefaultQueryServer;
  apiURL += path;

  dlog("Sending query POST request to $apiURL: ${qargs.toString()}");
  Response? response;
  try {
    response =
        await http.post(Uri.parse(apiURL), body: qargs).timeout(kRequestTimeout, onTimeout: () {
      handler!(null);
      return Response("Request timed out", 408);
    });
  } catch (e) {
    dlog("Error while making POST request: $e");
    response = null;
  }

  // Handle null response
  if (response == null) {
    handler!(null);
    return null;
  }

  // We have a valid response object
  dlog("Response status: ${response.statusCode}");
  dlog("Response body: ${response.body}");
  if (handler != null) {
    // Parse JSON body and feed ensuing data structure to handler function
    dynamic arg = (response.statusCode == 200) ? json.decode(response.body) : null;
    // JSON response should be a dict, otherwise something's gone horribly wrong
    arg = (arg is Map) == false ? null : arg;
    handler(arg);
  }

  return response;
}

/// Wrapper class around communication with query server
class QueryService {
  /// Clear user data
  /// Boolean [allData] param determines whether all device-specific
  /// data or only query history should be deleted server-side.
  static Future<void> clearUserData(bool allData, [Function? handler]) async {
    final Map<String, String> qargs = {
      'action': allData ? 'clear_all' : 'clear',
      'api_key': readQueryServerKey(),
      'client_type': await getClientType(),
      'client_id': await getUniqueIdentifier(),
      'client_version': await getVersion(),
    };

    await _makeRequest(kQueryHistoryAPIPath, qargs, handler);
  }
}

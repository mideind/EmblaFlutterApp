/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2021 Miðeind ehf. <mideind@mideind.is>
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
import 'dart:io' show Platform;

import 'package:device_id/device_id.dart' show DeviceId;
import 'package:http/http.dart' show Response;
import 'package:http/http.dart' as http;
import 'package:package_info/package_info.dart' show PackageInfo;

import './common.dart';
import './loc.dart' show LocationTracking;
import './prefs.dart' show Prefs;
import './util.dart' show readQueryServerKey;

const int kRequestTimeout = 10; // Seconds

String _clientType() {
  return "${Platform.operatingSystem}_flutter";
}

Future<String> _clientID() async {
  return await DeviceId.getID;
}

Future<String> _clientVersion() async {
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  return packageInfo.version;
}

// Send a request to query server
Future<Response> _makeRequest(String path, Map qargs, [Function handler]) async {
  String apiURL = Prefs().stringForKey('query_server') + path;

  dlog("Sending query POST request to $apiURL: ${qargs.toString()}");
  Response response = await http
      .post(Uri.parse(apiURL), body: qargs)
      .timeout(Duration(seconds: kRequestTimeout), onTimeout: () {
    if (handler != null) {
      handler(null);
    }
    return null;
  });

  // Handle null response
  if (response == null) {
    if (handler != null) {
      handler(null);
    }
    return null;
  }

  // We have a valid response object
  dlog("Response status: ${response.statusCode}");
  dlog("Response body: ${response.body}");
  if (handler != null) {
    // Parse JSON body and feed ensuing data structure to handler function
    dynamic arg = response.statusCode == 200 ? json.decode(response.body) : null;
    arg = (arg is Map) == false ? null : arg; // Should be a dict, otherwise something's gone wrong
    handler(arg);
  }

  return response;
}

// Singleton wrapper around communication with query server
class QueryService {
  // Send request to query API
  static Future<void> sendQuery(List<String> queries, [Function handler, bool test]) async {
    // Query args
    Map<String, String> qargs = {
      'q': queries.join('|'),
      'voice': '1',
      'voice_id': Prefs().stringForKey('voice_id') == 'Karl' ? 'Karl' : 'Dora'
    };

    // Never send client information in privacy mode
    bool privacyMode = Prefs().boolForKey('privacy_mode');
    if (privacyMode) {
      qargs['private'] = '1';
    } else {
      qargs['client_type'] = _clientType();
      qargs['client_id'] = await _clientID();
      qargs['client_version'] = await _clientVersion();
    }

    if (test == true) {
      qargs['test'] = '1';
    }

    double speed = Prefs().floatForKey('voice_speed');
    if (speed != null) {
      qargs['voice_speed'] = speed.toString();
    }

    bool shareLocation = privacyMode ? false : Prefs().boolForKey('share_location');
    if (shareLocation) {
      List<double> latlon = LocationTracking().location;
      if (latlon != null) {
        qargs['latitude'] = latlon[0].toString();
        qargs['longitude'] = latlon[1].toString();
      }
    }

    await _makeRequest(kQueryAPIPath, qargs, handler);
  }

  // Send request to query history API
  // allData boolean param determines whether all device-specific
  // data or only query history should be deleted server-side
  static Future<void> clearUserData(bool allData, [Function handler]) async {
    Map<String, String> qargs = {
      'action': allData ? 'clear_all' : 'clear',
      'client_id': await _clientID(),
      'client_type': _clientType(),
      'client_version': await _clientVersion(),
      'api_key': readQueryServerKey()
    };

    await _makeRequest(kQueryHistoryAPIPath, qargs, handler);
  }

  // This is unneeded until JS execution functionality is implemented
  // Send request to speech synthesis API
  // static Future<void> requestSpeechSynthesis(String text, [Function handler]) async {
  //   Map<String, String> qargs = {
  //     'text': text,
  //     'voice_id': Prefs().stringForKey('voice_id') == 'Karl' ? 'Karl' : 'Dora',
  //     'format': 'text', // No SSML for now...
  //     'api_key': readQueryServerKey(),
  //   };

  //   await _makeRequest(kSpeechAPIPath, qargs, handler);
  // }
}

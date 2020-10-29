/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2020 Miðeind ehf.
 * Author: Sveinbjorn Thordarson
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
//import 'package:location/location.dart';

import './prefs.dart' show Prefs;
import './util.dart' show readQueryServerKey;
import './common.dart';

// void _location() {
//     Location location = new Location();

//     bool _serviceEnabled;
//     PermissionStatus _permissionGranted;
//     LocationData _locationData;

//     _serviceEnabled = await location.serviceEnabled();
//     if (!_serviceEnabled) {
//         _serviceEnabled = await location.requestService();
//         if (!_serviceEnabled) {
//             return;
//         }
//     }

//     _permissionGranted = await location.hasPermission();
//     if (_permissionGranted == PermissionStatus.denied) {
//         _permissionGranted = await location.requestPermission();
//         if (_permissionGranted != PermissionStatus.granted) {
//             return;
//         }
//     }
//     return await location.getLocation();
// }

String _clientType() {
  return Platform.operatingSystem + "_flutter";
}

Future<String> _clientID() async {
  return await DeviceId.getID;
}

Future<String> _clientVersion() async {
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  return packageInfo.buildNumber;
}

void _logResponse(Response response) {
  dlog('Response status: ${response.statusCode}');
  dlog('Response body: ${response.body}');
}

class QueryService {
  // Send request to query API
  static Future<void> sendQuery(List<String> queries, [Function handler]) async {
    Map qargs = {
      "q": queries.join("|"),
      "voice": "1",
      "voice_id": Prefs().boolForKey('voice_id') ? "Karl" : "Dora"
    };

    bool privacyMode = Prefs().boolForKey('privacy_mode');
    if (privacyMode) {
      qargs["private"] = "1";
    } else {
      qargs["client_type"] = _clientType();
      qargs["client_id"] = await _clientID();
      qargs["client_version"] = await _clientVersion();
    }

    String speed = Prefs().stringForKey('voice_speed');
    if (speed != null) {
      qargs["voice_speed"] = speed;
    }

    bool shareLocation = privacyMode ? false : Prefs().boolForKey('share_location');
    if (shareLocation) {
      // LocationData ld = _location();
      // qargs["latitude"] = ld.latitude;
      // qargs["longitude"] = ld.longitude;
    }

    String apiURL = Prefs().stringForKey('query_server') + QUERY_API_PATH;
    dlog("Sending query POST request to $apiURL: " + qargs.toString());
    Response response = await http.post(apiURL, body: qargs);
    _logResponse(response);

    if (handler != null) {
      String arg = response.statusCode == 200 ? json.decode(response.body) : null;
      handler(arg);
    }
  }

  // Send request to speech synthesis API
  static Future<void> requestSpeechSynthesis(String text, [Function handler]) async {
    Map qargs = {
      "text": text,
      "api_key": readQueryServerKey(),
      "voice_id": Prefs().boolForKey('voice_id') ? "Karl" : "Dora",
      "format": "text" // No SSML for now...
    };

    String apiURL = Prefs().stringForKey('query_server') + SPEECH_API_PATH;
    dlog("Sending speech synthesis POST request to $apiURL: " + qargs.toString());
    Response response = await http.post(apiURL, body: qargs);
    _logResponse(response);

    if (handler != null) {
      String arg = response.statusCode == 200 ? json.decode(response.body) : null;
      handler(arg);
    }
  }

  // Send request to query history API
  static Future<void> clearUserData(bool allData, [Function handler]) async {
    Map qargs = {
      "action": allData ? "clear_all" : "clear",
      "client_id": _clientID(),
      "client_type": _clientType(),
      "client_version": _clientVersion(),
      "api_key": readQueryServerKey()
    };

    String apiURL = Prefs().stringForKey('query_server') + QUERY_HISTORY_API_PATH;
    dlog("Sending query history POST request to $apiURL: " + qargs.toString());
    Response response = await http.post(apiURL, body: qargs);
    _logResponse(response);

    if (handler != null) {
      String arg = response.statusCode == 200 ? json.decode(response.body) : null;
      handler(arg);
    }
  }
}

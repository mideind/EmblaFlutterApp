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

// import 'package:requests/requests.dart';
import 'dart:convert' show json;
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import 'package:device_id/device_id.dart';
import 'package:package_info/package_info.dart';
import './prefs.dart';
import './common.dart';

//import 'package:location/location.dart';

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

class QueryService {
  static const String queryAPIPath = "/query.api/v1";
  static const String speechAPIPath = "/speech.api/v1";
  static const String queryHistoryAPIPath = "/query_history.api/v1";

  static Future<void> sendQuery(List<String> queries, [Function handler]) async {
    var qargs = {"q": queries.join("|"), "voice": "1"};

    bool privacyMode = Prefs().boolForKey('privacy_mode');
    if (privacyMode) {
      qargs["private"] = "1";
    } else {
      qargs["client_type"] = Platform.operatingSystem;
      qargs["client_id"] = await DeviceId.getID;
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      qargs["client_version"] = packageInfo.buildNumber;
    }
    qargs["voice_id"] = Prefs().boolForKey('voice_id') ? "Karl" : "Dora";
    qargs["voice_speed"] = Prefs().stringForKey('voice_speed');

    bool shareLocation = privacyMode ? false : Prefs().boolForKey('share_location');
    if (shareLocation) {
      // LocationData ld = _location();
      // qargs["latitude"] = ld.latitude;
      // qargs["longitude"] = ld.longitude;
    }

    dlog("Sending query POST request: " + qargs.toString());
    String server = Prefs().stringForKey('query_server');
    var response = await http.post(server + queryAPIPath, body: qargs);
    dlog('Response status: ${response.statusCode}');
    dlog('Response body: ${response.body}');
    if (handler != null) {
      handler(response);
    }
  }

  static Future<void> requestSpeechSynthesis(String text, [Function handler]) async {}

  static Future<void> clearUserData(bool allData, [Function handler]) async {}
}

void main() {
  void printResponse(r) {
    final j = json.decode(r.body);
    print(j["answer"]);
  }

  QueryService.sendQuery(["hvað er klukkan"], printResponse);
}

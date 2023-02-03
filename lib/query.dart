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
import 'dart:io' show Platform;

import 'package:http/http.dart' show Response;
import 'package:http/http.dart' as http;
import 'package:platform_device_id/platform_device_id.dart';
import 'package:package_info_plus/package_info_plus.dart' show PackageInfo;

import './common.dart';
import './loc.dart' show LocationTracker;
import './prefs.dart' show Prefs;
import './util.dart' show readQueryServerKey;

const kRequestTimeout = Duration(seconds: 10); // Seconds

String _clientType() {
  return "${Platform.operatingSystem}_{$kSoftwareImplementation}";
}

Future<String?> _clientID() async {
  return await PlatformDeviceId.getDeviceId;
}

Future<String?> _clientVersion() async {
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  return packageInfo.version;
}

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
  //
  /// Send request to query server API
  static Future<void> sendQuery(List<String> queries, [Function? handler, bool? test]) async {
    // Query args
    final String voiceID = Prefs().stringForKey('voice_id') ?? kDefaultVoice;
    final Map<String, String> qargs = {'q': queries.join('|'), 'voice': '1', 'voice_id': voiceID};

    // Never send client information in privacy mode
    bool privacyMode = Prefs().boolForKey('privacy_mode');
    if (privacyMode) {
      qargs['private'] = '1';
    } else {
      qargs['client_type'] = _clientType();
      qargs['client_id'] = await _clientID() ?? "";
      qargs['client_version'] = await _clientVersion() ?? kSoftwareVersion;
    }

    if (test == true) {
      qargs['test'] = '1';
    }

    // Set voice speed if set
    double? speed = Prefs().floatForKey('voice_speed');
    if (speed != null) {
      qargs['voice_speed'] = speed.toString();
    }

    // Set location params if available and sharing is enabled
    bool shareLocation = privacyMode ? false : Prefs().boolForKey('share_location');
    if (shareLocation == true) {
      List<double>? latlon = LocationTracker().location;
      if (latlon != null) {
        qargs['latitude'] = latlon[0].toString();
        qargs['longitude'] = latlon[1].toString();
      }
    }

    await _makeRequest(kQueryAPIPath, qargs, handler);
  }

  /// Send request to query history API
  /// Boolean [allData] param determines whether all device-specific
  /// data or only query history should be deleted server-side.
  static Future<void> clearUserData(bool allData, [Function? handler]) async {
    final Map<String, String> qargs = {
      'action': allData ? 'clear_all' : 'clear',
      'api_key': readQueryServerKey(),
      'client_type': _clientType(),
      'client_id': await _clientID() ?? "",
      'client_version': await _clientVersion() ?? kSoftwareVersion
    };

    await _makeRequest(kQueryHistoryAPIPath, qargs, handler);
  }

  /// Send request to speech synthesis API
  static Future<void> requestSpeechSynthesis(String text, [Function? handler]) async {
    Map<String, String> qargs = {
      'text': text,
      'voice_id': Prefs().stringForKey('voice_id') ?? kDefaultVoice,
      'voice_speed': Prefs().floatForKey('voice_speed').toString(),
      'format': 'text', // No SSML for now...
      'api_key': readQueryServerKey(),
    };

    await _makeRequest(kSpeechSynthesisAPIPath, qargs, handler);
  }

  /// Send request to voices API
  // static Future<Map<String, dynamic>?> requestSupportedVoices() async {
  //   final Response? r = await _makeRequest(kVoiceListAPIPath, {}, null);
  //   if (r == null) {
  //     return null;
  //   } else {
  //     return json.decode(r.body);
  //   }
  // }
}

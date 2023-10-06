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

/// Info route that shows detailed information about the client.
/// Subroute of SettingsRoute, shown when the program version is tapped.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
// import 'package:platform_device_id/platform_device_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:embla_core/embla_core.dart' show kEmblaCoreVersion;

import './common.dart';
import './theme.dart';
import './prefs.dart' show Prefs;
import './loc.dart' show LocationTracker;
import './settings.dart'
    show
        SettingsAsyncLabelValueWidget,
        SettingsFullTextLabelWidget,
        SettingsAsyncFullTextLabelWidget;

const kYesLabel = "Já";
const kNoLabel = "Nei";

// Map the values returned by Platform.operatingSystem to prettified names
const Map<String, String> kOSNameToPretty = {
  "linux": "Linux",
  "macos": "macOS",
  "windows": "Windows",
  "android": "Android",
  "ios": "iOS",
};

/// Generate human-friendly version string for app
Future<String> getHumanFriendlyVersionString() async {
  final String version = await getMarketingVersion();
  final String osName = await _getPlatform();
  return "$version ($osName)";
}

/// Return marketing version string, e.g. "1.4.0", "1.3.3 dbg"
Future<String> getMarketingVersion() async {
  final packageInfo = await PackageInfo.fromPlatform();
  if (kDebugMode == true) {
    return "${packageInfo.version} dbg";
  }
  return packageInfo.version;
}

/// Returns an app-specific unique identifier for the device.
/// This is the ID used to identify the user in the backend.
/// On both iOS and Android, this is unique for all apps from
/// a single vendor.
Future<String> getUniqueDeviceIdentifier() async {
  return "blergh"; //PlatformDeviceId.getDeviceId ?? "";
}

/// Return canonical client type string (e.g. 'ios_native', 'android_flutter', etc.)
/// that consists of the OS name and the implementation name.
Future<String> getClientType() async {
  final String impl = await _getImplementation();
  return "${Platform.operatingSystem.toLowerCase()}_${impl.toLowerCase()}";
}

/// Return application name
Future<String> _getName() async {
  return kSoftwareName;
}

/// Return the unique application identifier e.g. is.mideind.Embla
Future<String> _getAppIdentifier() async {
  final packageInfo = await PackageInfo.fromPlatform();
  return packageInfo.packageName;
}

/// Return internal build number
Future<String> _getBuildNumber() async {
  final packageInfo = await PackageInfo.fromPlatform();
  return packageInfo.buildNumber;
}

/// Return the name of the operating system
Future<String> _getPlatform() async {
  return kOSNameToPretty[Platform.operatingSystem] ?? "???";
}

/// Return OS version
Future<String> _getOSVersion() async {
  return Platform.operatingSystemVersion;
}

/// Returns the device type e.g. iPhone 11 Pro Max (iPhone12,5)
Future<String> _getDeviceType() async {
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  if (Platform.isAndroid) {
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    return androidInfo.model;
  } else if (Platform.isIOS) {
    IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
    return iosInfo.utsname.machine;
  }
  return "???";
}

/// Return the implementation name e.g. "flutter", "native"
Future<String> _getImplementation() async {
  return kSoftwareImplementation;
}

/// Software author name
Future<String> _getAuthor() async {
  return kSoftwareAuthor;
}

/// Is microphone access granted?
Future<String> _getMicAccess() async {
  return (await Permission.location.isGranted) ? kYesLabel : kNoLabel;
}

/// Is location data available?
Future<String> _getLocationAccess() async {
  if (Prefs().boolForKey('privacy_mode')) {
    return "$kNoLabel (stillingar)";
  }
  return LocationTracker().known ? kYesLabel : kNoLabel;
}

Future<String> _getEmblaCoreVersion() async {
  return kEmblaCoreVersion;
}

/// Generate list of info widgets
ListView _buildVersionInfoWidgetList(BuildContext context) {
  final divider = Divider(height: 40, color: color4ctx(context));
  final infoIcon = Icon(Icons.info_outline, color: color4ctx(context));
  final header = Center(
      child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
    infoIcon,
    const Text(' Upplýsingar'),
  ]));

  return ListView(padding: standardEdgeInsets, children: [
    header,
    divider,
    SettingsAsyncLabelValueWidget('Nafn', _getName()),
    SettingsAsyncLabelValueWidget('ID', _getAppIdentifier()),
    SettingsAsyncLabelValueWidget('Tegund', getClientType()),
    SettingsAsyncLabelValueWidget('Útgáfa', getMarketingVersion()),
    SettingsAsyncLabelValueWidget('Útgáfunúmer', _getBuildNumber()),
    SettingsAsyncLabelValueWidget('EmblaCore', _getEmblaCoreVersion()),
    SettingsAsyncLabelValueWidget('Tæki', _getDeviceType()),
    SettingsAsyncLabelValueWidget('Stýrikerfi', _getPlatform()),
    SettingsAsyncFullTextLabelWidget(_getOSVersion()),
    SettingsAsyncLabelValueWidget('Útfærsla', _getImplementation()),
    SettingsAsyncLabelValueWidget('Höfundur', _getAuthor()),
    divider,
    SettingsAsyncLabelValueWidget('Hljóðnemi', _getMicAccess()),
    SettingsAsyncLabelValueWidget('Staðsetning', _getLocationAccess()),
    divider,
    const SettingsFullTextLabelWidget("Auðkenni tækis:"),
    SettingsAsyncFullTextLabelWidget(getUniqueDeviceIdentifier()),
    divider,
    // Padding at the bottom to improve scrollability
    const Padding(padding: EdgeInsets.only(top: 50, bottom: 50), child: Text(''))
  ]);
}

/// Route for displaying app and device information
class VersionRoute extends StatelessWidget {
  const VersionRoute({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: standardAppBar, body: _buildVersionInfoWidgetList(context));
  }
}

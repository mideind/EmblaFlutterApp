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

// Version route

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:platform_device_id/platform_device_id.dart';

import './common.dart';
import './settings.dart' show SettingsAsyncLabelValueWidget;
import './loc.dart' show LocationTracker;
import './theme.dart';

/// Generate canonical version string for app
Future<String> genVersionString() async {
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  final String version = packageInfo.version;
  //final String buildNumber = packageInfo.buildNumber;

  final String osName = kOSNameToPretty[Platform.operatingSystem] ?? "";
  String swInfoStr = "$version ($osName)";
  if (kReleaseMode == false) {
    swInfoStr += " dbg";
  }
  return swInfoStr;
}

Future<String> _genName() async {
  return kSoftwareName;
}

Future<String> _genAppIdentifier() async {
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  return packageInfo.packageName;
}

Future<String> _genVersion() async {
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  if (kReleaseMode == false) {
    return "${packageInfo.version} (debug)";
  }
  return packageInfo.version;
}

Future<String> _genBuildNumber() async {
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  return packageInfo.buildNumber;
}

final Map<String, String> kOSNameToPretty = {
  "linux": "Linux",
  "macos": "macOS",
  "windows": "Windows",
  "android": "Android",
  "ios": "iOS",
};

Future<String> _genPlatform() async {
  return kOSNameToPretty[Platform.operatingSystem] ?? "";
}

Future<String> _genImplementation() async {
  return kSoftwareImplementation;
}

Future<String> _genAuthor() async {
  return kSoftwareAuthor;
}

Future<String> _genMicAccess() async {
  return (await Permission.location.isGranted) ? "Já" : "Nei";
}

Future<String> _genLocationAccess() async {
  return LocationTracker().known ? "Já" : "Nei";
}

Future<String> _genUniqueIdentifier() async {
  return await PlatformDeviceId.getDeviceId ?? "???";
}

// List of settings widgets
List<Widget> _versionInfo(BuildContext context) {
  List<Widget> versionInfoWidgets = [
    SettingsAsyncLabelValueWidget('Nafn', _genName()),
    SettingsAsyncLabelValueWidget('ID', _genAppIdentifier()),
    SettingsAsyncLabelValueWidget('Útgáfa', _genVersion()),
    SettingsAsyncLabelValueWidget('Útgáfunúmer', _genBuildNumber()),
    SettingsAsyncLabelValueWidget('Stýrikerfi', _genPlatform()),
    SettingsAsyncLabelValueWidget('Útfærsla', _genImplementation()),
    SettingsAsyncLabelValueWidget('Höfundur', _genAuthor()),
    SettingsAsyncLabelValueWidget('Hljóðnemi', _genMicAccess()),
    SettingsAsyncLabelValueWidget('Staðsetning', _genLocationAccess()),
    // SettingsAsyncLabelValueWidget('Auðkenni', _genUniqueIdentifier()),
    ListTile(
        title: Text("${_genUniqueIdentifier()}", style: Theme.of(context).textTheme.bodyText2)),
  ];
  // Only include query server selection widget in debug builds
//   if (kReleaseMode == false) {
//     settingsWidgets.addAll([
//       QueryServerSegmentedWidget(items: kQueryServerPresetOptions, prefKey: 'query_server'),
//     ]);
//   }
  return versionInfoWidgets;
}

class VersionRoute extends StatelessWidget {
  const VersionRoute({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: standardAppBar,
        body: ListView(padding: const EdgeInsets.all(8), children: _versionInfo(context)));
  }
}

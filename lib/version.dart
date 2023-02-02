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

// Version route shows all sorts of info about the client

import 'dart:io' show Platform;

import 'package:embla/util.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:platform_device_id/platform_device_id.dart';

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

// Map the values returned by Platform.operatingSystem to pretty names
final Map<String, String> kOSNameToPretty = {
  "linux": "Linux",
  "macos": "macOS",
  "windows": "Windows",
  "android": "Android",
  "ios": "iOS",
};

// Generate canonical version string for app
Future<String> genVersionString() async {
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  final String version = packageInfo.version;
  final String osName = kOSNameToPretty[Platform.operatingSystem] ?? "";

  String swInfoStr = "$version ($osName)";
  if (kReleaseMode == false) {
    swInfoStr += " dbg";
  }
  return swInfoStr;
}

// Return application name
Future<String> _genName() async {
  return kSoftwareName;
}

// Return the unique application identifier e.g. is.mideind.embla
Future<String> _genAppIdentifier() async {
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  return packageInfo.packageName;
}

// Return marketing version e.g. 1.3.3
Future<String> _genVersion() async {
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  if (kReleaseMode == false) {
    return "${packageInfo.version} (debug)";
  }
  return packageInfo.version;
}

// Return internal build number
Future<String> _genBuildNumber() async {
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  return packageInfo.buildNumber;
}

// Return the name of the operating system
Future<String> _genPlatform() async {
  return kOSNameToPretty[Platform.operatingSystem] ?? "";
}

// Return OS version
Future<String> _genOSVersion() async {
  return Platform.operatingSystemVersion;
}

// Return the implementation name e.g. flutter, native
Future<String> _genImplementation() async {
  return kSoftwareImplementation.sentenceCapitalized();
}

// Software author name
Future<String> _genAuthor() async {
  return kSoftwareAuthor;
}

// Is microphone access granted?
Future<String> _genMicAccess() async {
  return (await Permission.location.isGranted) ? kYesLabel : kNoLabel;
}

// Is location access granted?
Future<String> _genLocationAccess() async {
  if (Prefs().boolForKey('privacy_mode')) {
    return "Nei";
  }
  return LocationTracker().known ? kYesLabel : kNoLabel;
}

// This returns an app-specific unique identifier for the device
// This is the ID used to identify the user in the backend
Future<String> _genUniqueIdentifier() async {
  return await PlatformDeviceId.getDeviceId ?? "???";
}

// List of version info widgets
List<Widget> _versionInfo(BuildContext context) {
  final divider = Divider(height: 40, color: color4ctx(context));
  final infoIcon = Icon(IconData(0xe33d, fontFamily: 'MaterialIcons'), color: color4ctx(context));
  final header = Center(
      child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
    infoIcon,
    Text(' Upplýsingar'),
  ]));

  List<Widget> versionInfoWidgets = [
    header,
    divider,
    SettingsAsyncLabelValueWidget('Nafn', _genName()),
    SettingsAsyncLabelValueWidget('ID', _genAppIdentifier()),
    SettingsAsyncLabelValueWidget('Útgáfa', _genVersion()),
    SettingsAsyncLabelValueWidget('Útgáfunúmer', _genBuildNumber()),
    SettingsAsyncLabelValueWidget('Stýrikerfi', _genPlatform()),
    SettingsAsyncFullTextLabelWidget(_genOSVersion()),
    SettingsAsyncLabelValueWidget('Útfærsla', _genImplementation()),
    SettingsAsyncLabelValueWidget('Höfundur', _genAuthor()),
    divider,
    SettingsAsyncLabelValueWidget('Hljóðnemi', _genMicAccess()),
    SettingsAsyncLabelValueWidget('Staðsetning', _genLocationAccess()),
    divider,
    SettingsFullTextLabelWidget("Auðkenni:"),
    SettingsAsyncFullTextLabelWidget(_genUniqueIdentifier()),
    divider,
    Padding(padding: EdgeInsets.only(top: 50, bottom: 50), child: Text(''))
  ];
  return versionInfoWidgets;
}

class VersionRoute extends StatelessWidget {
  const VersionRoute({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: standardAppBar,
        body: ListView(padding: standardEdgeInsets, children: _versionInfo(context)));
  }
}

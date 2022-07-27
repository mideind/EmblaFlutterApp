/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2020-2022 Miðeind ehf. <mideind@mideind.is>
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

// Internet of Things (IoT) route

import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';

import 'package:package_info_plus/package_info_plus.dart' show PackageInfo;

import './common.dart';
import './query.dart' show QueryService;
import './prefs.dart' show Prefs;
import './voices.dart' show VoiceSelectionRoute;
import './theme.dart';

// UI String constants
const String kNoIoTDevicesFound = 'Engin snjalltæki fundin';
const String kFindDevices = "Finna snjalltæki";


// List of IoT widgets
List<Widget> _iot(BuildContext context) {
  return <Widget>[
    Text("Embla snjallheimili"),
    // TODO: Add widget for selecting specific devices
    // TODO: Add widget for found devices
    // TODO: Add widget for activating mDNS search (and spinner)
  ];
}

class IoTRoute extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    List<Widget> wlist = _iot(context);

    if (kReleaseMode == false) {
      // Special debug widgets go here
    }

    return Scaffold(
        appBar: standardAppBar,
        body: ListView(
          padding: const EdgeInsets.all(8),
          children: wlist,
        ));
  }
}

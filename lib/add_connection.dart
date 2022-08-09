// @dart=2.9
// ^ Removes checks for null safety

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

// mDNS scan route

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import './common.dart';
import './theme.dart';
import './mdns_scan.dart';

// UI String constants
const String kNoIoTDevicesFound = 'Engin snjalltæki fundin';
const String kFindDevices = "Finna snjalltæki";

void _pushConnectionRoute(BuildContext context, dynamic arg) {
  Navigator.push(
    context,
    CupertinoPageRoute(
      builder: (context) => const MDNSRoute(),
    ),
  );
}

// List of IoT widgets
List<Widget> _options(BuildContext context) {
  return <Widget>[
    Container(
        margin: const EdgeInsets.only(
            top: 20.0, left: 25.0, bottom: 30.0, right: 25.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              "Tækjaleit",
              style: TextStyle(fontSize: 25.0, color: Colors.black),
            ),
          ],
        )),
    Container(
      margin: const EdgeInsets.only(bottom: 20.0),
      child: Center(
        child: ElevatedButton(
          onPressed: () async {
            dlog("Navigating to scan...");
            _pushConnectionRoute(context, null);
          },
          style: const ButtonStyle(),
          child: const Text(
            'Skanna',
          ),
        ),
      ),
    ),
  ];
}

class ConnectionRoute extends StatelessWidget {
  const ConnectionRoute({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<Widget> wlist = _options(context);

    if (kReleaseMode == false) {
      // Special debug widgets go here
    }

    return Scaffold(
      appBar: standardAppBar,
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: wlist,
      ),
    );
  }
}

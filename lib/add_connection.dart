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

import 'dart:core';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import './common.dart';
import './theme.dart';
import './mdns_scan.dart';
import 'connection_listitem.dart';
import '././connection.dart';

// UI String constants
const String kNoIoTDevicesFound = 'Engin snjalltæki fundin';
const String kFindDevices = "Finna snjalltæki";

void _pushConnectionRoute(BuildContext context, dynamic arg) {
  Navigator.push(
    context,
    CupertinoPageRoute(
      builder: (context) => MDNSRoute(
        connectionInfo: arg,
      ),
    ),
  );
}

// List of IoT widgets
List<Widget> _options(BuildContext context, Map<String, dynamic> connectionInfo,
    List<ConnectionListItem> connectionList) {
  return <Widget>[
    Container(
      margin: const EdgeInsets.only(
          top: 20.0, left: 25.0, bottom: 30.0, right: 25.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            "Bæta við tengingu",
            style: TextStyle(fontSize: 25.0, color: Colors.black),
          ),
          Container(
            margin: EdgeInsets.only(bottom: 40.0, top: 40.0),
            child: Center(
              child: ElevatedButton.icon(
                onPressed: () async {
                  dlog("Navigating to scan...");
                  _pushConnectionRoute(context, connectionInfo);
                },
                style: ButtonStyle(
                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50.0),
                    ),
                  ),
                  padding: MaterialStateProperty.all(
                      EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0)),
                  backgroundColor: MaterialStateProperty.resolveWith<Color>(
                    (Set<MaterialState> states) {
                      if (states.isEmpty) {
                        return Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.5);
                      }
                      if (states.contains(MaterialState.pressed)) {
                        return Theme.of(context)
                            .colorScheme
                            .secondary
                            .withOpacity(0.4);
                      }
                      return null; // Use the component's default.
                    },
                  ),
                ),
                label: Text(
                  'Finna tæki',
                ),
                icon: Icon(
                  Icons.wifi,
                  color: Theme.of(context).colorScheme.background,
                ),
              ),
            ),
          ),
          Text('Studdar tengingar',
              style: Theme.of(context).textTheme.headline1),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.02,
          ),
          Column(
            children: <Widget>[
              ListView.builder(
                physics: NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: connectionList.length,
                itemBuilder: (context, index) {
                  return connectionList[index];
                },
              ),
            ],
          ),
        ],
      ),
    ),
  ];
}

class ConnectionRoute extends StatefulWidget {
  final Map<String, dynamic> connectionInfo;

  const ConnectionRoute({Key key, this.connectionInfo}) : super(key: key);

  @override
  State<ConnectionRoute> createState() => _ConnectionRouteState();
}

class _ConnectionRouteState extends State<ConnectionRoute> {
  List<ConnectionListItem> _connectionList = <ConnectionListItem>[];

  void _returnCallback(args) {
    dlog("Returning from scan: ");
    Navigator.of(context).pop();
    Navigator.of(context).pop();
  }

  void initializeConnectionList() async {
    Future<void> makeCard(String key, Map<String, dynamic> value) async {
      _connectionList.add(ConnectionListItem(
        connection: Connection.list(
          name: value['display_name'],
          icon: Icon(
            IconData(value['icon'], fontFamily: 'MaterialIcons'),
            //TODO: use theme here. Was causing errors
            color: Colors.red, //Theme.of(context).primaryColor
            size: 24.0,
          ),
          logo: Image(
            image: NetworkImage(value['logo'], scale: 1.0),
            width: 25.0,
          ),
          webview:
              '${value['webview_connect']}${value.containsKey('connect_url') ? '&connect_url=${Uri.encodeQueryComponent(value['connect_url'])}' : ''}',
        ),
        callbackFromJavascript: _returnCallback,
      ));
      dlog("Card added: ${value['display_name']}");
    }

    Future<void> makeCards() async {
      widget.connectionInfo.forEach((key, value) async {
        dlog("Key: $key, value: $value");
        await makeCard(key, value);
      });
    }

    await makeCards();

    setState(() {
      dlog("Initializing connection list...");
      dlog("Connection list initialized with ${_connectionList.length} items");
    });
  }

  @override
  void initState() {
    super.initState();
    dlog("Connection info: ${widget.connectionInfo}");
    initializeConnectionList();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> wlist =
        _options(context, widget.connectionInfo, _connectionList);

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

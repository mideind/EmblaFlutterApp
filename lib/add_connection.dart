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

import 'package:embla/util.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:fluttertoast/fluttertoast.dart';

import './common.dart';
import './theme.dart';
import './mdns_scan.dart';
import './connection_listitem.dart';
import '././connection.dart';

// UI String constants
const String kNoIoTDevicesFound = 'Engin snjalltæki fundin';
const String kFindDevices = "Finna snjalltæki";

FToast fToastAdd;

// Pushes the mDNS scan route on the navigation stack
void _pushMDNSRoute(BuildContext context, dynamic arg) {
  Navigator.push(
    context,
    CupertinoPageRoute(
      builder: (context) => MDNSRoute(
        connectionInfo: arg,
      ),
    ),
  );
}

// List of widgets that get displayed on the add connection route
List<Widget> _options(BuildContext context, Map<String, dynamic> connectionInfo,
    List<ConnectionListItem> connectionList) {
  return <Widget>[
    Container(
      margin: const EdgeInsets.only(top: 20.0, left: 25.0, bottom: 30.0, right: 25.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            "Bæta við tengingu",
            style: sessionTextStyle,
          ),
          Container(
            margin: EdgeInsets.only(bottom: 40.0, top: 40.0),
            child: Center(
              child: ElevatedButton.icon(
                onPressed: () async {
                  dlog("Navigating to scan...");
                  _pushMDNSRoute(context, connectionInfo);
                },
                style: ElevatedButton.styleFrom(
                    primary: Theme.of(context).primaryColor.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50.0),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0)),
                label: Text(
                  'Finna tæki',
                  style: TextStyle(color: Colors.white),
                ),
                icon: Icon(
                  Icons.wifi,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Container(
            margin: EdgeInsets.only(bottom: 40.0),
            child: Text('Studdar tengingar', style: Theme.of(context).textTheme.headline1),
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
  // ignore: prefer_final_fields
  List<ConnectionListItem> _connectionList = <ConnectionListItem>[];

  // Callback from javascript to show toast message
  // if the connection failed, or navigates back to
  // The smart home screen if the connection succeeded
  void _returnCallback(args) {
    fToastAdd = FToast();
    fToastAdd.init(context);

    // Toast widget with a given message
    _showToast(String message) {
      Widget toast = Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 24.0,
          vertical: 12.0,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25.0),
          color: HexColor.fromHex("#C00004"),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
            ),
            SizedBox(
              width: 12.0,
            ),
            Text(
              message,
              style: TextStyle(
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
      fToastAdd.removeQueuedCustomToasts();

      fToastAdd.showToast(
        child: toast,
        gravity: ToastGravity.BOTTOM,
        toastDuration: Duration(
          seconds: 4,
        ),
      );
    }

    bool isError = false;
    bool isButtonPressMissing = false;
    String hubError;
    if (args[0].containsKey('error')) {
      isError = true;
    }
    if (args[0].containsKey('button_press_missing')) {
      isButtonPressMissing = true;
    }
    if (args[0].containsKey('hub_error')) {
      hubError = args[0]['hub_error'];
    }
    if (isButtonPressMissing) {
      _showToast("Ýta þarf á hnapp á tengiboxi.");
    } else if (hubError != null) {
      if (hubError == '429') {
        _showToast("Tenging mistókst.\nReyndu aftur í gegnum\n„Finna tæki“ á fyrri skjá.");
      } else if (hubError == 'no-hub') {
        _showToast("Ekkert tengibox fannst.\nReyndu aftur í gegnum\n„Finna tæki“ á fyrri skjá.");
      } else {
        _showToast("Villa í tengingu við tengibox.");
      }
    } else {
      Navigator.of(context).pop();
      if (!isError) {
        Navigator.of(context).pop();
      }
    }
  }

  // Initializes the connection list by making cards
  // for each connection in the connectionInfo map
  void initializeConnectionList() async {
    // Makes a connection card from the given key and values
    Future<void> makeCard(String key, Map<String, dynamic> value) async {
      _connectionList.add(ConnectionListItem(
        connection: Connection.list(
          name: value['display_name'],
          icon: Icon(
            IconData(
              value['icon'],
              fontFamily: 'MaterialIcons',
            ),
            color: Colors.red.withOpacity(0.5),
            size: 24.0,
          ),
          logo: Image(
              image: FadeInImage.assetNetwork(
                      image: value['logo'],
                      placeholder: 'assets/images/cube.png',
                      width: 25.0,
                      height: 25.0)
                  .image,
              errorBuilder: (context, error, stackTrace) {
                return Image.asset('assets/images/cube.png');
              },
              width: 25.0,
              height: 25.0),
          webview:
              '${value['webview_connect']}${value.containsKey('connect_url') ? '&connect_url=${Uri.encodeQueryComponent(value['connect_url'])}' : ''}',
        ),
        callbackFromJavascript: _returnCallback,
      ));
    }

    // Makes all of the cards from the connectionInfo map
    Future<void> makeCards() async {
      widget.connectionInfo.forEach((key, value) async {
        await makeCard(key, value);
      });
    }

    await makeCards();
  }

  @override
  void initState() {
    super.initState();
    initializeConnectionList();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> wlist = _options(context, widget.connectionInfo, _connectionList);

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

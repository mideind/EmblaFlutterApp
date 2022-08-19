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

import 'package:embla/util.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:platform_device_id/platform_device_id.dart';

import './common.dart';
import './theme.dart';
import './connection.dart';
import './connection_card.dart';
import './mdns.dart';

// UI String constants
const String kNoIoTDevicesFound = 'Engin snjalltæki fundin';
const String kFindDevices = "Finna snjalltæki";

FToast fToastMdns;

// Future<String> loadText(String textFile) async {
//   dlog("Loading text file: $textFile");
//   String tFile = await rootBundle.loadString('assets/iot_keys/$textFile');
//   return tFile;
// }

// List of widgets on the mDNS scan route
List<Widget> _mdns(
    BuildContext context,
    Function scanForDevices,
    List<ConnectionCard> connectionCards,
    String searchingText,
    bool isSearching) {
  return <Widget>[
    Container(
        margin: const EdgeInsets.only(
          top: 20.0,
          left: 25.0,
          bottom: 30.0,
          right: 25.0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              margin: const EdgeInsets.only(
                top: 9.0,
                bottom: 9.0,
              ),
              child: Text(
                searchingText,
                style: sessionTextStyle,
              ),
            ),
            Visibility(
              visible: !isSearching,
              child: IconButton(
                onPressed: () {
                  scanForDevices();
                },
                icon: Icon(
                  Icons.refresh_rounded,
                  size: 30.0,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ],
        )),
    Container(
      margin: const EdgeInsets.only(
        top: 20.0,
        left: 20.0,
        bottom: 30.0,
      ),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 10.0,
        children: connectionCards,
      ),
    ),
    Center(
      child: Column(
        children: <Widget>[
          Visibility(
            visible: !isSearching && connectionCards.isEmpty,
            child: Container(
              margin: const EdgeInsets.only(
                top: 20.0,
                left: 25.0,
                bottom: 30.0,
                right: 25.0,
              ),
              child: Column(
                children: [
                  Text(
                    'Engin tæki fundust.\n',
                    style: TextStyle(
                      fontSize: 16.0,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    'Vinsamlegast reyndu aftur',
                    style: TextStyle(
                      fontSize: 16.0,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    'eða veldu tæki handvirkt.',
                    style: TextStyle(
                      fontSize: 16.0,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(
            height: 50.0,
          ),
          Center(
            child: Visibility(
              visible: isSearching,
              child: SpinKitRing(
                color: Theme.of(context).primaryColor,
                size: 50.0,
              ),
            ),
          ),
        ],
      ),
    ),
  ];
}

class MDNSRoute extends StatefulWidget {
  final Map<String, dynamic> connectionInfo;

  const MDNSRoute({Key key, this.connectionInfo}) : super(key: key);

  @override
  State<MDNSRoute> createState() => _MDNSRouteState();
}

class _MDNSRouteState extends State<MDNSRoute> {
  List<ConnectionCard> connectionCards = [];
  String searchingText = "Leita að snjalltækjum...";
  bool isSearching = false;
  List<RegExp> kmDNSServiceFilters = <RegExp>[];
  Map<String, String> serviceMap = {};

  // Callback from javascript to show toast message
  // if the connection failed, or navigates back to
  // The smart home screen if the connection succeeded
  void _returnCallback(args) {
    fToastMdns = FToast();
    fToastMdns.init(context);

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
      fToastMdns.removeQueuedCustomToasts();

      fToastMdns.showToast(
        child: toast,
        gravity: ToastGravity.BOTTOM,
        toastDuration: Duration(seconds: 4),
      );
    }

    bool isError = false;
    bool isButtonPressMissing = false;
    int hubError;
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
      if (hubError == 429) {
        _showToast("Of margar pörunarbeiðnir.\nReyndu aftur síðar.");
      } else {
        _showToast("Villa í tengingu við tengibox.");
      }
    } else {
      Navigator.of(context).pop();
      if (!isError) {
        Navigator.of(context).pop();
        Navigator.of(context).pop();
      }
    }
  }

  // Makes a card out of the connectionName and connectionInfo
  void makeCard(String connectionName, String ipAddress) async {
    if (mounted) {
      setState(() {
        connectionCards.add(ConnectionCard(
          connection: Connection.card(
            name: widget.connectionInfo[connectionName]['name'],
            brand: widget.connectionInfo[connectionName]['brand'],
            icon: Icon(
              IconData(
                widget.connectionInfo[connectionName]['icon'],
                fontFamily: 'MaterialIcons',
              ),
              color: Colors.red.withOpacity(0.5),
              size: 30.0,
            ),
            webview:
                '${widget.connectionInfo[connectionName]['webview_connect']}${widget.connectionInfo[connectionName].containsKey('connect_url') ? '&connect_url=${Uri.encodeQueryComponent(widget.connectionInfo[connectionName]['connect_url'])}' : ''}${(connectionName == 'philips_hue') ? '&hub_ip_address=$ipAddress' : ''}',
          ),
          callbackFromJavascript: _returnCallback,
        ));
      });
    }
  }

  // Scans for devices and adds them to the list of connection cards.
  void scanForDevices() async {
    if (isSearching) {
      return;
    }
    if (mounted) {
      setState(() {
        searchingText = "Tækjaleit í gangi...";
        connectionCards.clear();
      });

      isSearching = true;
      MulticastDNSSearcher mdns = MulticastDNSSearcher();

      await mdns.findLocalDevices(kmDNSServiceFilters, serviceMap, makeCard);
      isSearching = false;
      if (mounted) {
        setState(() {
          searchingText = 'Tækjaleit lokið';
        });
      }
    }
  }

  // Creates mdns service filters for each connection
  // in the connectionInfo map
  void createServiceFilters() {
    widget.connectionInfo.forEach((key, connection) {
      RegExp regex = RegExp("${connection["mdns_name"]}");
      kmDNSServiceFilters.add(regex);
      serviceMap[connection["mdns_name"]] = key;
    });
  }

  @override
  void initState() {
    super.initState();
    createServiceFilters();
    scanForDevices();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> wlist = _mdns(
        context, scanForDevices, connectionCards, searchingText, isSearching);

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

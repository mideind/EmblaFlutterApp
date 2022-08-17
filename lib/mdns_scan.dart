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

import 'dart:convert';

import 'package:embla/util.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter/services.dart' show rootBundle;
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
const String kHost = "http://192.168.1.76:5000";

FToast fToastMdns;

// Future<String> loadText(String textFile) async {
//   dlog("Loading text file: $textFile");
//   String tFile = await rootBundle.loadString('assets/iot_keys/$textFile');
//   return tFile;
// }

// List of IoT widgets
List<Widget> _mdns(
    BuildContext context,
    Function scanForDevices,
    List<ConnectionCard> connectionCards,
    String searchingText,
    bool isSearching) {
  return <Widget>[
    Container(
        margin: const EdgeInsets.only(
            top: 20.0, left: 25.0, bottom: 30.0, right: 25.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 9.0, bottom: 9.0),
              child: Text(
                searchingText,
                // style: const TextStyle(fontSize: 25.0, color: Colors.black),
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
      margin: const EdgeInsets.only(top: 20.0, left: 20.0, bottom: 30.0),
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
                  top: 20.0, left: 25.0, bottom: 30.0, right: 25.0),
              child: Column(
                children: [
                  Text(
                    'Engin tæki fundust.',
                    style: Theme.of(context).textTheme.headline4,
                  ),
                  Text(
                    'Vinsamlegast reyndu aftur\neða veldu tæki handvirkt.',
                    style: Theme.of(context).textTheme.headline4,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 50.0),
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

  void _returnCallback(args) {
    fToastMdns = FToast();
    fToastMdns.init(context);

    _showToast(String message) {
      Widget toast = Container(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25.0),
          color: HexColor.fromHex("#C00004"),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.white),
            SizedBox(
              width: 12.0,
            ),
            Text(message, style: TextStyle(color: Colors.white)),
          ],
        ),
      );

      fToastMdns.showToast(
        child: toast,
        gravity: ToastGravity.BOTTOM,
        toastDuration: Duration(seconds: 4),
      );
    }

    dlog("Returning from scan: ");
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

  void makeCard(String connectionName, String ipAddress) async {
    dlog("${widget.connectionInfo}");
    String clientID = await PlatformDeviceId.getDeviceId;
    // Map<String, String> domain_map = {
    //   "_hue._tcp.local": "philips_hue",
    //   "_sonos._tcp.local": "sonos",
    // };
    // String connection_name = domain_map[domainName];

    dlog("MAKING CARD: $connectionName");
    dlog("Connectioninfo: ${widget.connectionInfo}");
    if (mounted) {
      dlog("!!!!!!!Mounted!!!!!!!!!");
      setState(() {
        dlog("Making card: $connectionName");
        dlog("!!!!!!IP: $ipAddress");
        connectionCards.add(ConnectionCard(
          connection: Connection.card(
            name: widget.connectionInfo[connectionName]['name'],
            brand: widget.connectionInfo[connectionName]['brand'],
            icon: Icon(
              IconData(widget.connectionInfo[connectionName]['icon'],
                  fontFamily: 'MaterialIcons'),
              // connectionInfo[name]['icon'] as IconData,
              color: Colors.red.withOpacity(0.5),
              size: 30.0,
            ),
            webview:
                '${widget.connectionInfo[connectionName]['webview_connect']}${widget.connectionInfo[connectionName].containsKey('connect_url') ? '&connect_url=${Uri.encodeQueryComponent(widget.connectionInfo[connectionName]['connect_url'])}' : ''}${(connectionName == 'philips_hue') ? '&hub_ip_address=$ipAddress' : ''}',
          ),
          callbackFromJavascript: _returnCallback,
        ));
        dlog("Connection cards: ${connectionCards.length}");
      });
    }
  }

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

      dlog("Finding devices");
      await mdns.findLocalDevices(kmDNSServiceFilters, serviceMap, makeCard);
      isSearching = false;
      if (mounted) {
        setState(() {
          searchingText = 'Tækjaleit lokið';
          dlog("Search text set");
        });
      }
    }
  }

  void createServiceFilters() {
    widget.connectionInfo.forEach((key, connection) {
      dlog("Creating service filter for: ${connection['mdns_name']}");
      RegExp regex = RegExp("${connection["mdns_name"]}");
      kmDNSServiceFilters.add(regex);
      dlog("Service filters: ${kmDNSServiceFilters.length}");
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

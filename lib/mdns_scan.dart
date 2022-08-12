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
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:platform_device_id/platform_device_id.dart';

import './common.dart';
import './theme.dart';
import 'connection.dart';
import 'connection_card.dart';
import './mdns.dart';

// UI String constants
const String kNoIoTDevicesFound = 'Engin snjalltæki fundin';
const String kFindDevices = "Finna snjalltæki";
const String kHost = "http://192.168.1.76:5000";

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
                style: const TextStyle(fontSize: 25.0, color: Colors.black),
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
    Center(
      child: Column(
        children: <Widget>[
          Container(
            color: Colors.red,
            margin: const EdgeInsets.only(top: 20.0, left: 20.0, bottom: 30.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                Column(
                  children: <Widget>[
                    Wrap(
                      spacing: 10.0,
                      runSpacing: 10.0,
                      children: connectionCards,
                    ),
                  ],
                ),
              ],
            ),
          ),
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
                    'Vinsamlegast reyndu aftur eða veldu tæki handvirkt.',
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

  void makeCard(String name, String domainName) async {
    dlog("${widget.connectionInfo}");
    String clientID = await PlatformDeviceId.getDeviceId;
    Map<String, String> domain_map = {
      "_hue._tcp.local": "philips_hue",
      "_sonos._tcp.local": "sonos",
    };
    String connection_name = domain_map[domainName];

    dlog("MAKING CARD: $connection_name");
    dlog("Connectioninfo: ${widget.connectionInfo}");
    setState(() {
      dlog("Making card: $connection_name");
      connectionCards.add(ConnectionCard(
        connection: Connection(
          name: widget.connectionInfo[connection_name]['name'],
          brand: widget.connectionInfo[connection_name]['brand'],
          icon: Icon(
            IconData(widget.connectionInfo[connection_name]['icon'],
                fontFamily: 'MaterialIcons'),
            // connectionInfo[name]['icon'] as IconData,
            color: Theme.of(context).primaryColor,
            size: 30.0,
          ),
          webview: widget.connectionInfo[connection_name]['webview_connect'],
        ),
      ));
      dlog("Connection cards: ${connectionCards.length}");
    });
  }

  void scanForDevices() async {
    if (isSearching) {
      return;
    }
    setState(() {
      searchingText = "Tækjaleit í gangi...";
      connectionCards.clear();
    });
    isSearching = true;
    MulticastDNSSearcher mdns = MulticastDNSSearcher();
    dlog("Finding devices");
    await mdns.findLocalDevices(kmDNSServiceFilters, makeCard);
    isSearching = false;

    setState(() {
      searchingText = 'Tækjaleit lokið';
      dlog("Search text set");
    });
  }

  @override
  void initState() {
    super.initState();
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
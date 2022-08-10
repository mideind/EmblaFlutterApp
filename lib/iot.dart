// @dart=2.9
// ^ Removes checks for null safety
//import 'dart:html';

import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:http/http.dart' as http;
import 'package:platform_device_id/platform_device_id.dart';
import 'package:rxdart/rxdart.dart';

import './common.dart';
import './theme.dart';
import './connection_card.dart';
import './connection.dart';
import './add_connection.dart';

// UI String constants
const String kNoIoTDevicesFound = 'Engin snjalltæki fundin';
const String kFindDevices = "Finna snjalltæki";
const String kHost = "http://192.168.1.76:5000";

const List<String> kDeviceTypes = <String>["Öll tæki", "Ljós", "Gardínur"];

void _pushMDNSRoute(BuildContext context, dynamic arg) {
  Navigator.push(
    context,
    CupertinoPageRoute(
      builder: (context) => ConnectionRoute(
        connectionInfo: arg,
      ),
    ),
  );
}

// List of IoT widgets
List<Widget> _iot(BuildContext context, List<ConnectionCard> connectionCards,
    bool isSearching, Map<String, dynamic> connectionInfo) {
  dlog("Context: , $context");
  return <Widget>[
    Container(
        margin: const EdgeInsets.only(
            top: 20.0, left: 25.0, bottom: 30.0, right: 25.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Embla snjallheimili",
              style: TextStyle(fontSize: 25.0, color: Colors.black),
            ),
            IconButton(
              onPressed: () {
                _pushMDNSRoute(context, connectionInfo);
              },
              icon: Icon(
                Icons.add,
                size: 30.0,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ],
        )),
    Container(
      margin: const EdgeInsets.only(left: 25.0, bottom: 20.0),
      child: Text(
        'Mínar tengingar',
        style: Theme.of(context).textTheme.headline4,
      ),
    ),
    Container(
      margin: const EdgeInsets.only(top: 20.0, left: 20.0, bottom: 30.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Column(
            children: <Widget>[
              Wrap(
                spacing: 8.0,
                runSpacing: 10.0,
                children: connectionCards,
              ),
              Visibility(
                visible: !isSearching && connectionCards.isEmpty,
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.only(
                        top: 20.0, left: 25.0, bottom: 30.0, right: 25.0),
                    child: Text(
                      'Engar tengingar til staðar.',
                      style: TextStyle(fontSize: 16.0, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 50.0),
              Visibility(
                visible: isSearching,
                child: SpinKitRing(
                  color: Theme.of(context).primaryColor,
                  size: 50.0,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  ];
}

class IoTRoute extends StatefulWidget {
  const IoTRoute({Key key}) : super(key: key);

  @override
  State<IoTRoute> createState() => _IoTRouteState();
}

class _IoTRouteState extends State<IoTRoute> {
  List<ConnectionCard> connectionCards = [];
  bool isSearching = false;
  Map<String, dynamic> connectionInfo = {};

  void makeCard(String name, String clientID, String iotGroup) async {
    setState(() {
      connectionCards.add(ConnectionCard(
        connection: Connection(
          name: connectionInfo[name]['name'],
          brand: connectionInfo[name]['brand'],
          icon: Icon(
            IconData(connectionInfo[name]['icon'], fontFamily: 'MaterialIcons'),
            // connectionInfo[name]['icon'] as IconData,
            color: Theme.of(context).primaryColor,
            size: 30.0,
          ),
          webview: connectionInfo[name]['webview_home'],
          // context: context,
        ),
      ));
    });
  }

  void getSupportedConnections() async {
    setState(() {
      isSearching = true;
    });
    String clientID = await PlatformDeviceId.getDeviceId;
    await http
        .get(Uri.parse(
            '$kHost/get_supported_iot_connections.api?client_id=$clientID&host=$kHost'))
        .then((response) {
      final Map<String, dynamic> body = json.decode(response.body);
      connectionInfo = body['data']['connections'];
      setState(() {
        isSearching = false;
      });
    }).catchError((error) {
      dlog("Error: $error");
    }).whenComplete(() {
      setState(() {
        isSearching = false;
        scanForDevices();
      });
    });
  }

  void scanForDevices() async {
    dlog("Scanning for devices...");
    if (isSearching) {
      return;
    }
    setState(() {
      connectionCards.clear();
    });
    isSearching = true;
    String clientID = await PlatformDeviceId.getDeviceId;

    // Fetching connections from data base
    Future<http.Response> fetchConnections() async {
      return http
          .get(Uri.parse('$kHost/get_iot_devices.api?client_id=$clientID'));
    }

    fetchConnections().then((http.Response response) {
      Map<String, dynamic> json = jsonDecode(response.body);
      if (json['valid'] == true) {
        json.removeWhere((key, value) => key == "valid");
        for (Map<String, dynamic> groups in json.values) {
          for (final group in groups.entries) {
            String iotGroup = group.key;
            Map<String, dynamic> devices = group.value;
            for (String device in devices.keys) {
              dlog("Making card after fetching connections");
              makeCard(device, clientID, iotGroup);
            }
          }
        }
      }
    }).catchError((error) {
      dlog("Error: $error");
    }).whenComplete(() {
      setState(() {
        isSearching = false;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    getSupportedConnections();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> wlist =
        _iot(context, connectionCards, isSearching, connectionInfo);

    return Scaffold(
        appBar: standardAppBar,
        body: ListView(
          padding: const EdgeInsets.all(8),
          children: wlist,
        ));
  }
}

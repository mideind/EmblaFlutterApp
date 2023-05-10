/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2023 Miðeind ehf. <mideind@mideind.is>
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

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:platform_device_id/platform_device_id.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../session.dart';
import '../util.dart';
import '../common.dart';
import '../theme.dart';
import '../prefs.dart' show Prefs;

import './connection_card.dart';
import './connection.dart';
import './add_connection.dart';

// UI String constants
const String kNoSmarthomeDevicesFound = 'Engin snjalltæki fundin';
const String kFindDevices = "Finna snjalltæki";

FToast? fToastSmarthome;

// Pushes the add_connection route on the navigation stack
// If you navigate back to this route, the list of devices
// will be refreshed
void _pushConnectionRoute(BuildContext context, Function refreshDevices, dynamic arg) {
  Navigator.push(
    context,
    CupertinoPageRoute(
      builder: (context) => ConnectionRoute(
        connectionInfo: arg,
      ),
    ),
  ).then((value) {
    // Refresh the list of devices
    refreshDevices();
  });
}

// List of Smarthome home screen widgets
List<Widget> _smarthome(
  BuildContext context,
  List<ConnectionCard> connectionCards,
  bool isSearching,
  bool isNetworkConnection,
  bool isServerError,
  Map<String, dynamic> connectionInfo,
  Function scanCallback,
) {
  dlog("isSearching in _iot: $isSearching");
  dlog("isNetworkConnection in _iot: $isNetworkConnection");
  dlog("isServerError in _iot: $isServerError");
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
              child: const Text(
                "Embla snjallheimili",
                style: sessionTextStyle,
              ),
            ),
            Visibility(
              visible: !isSearching && isNetworkConnection && !isServerError,
              child: IconButton(
                onPressed: () {
                  _pushConnectionRoute(context, scanCallback, connectionInfo);
                },
                icon: Icon(
                  Icons.add,
                  size: 30.0,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ],
        )),
    Container(
      margin: const EdgeInsets.only(
        left: 25.0,
        bottom: 20.0,
      ),
      child: Text(
        'Mínar tengingar',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
    ),
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
            visible:
                !isSearching && isNetworkConnection && !isServerError && connectionCards.isEmpty,
            child: Center(
              child: Container(
                margin: const EdgeInsets.only(
                  top: 20.0,
                  left: 25.0,
                  bottom: 30.0,
                  right: 25.0,
                ),
                child: Column(
                  children: [
                    const Text(
                      'Engar tengingar til staðar.',
                      style: TextStyle(
                        fontSize: 16.0,
                        color: Colors.grey,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(bottom: 40.0, top: 40.0),
                      child: Center(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            _pushConnectionRoute(context, scanCallback, connectionInfo);
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50.0),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0)),
                          label: const Text(
                            'Bæta við tengingu',
                            style: TextStyle(color: Colors.white),
                          ),
                          icon: const Icon(
                            Icons.add,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Visibility(
            visible: !isNetworkConnection,
            child: Center(
              child: Container(
                margin: const EdgeInsets.only(
                  top: 20.0,
                  left: 25.0,
                  bottom: 30.0,
                  right: 25.0,
                ),
                child: const Text(
                  kNoInternetMessage,
                  style: TextStyle(
                    fontSize: 16.0,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ),
          Visibility(
            visible: isServerError,
            child: Center(
              child: Container(
                margin: const EdgeInsets.only(
                  top: 20.0,
                  left: 25.0,
                  bottom: 30.0,
                  right: 25.0,
                ),
                child: const Text(
                  kServerErrorMessage,
                  style: TextStyle(
                    fontSize: 16.0,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(
            height: 50.0,
          ),
          Center(
            child: Visibility(
              visible: isSearching && !isServerError,
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

class SmarthomeRoute extends StatefulWidget {
  const SmarthomeRoute({Key? key}) : super(key: key);

  @override
  State<SmarthomeRoute> createState() => _SmarthomeRouteState();
}

class _SmarthomeRouteState extends State<SmarthomeRoute> {
  List<ConnectionCard> connectionCards = [];
  bool isSearching = false;
  bool isNetworkConnection = true;
  bool isServerError = false;
  Map<String, dynamic> connectionInfo = {};

  Future<bool> isConnectedToInternet() async {
    // TODO: Is this needed? Doc says to not use it for wifi status
    final ConnectivityResult connectivityResult = await Connectivity().checkConnectivity();
    return (connectivityResult != ConnectivityResult.none);
  }

  // Callback from javascript for when a device is disconnected
  // Displays a toast message to confirm the disconnection
  void disconnectCallback(args) {
    fToastSmarthome = FToast();
    fToastSmarthome!.init(context);

    // Toast widget with a given message
    void showToast(bool isSuccess) {
      Widget toast = Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 24.0,
          vertical: 12.0,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25.0),
          color: (isSuccess) ? HexColor.fromHex('#87c997') : HexColor.fromHex("#C00004"),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              (isSuccess) ? Icons.check : Icons.error_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(
              width: 12.0,
            ),
            Text(
              (isSuccess) ? "Aftenging tókst" : "Villa kom upp, reyndu aftur.",
              style: const TextStyle(
                color: Colors.white,
              ),
            ),
          ],
        ),
      );

      fToastSmarthome!.removeQueuedCustomToasts();

      fToastSmarthome!.showToast(
        child: toast,
        gravity: ToastGravity.BOTTOM,
        toastDuration: const Duration(seconds: 3),
      );
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text("Aftengja tæki"),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  "Ertu viss um að þú viljir aftengja ${connectionInfo[args[0]["iotName"]]["display_name"]}?",
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Hætta við'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text("Aftengja"),
              onPressed: () {
                http
                    .delete(Uri.parse(
                        "${Prefs().stringForKey('query_server')}/delete_iot_data.api?client_id=${args[0]["clientId"]}&iot_group=${args[0]["iotGroup"]}&iot_name=${args[0]["iotName"]}"))
                    .then((value) {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                  showToast(true);
                }).catchError((error) {
                  dlog("Error: $error");
                  showToast(false);
                });
              },
            ),
          ],
        );
      },
    );
  }

  // Makes a single connection card from a given connection info
  // with the name as key
  void makeCard(String name) async {
    setState(() {
      connectionCards.add(ConnectionCard(
        connection: Connection.card(
          name: connectionInfo[name]['name'],
          brand: connectionInfo[name]['brand'],
          icon: Icon(
            IconData(
              connectionInfo[name]['icon'],
              fontFamily: 'MaterialIcons',
            ),
            color: Colors.red.withOpacity(0.5), // TODO: Use theme color
            size: 30.0,
          ),
          webview: connectionInfo[name]['webview_home'],
        ),
        navigationCallback: scanCallback,
        callbackFromJavascript: disconnectCallback,
      ));
    });
  }

  // Fetches all available connections from the server
  // and puts it in the connection info map
  void getSupportedConnections() async {
    // Check for internet connectivity
    if (await isConnectedToInternet() == false) {
      setState(() {
        isNetworkConnection = false;
        isServerError = false;
        isSearching = false;
      });
      return;
    }
    setState(() {
      isNetworkConnection = true;
      isSearching = true;
      isServerError = false;
    });
    String? clientID = await PlatformDeviceId.getDeviceId;
    await Future.any([
      http
          .get(Uri.parse(
              "${Prefs().stringForKey('query_server')}/get_supported_iot_connections.api?client_id=$clientID&host=${Prefs().stringForKey('query_server')}"))
          .then((response) {
        dlog("Response: ${response.body}");
        final Map<String, dynamic> body = json.decode(response.body);
        connectionInfo = body['data']['connections'];
      }).whenComplete(() {
        setState(() {
          isSearching = false;
          isServerError = false;
          scanForDevices();
        });
      }),
      Future.delayed(const Duration(seconds: 5)).then(
        (value) {
          dlog("Timeout");
          if (isSearching == true) {
            setState(() {
              dlog("isSearching: $isSearching");
              isSearching = false;
              isServerError = true;
              dlog("isSearching: $isSearching");
            });
          }
        },
      ),
    ]).catchError((error) {
      setState(() {
        dlog("isSearching: $isSearching");
        isSearching = false;
        dlog("isSearching: $isSearching");
      });
      dlog("Error: $error");
    });
  }

  // Gets all connections for a given client id
  void scanForDevices() async {
    if (await isConnectedToInternet() == false) {
      setState(() {
        isNetworkConnection = false;
        isServerError = false;
        isSearching = false;
        connectionCards.clear();
      });
      return;
    }
    dlog("scanForDevices");
    if (isSearching) {
      return;
    }
    setState(() {
      connectionCards.clear();
    });
    isSearching = true;
    String? clientID = await PlatformDeviceId.getDeviceId;

    // Fetching connections from data base
    Future<http.Response> fetchConnections() async {
      return http.get(Uri.parse(
          "${Prefs().stringForKey('query_server')}/get_iot_devices.api?client_id=$clientID"));
    }

    await Future.any([
      fetchConnections().then((http.Response response) {
        Map<String, dynamic> json = jsonDecode(response.body);
        if (json['valid'] == true) {
          json.removeWhere((key, value) => key == "valid");
          for (Map<String, dynamic> groups in json.values) {
            for (final group in groups.entries) {
              Map<String, dynamic> devices = group.value;
              for (String device in devices.keys) {
                makeCard(device);
              }
            }
          }
        }
      }).whenComplete(() {
        setState(() {
          isSearching = false;
          isServerError = false;
          isNetworkConnection = true;
        });
      }),
      Future.delayed(const Duration(seconds: 5)).then(
        (value) {
          dlog("Timeout");
          if (isSearching == true) {
            setState(() {
              dlog("isSearching: $isSearching");
              isSearching = false;
              isServerError = true;
              dlog("isSearching: $isSearching");
            });
          }
        },
      ),
    ]).catchError((error) {
      dlog("Error: $error");
    });
  }

  @override
  void initState() {
    super.initState();
    getSupportedConnections();
  }

  void scanCallback() {
    setState(() {
      scanForDevices();
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> wlist = _smarthome(context, connectionCards, isSearching, isNetworkConnection,
        isServerError, connectionInfo, scanCallback);

    return Scaffold(
        appBar: standardAppBar,
        body: ListView(
          padding: standardEdgeInsets,
          children: wlist,
        ));
  }
}

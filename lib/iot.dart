// @dart=2.9
// ^ Removes checks for null safety
//import 'dart:html';

import 'dart:convert';

import 'package:embla/util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:http/http.dart' as http;
import 'package:platform_device_id/platform_device_id.dart';
import 'package:fluttertoast/fluttertoast.dart';

import './common.dart';
import './theme.dart';
import './connection_card.dart';
import './connection.dart';
import './add_connection.dart';

// UI String constants
const String kNoIoTDevicesFound = 'Engin snjalltæki fundin';
const String kFindDevices = "Finna snjalltæki";

const List<String> kDeviceTypes = <String>["Öll tæki", "Ljós", "Gardínur"];
FToast fToastIot;

// Pushes the add_connection route on the navigation stack
// If you navigate back to this route, the list of devices
// will be refreshed
void _pushConnectionRoute(
    BuildContext context, Function refreshDevices, dynamic arg) {
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

// List of IoT home screen widgets
List<Widget> _iot(
  BuildContext context,
  List<ConnectionCard> connectionCards,
  bool isSearching,
  Map<String, dynamic> connectionInfo,
  Function scanCallback,
) {
  return <Widget>[
    Container(
        margin: const EdgeInsets.only(
            top: 20.0, left: 25.0, bottom: 30.0, right: 25.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Embla snjallheimili",
              style: sessionTextStyle,
            ),
            IconButton(
              onPressed: () {
                _pushConnectionRoute(context, scanCallback, connectionInfo);
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

class IoTRoute extends StatefulWidget {
  const IoTRoute({Key key}) : super(key: key);

  @override
  State<IoTRoute> createState() => _IoTRouteState();
}

class _IoTRouteState extends State<IoTRoute> {
  List<ConnectionCard> connectionCards = [];
  bool isSearching = false;
  Map<String, dynamic> connectionInfo = {};
  DisconnectButtonPromptWidget disconnectButtonPromptWidget;

  // Callback from javascript for when a device is disconnected
  // Displays a toast message to confirm the disconnection
  void disconnectCallback(args) {
    fToastIot = FToast();
    fToastIot.init(context);

    // Toast widget with a given message
    _showToast(bool isSuccess) {
      Widget toast = Container(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25.0),
          color: (isSuccess)
              ? HexColor.fromHex('#87c997')
              : HexColor.fromHex("#C00004"),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon((isSuccess) ? Icons.check : Icons.error_outline_rounded,
                color: Colors.white),
            SizedBox(
              width: 12.0,
            ),
            Text(
                (isSuccess)
                    ? "Aftenging tókst"
                    : "Villa kom upp, reyndu aftur.",
                style: TextStyle(color: Colors.white)),
          ],
        ),
      );

      fToastIot.removeQueuedCustomToasts();

      fToastIot.showToast(
        child: toast,
        gravity: ToastGravity.BOTTOM,
        toastDuration: Duration(seconds: 3),
      );
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Aftengja tæki"),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                    "Ertu viss um að þú viljir aftengja ${connectionInfo[args[0]["iotName"]]["display_name"]}?"),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Hætta við'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("Aftengja"),
              onPressed: () {
                http
                    .delete(Uri.parse(
                        "$kDefaultQueryServer/delete_iot_data.api?client_id=${args[0]["clientId"]}&iot_group=${args[0]["iotGroup"]}&iot_name=${args[0]["iotName"]}"))
                    .then((value) {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                  _showToast(true);
                }).catchError((error) {
                  dlog("Error: $error");
                  _showToast(false);
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
            IconData(connectionInfo[name]['icon'], fontFamily: 'MaterialIcons'),
            color: Colors.red.withOpacity(0.5),
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
    setState(() {
      isSearching = true;
    });
    String clientID = await PlatformDeviceId.getDeviceId;
    await http
        .get(Uri.parse(
            '$kDefaultQueryServer/get_supported_iot_connections.api?client_id=$clientID&host=$kDefaultQueryServer'))
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

  // Gets all connections for a given client id
  void scanForDevices() async {
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
      return http.get(Uri.parse(
          '$kDefaultQueryServer/get_iot_devices.api?client_id=$clientID'));
    }

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

  void scanCallback() {
    setState(() {
      scanForDevices();
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> wlist = _iot(
        context, connectionCards, isSearching, connectionInfo, scanCallback);

    return Scaffold(
        appBar: standardAppBar,
        body: ListView(
          padding: const EdgeInsets.all(8),
          children: wlist,
        ));
  }
}

// Button that presents an alert with an action name + handler
class DisconnectButtonPromptWidget extends StatelessWidget {
  final String label;
  final String alertText;
  final String buttonTitle;
  final Function handler;

  const DisconnectButtonPromptWidget(
      {Key key, this.label, this.alertText, this.buttonTitle, this.handler})
      : super(key: key);

  Future<void> _showPromptDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("$label?"),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(alertText),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Hætta við'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(buttonTitle),
              onPressed: () {
                handler();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {
        _showPromptDialog(context);
      },
      child: Text(label, style: TextStyle(fontSize: defaultFontSize)),
    );
  }
}

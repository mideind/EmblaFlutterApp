import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import './iot_web.dart';
import './connection.dart';

// Pushes a webroute on the navigation stack
// If there is a navigation callback, call it
// when returning to the previous route
void _pushWebRoute(BuildContext context, Function navigationCallback, dynamic arg,
    Function callbackFromJavascript) {
  Navigator.push(
    context,
    CupertinoPageRoute(
      builder: (context) => WebViewRoute(
        initialURL: arg,
        callbackFromJavascript: callbackFromJavascript,
      ),
    ),
  ).then(
    (value) {
      if (navigationCallback != null) {
        navigationCallback();
      }
    },
  );
}

class ConnectionListItem extends StatelessWidget {
  final Connection connection;
  final Function navigationCallback;
  final Function callbackFromJavascript;

  const ConnectionListItem(
      {Key key, @required this.connection, this.navigationCallback, this.callbackFromJavascript})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.all(0),
          primary: Theme.of(context).cardColor,
          onPrimary: Theme.of(context).splashColor,
          splashFactory: InkRipple.splashFactory,
        ),
        onPressed: () {
          _pushWebRoute(context, navigationCallback, connection.webview, callbackFromJavascript);
        },
        child: ListTile(
          leading: SizedBox(
            width: 25.0,
            height: 25.0,
            child: connection.logo,
          ),
          title: Text(connection.name),
          trailing: connection.icon,
        ),
      ),
    );
  }
}

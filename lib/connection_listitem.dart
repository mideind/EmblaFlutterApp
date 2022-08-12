import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import './common.dart';
import './iot_web.dart';
import './connection.dart';

void _pushWebRoute(BuildContext context, Function navigationCallback,
    dynamic arg, Function callbackFromJavascript) {
  dlog("URL: " + arg);
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
      {Key key,
      @required this.connection,
      this.navigationCallback,
      this.callbackFromJavascript})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _pushWebRoute(context, navigationCallback, '${connection.webview}',
            callbackFromJavascript);
      },
      child: GestureDetector(
        onTap: () {
          _pushWebRoute(context, navigationCallback, '${connection.webview}',
              callbackFromJavascript);
        },
        child: Card(
          child: ListTile(
            leading: connection.logo,
            title: Text(connection.name),
            trailing: connection.icon,
          ),
        ),
      ),
    );
  }
}

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
    return Card(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.all(0),
          primary: Theme.of(context).cardColor,
          onPrimary: Theme.of(context).splashColor,
          //.withOpacity(0.1), //.withOpacity(0.5),
          // .withOpacity(0.01), //Theme.of(context).primaryColor,
          // surfaceTintColor: Theme.of(context).hoverColor.withOpacity(0.1),
          // surfaceTintColor: Theme.of(context).primaryColor.withOpacity(0.1),
          splashFactory: InkRipple.splashFactory,
          // overlayColor: MaterialStateProperty.all(
          //     Theme.of(context).primaryColor.withOpacity(0.1)),
          // // surfaceTintColor: MaterialStateProperty.all(Colors.white),
          // // elevation: MaterialStateProperty.all(0),
          // backgroundColor:
          //     MaterialStateProperty.all(Colors.white), //resolveWith<Color>(
          // // (Set<MaterialState> states) {),
        ),
        onPressed: () {
          _pushWebRoute(context, navigationCallback, '${connection.webview}',
              callbackFromJavascript);
        },
        child: ListTile(
          // contentPadding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 0.0),
          leading: connection.logo,
          title: Text(connection.name),
          trailing: connection.icon,
        ),
      ),
    );
  }
}

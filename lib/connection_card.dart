// @dart=2.9
// ^ Removes checks for null safety
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import './common.dart';
import './iot_web.dart';
import './connection.dart';

// TODO: Maybe not stateful?
class ConnectionCard extends StatefulWidget {
  final Connection connection;
  final Function navigationCallback;
  final Function callbackFromJavascript;

  const ConnectionCard(
      {Key key,
      @required this.connection,
      this.navigationCallback,
      this.callbackFromJavascript})
      : super(key: key);

  @override
  _ConnectionCardState createState() => _ConnectionCardState();
}

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

class _ConnectionCardState extends State<ConnectionCard> {
  @override
  Widget build(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    print(width);
    var cardWidth = (width < 500.0) ? (width * 0.34) : (width * 0.175);

    return GestureDetector(
      onTap: () {
        _pushWebRoute(context, widget.navigationCallback,
            '${widget.connection.webview}', widget.callbackFromJavascript);
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          child: SizedBox(
            width: cardWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.connection.name,
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.connection.brand,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  //style: Theme.of(context).textTheme.bodyMedium,
                ),
                Container(
                  alignment: Alignment.centerRight,
                  child: widget.connection.icon,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

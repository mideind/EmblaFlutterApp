// @dart=2.9
// ^ Removes checks for null safety
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import './common.dart';
import './web.dart';
import './connection.dart';

// TODO: Maybe not stateful?
class ConnectionCard extends StatefulWidget {
  final Connection connection;

  const ConnectionCard({Key key, this.connection}) : super(key: key);

  @override
  _ConnectionCardState createState() => _ConnectionCardState();
}

void _pushWebRoute(BuildContext context, dynamic arg) {
  dlog("URL: " + arg);
  Navigator.push(
    context,
    CupertinoPageRoute(
      builder: (context) => WebViewRoute(initialURL: arg),
    ),
  );
}

class _ConnectionCardState extends State<ConnectionCard> {
  int counter = 0;

  @override
  Widget build(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    //print(width);
    var cardWidth = (width < 500.0) ? (width * 0.35) : (width * 0.175);

    return GestureDetector(
      onTap: () {
        //counter++;
        dlog("Counter: $counter");
        _pushWebRoute(context,
            '${widget.connection.webview}'); // http://192.168.1.76:5000/iot/
        // kAboutURL);
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

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

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../common.dart';

import './smarthome_web.dart';
import './connection.dart';

// TODO: Maybe not stateful?
class ConnectionCard extends StatefulWidget {
  final Connection connection;
  final Function? navigationCallback;
  final Function callbackFromJavascript;

  const ConnectionCard(
      {Key? key,
      required this.connection,
      this.navigationCallback,
      required this.callbackFromJavascript})
      : super(key: key);

  @override
  ConnectionCardState createState() => ConnectionCardState();
}

// Pushes a webroute on the navigation stack
// If there is a navigation callback, call it
// when returning to the previous route
void _pushWebRoute(BuildContext context, Function? navigationCallback, dynamic arg,
    Function callbackFromJavascript) {
  dlog("URL: $arg");
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

class ConnectionCardState extends State<ConnectionCard> {
  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double cardWidth = (width < 500.0) ? (width * 0.34) : (width * 0.175);

    return Card(
      semanticContainer: false,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: 15.0,
            vertical: 10.0,
          ),
          backgroundColor: Theme.of(context).cardColor,
          foregroundColor: Theme.of(context).splashColor,
          splashFactory: InkRipple.splashFactory,
        ),
        onPressed: () {
          _pushWebRoute(context, widget.navigationCallback, widget.connection.webview,
              widget.callbackFromJavascript);
        },
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
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Container(
                alignment: Alignment.centerRight,
                child: widget.connection.icon,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

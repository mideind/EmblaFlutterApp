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

import 'smarthome_web.dart';
import './connection.dart';

// Pushes a webroute on the navigation stack
// If there is a navigation callback, call it
// when returning to the previous route
void _pushWebRoute(BuildContext context, Function? navigationCallback, dynamic arg,
    Function? callbackFromJavascript) {
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
  final Function? navigationCallback;
  final Function? callbackFromJavascript;

  const ConnectionListItem(
      {Key? key, required this.connection, this.navigationCallback, this.callbackFromJavascript})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.all(0),
          backgroundColor: Theme.of(context).cardColor,
          foregroundColor: Theme.of(context).splashColor,
          splashFactory: InkRipple.splashFactory,
        ),
        onPressed: () {
          _pushWebRoute(context, navigationCallback!, connection.webview, callbackFromJavascript);
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

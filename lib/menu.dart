/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2020 Miðeind ehf. <mideind@mideind.is>
 * Author: Sveinbjorn Thordarson
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

// Menu view

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import './settings.dart' show SettingsRoute;
import './theme.dart' show bgColor, defaultTextStyle;
import './web.dart';
import './common.dart';

var menuContext;

void _pushSettings() {
  Navigator.push(
    menuContext,
    MaterialPageRoute(
      builder: (context) => SettingsRoute(),
    ),
  );
}

void _pushAbout() {
  Navigator.push(
    menuContext,
    MaterialPageRoute(
      builder: (context) => WebViewRoute(initialURL: kAboutURL),
    ),
  );
}

void _pushInstructions() {
  Navigator.push(
    menuContext,
    MaterialPageRoute(
      builder: (context) => WebViewRoute(initialURL: kInstructionsURL),
    ),
  );
}

void _pushPrivacy() {
  Navigator.push(
    menuContext,
    MaterialPageRoute(
      builder: (context) => WebViewRoute(initialURL: kPrivacyURL),
    ),
  );
}

ListTile _generateTile(String name, String imageName, Function onTapFunc) {
  return ListTile(
    title: Text(name, style: defaultTextStyle),
    //leading: const Icon(CupertinoIcons.gear),
    leading: Image(image: AssetImage("assets/images/$imageName.png")),
    trailing: Icon(Icons.arrow_right, color: Colors.red),
    onTap: onTapFunc,
  );
}

// List of menu tiles
var list = ListView(
  padding: const EdgeInsets.all(8),
  children: <Widget>[
    _generateTile('Stillingar', 'cog', _pushSettings),
    _generateTile('Um Emblu', 'cube', _pushAbout),
    _generateTile('Leiðbeiningar', 'cube', _pushInstructions),
    _generateTile('Persónuvernd', 'cube', _pushPrivacy),
  ],
);

class MenuRoute extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    menuContext = context;
    return Scaffold(
        appBar: AppBar(
          backgroundColor: bgColor,
          bottomOpacity: 0.0,
          elevation: 0.0,
        ),
        body: list);
  }
}

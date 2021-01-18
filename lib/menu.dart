/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2021 Miðeind ehf. <mideind@mideind.is>
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

// Menu route

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import './common.dart';
import './settings.dart' show SettingsRoute;
import './theme.dart' show bgColor, mainColor, menuTextStyle;
import './web.dart' show WebViewRoute;

void _pushSettings(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => SettingsRoute(),
    ),
  );
}

void _pushAbout(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => WebViewRoute(initialURL: kAboutURL),
    ),
  );
}

void _pushInstructions(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => WebViewRoute(initialURL: kInstructionsURL),
    ),
  );
}

void _pushPrivacy(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => WebViewRoute(initialURL: kPrivacyURL),
    ),
  );
}

ListTile _generateTile(String name, String imageName, Function onTapFunc, BuildContext context) {
  return ListTile(
    title: Text(name, style: menuTextStyle),
    leading: Image(image: AssetImage("assets/images/$imageName.png")),
    trailing: Icon(Icons.arrow_right, color: mainColor),
    onTap: () {
      if (onTapFunc is Function) {
        onTapFunc(context);
      }
    },
  );
}

// Generate list of menu tiles
ListView _generateMenu(BuildContext context) {
  return ListView(
    padding: const EdgeInsets.all(8),
    children: <Widget>[
      _generateTile('Stillingar', 'cog', _pushSettings, context),
      _generateTile('Um Emblu', 'cube', _pushAbout, context),
      _generateTile('Leiðbeiningar', 'cube', _pushInstructions, context),
      _generateTile('Persónuvernd', 'cube', _pushPrivacy, context),
    ],
  );
}

class MenuRoute extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: bgColor,
          bottomOpacity: 0.0,
          elevation: 0.0,
        ),
        body: _generateMenu(context));
  }
}

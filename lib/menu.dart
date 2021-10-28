/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2021 Miðeind ehf. <mideind@mideind.is>
 * Original author: Sveinbjorn Thordarson
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
import './theme.dart' show standardAppBar, mainColor, menuTextStyle;
//import './train.dart' show TrainingRoute;
import './web.dart' show WebViewRoute;

void _pushSettingsRoute(BuildContext context, dynamic arg) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => SettingsRoute(),
    ),
  );
}

void _pushHotwordTrainingRoute(BuildContext context, dynamic arg) {
  // Navigator.push(
  //   context,
  //   MaterialPageRoute(
  //     builder: (context) => TrainingRoute(),
  //   ),
  // );
}

void _pushWebRoute(BuildContext context, dynamic arg) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => WebViewRoute(initialURL: arg),
    ),
  );
}

// Generate a menu tile based on args
ListTile _generateTile(
    String name, String imageName, Function onTapFunc, BuildContext context, dynamic arg) {
  return ListTile(
    title: Text(name, style: menuTextStyle),
    leading: Image(image: AssetImage("assets/images/$imageName.png")),
    trailing: Icon(Icons.arrow_right, color: mainColor),
    onTap: () {
      if (onTapFunc is Function) {
        onTapFunc(context, arg);
      }
    },
  );
}

// Generate list of menu tiles
ListView _generateMenu(BuildContext context) {
  return ListView(
    padding: const EdgeInsets.all(8),
    children: <Widget>[
      _generateTile('Stillingar', 'cog', _pushSettingsRoute, context, null),
      _generateTile('Þjálfa raddvirkjun', 'cog', _pushHotwordTrainingRoute, context, null),
      _generateTile('Um Emblu', 'cube', _pushWebRoute, context, kAboutURL),
      _generateTile('Leiðbeiningar', 'cube', _pushWebRoute, context, kInstructionsURL),
      _generateTile('Persónuvernd', 'cube', _pushWebRoute, context, kPrivacyURL),
    ],
  );
}

class MenuRoute extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: standardAppBar, body: _generateMenu(context));
  }
}

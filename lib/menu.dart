/*
 * This file is part of the Embla Flutter app
 * Copyright (c) 2020 Miðeind ehf.
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
import './web.dart';

var menuContext;

final TextStyle textStyle = TextStyle(fontSize: 20.0);

void pushSettings() {
  Navigator.push(
    menuContext,
    MaterialPageRoute(
      builder: (context) => SettingsRoute(),
    ),
  );
}

void pushAbout() {
  Navigator.push(
    menuContext,
    MaterialPageRoute(
      builder: (context) => AboutRoute(),
    ),
  );
}

void pushInstructions() {
  Navigator.push(
    menuContext,
    MaterialPageRoute(
      builder: (context) => InstructionsRoute(),
    ),
  );
}

void pushPrivacy() {
  Navigator.push(
    menuContext,
    MaterialPageRoute(
      builder: (context) => PrivacyRoute(),
    ),
  );
}

var list = ListView(
  padding: const EdgeInsets.all(8),
  children: <Widget>[
    ListTile(
      title: const Text("Stillingar", style: TextStyle(fontSize: 18.0, color: Colors.red)),
      //leading: const Icon(CupertinoIcons.gear),
      leading: Image(image: AssetImage('images/cube.png')),
      trailing: Icon(Icons.arrow_right, color: Colors.red),
      onTap: pushSettings,
    ),
    ListTile(
      title: const Text("Um Emblu", style: TextStyle(fontSize: 18.0, color: Colors.red)),
      leading: Image(image: AssetImage('images/cube.png')),
      trailing: Icon(Icons.arrow_right, color: Colors.red),
      onTap: pushAbout,
    ),
    ListTile(
      title: const Text(
        "Leiðbeiningar",
        style: TextStyle(fontSize: 18.0, color: Colors.red),
      ),
      leading: Image(image: AssetImage('images/cube.png')),
      trailing: Icon(Icons.arrow_right, color: Colors.red),
      onTap: pushInstructions,
    ),
    ListTile(
      title: const Text("Persónuvernd", style: TextStyle(fontSize: 18.0, color: Colors.red)),
      leading: Image(image: AssetImage('images/cube.png')),
      trailing: Icon(Icons.arrow_right, color: Colors.red),
      onTap: pushPrivacy,
    ),
  ],
);

class MenuRoute extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    menuContext = context;
    return Scaffold(
        appBar: AppBar(
          title: const Text(""),
          // leading: const Text("Til baka"),
          backgroundColor: Colors.transparent,
          bottomOpacity: 0.0,
          elevation: 0.0,
        ),
        body: list);
  }
}

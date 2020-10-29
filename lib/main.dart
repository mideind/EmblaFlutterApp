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

// App & main view

import 'dart:io';
import 'dart:convert' show json;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart' show AudioPlayer;

import './menu.dart' show MenuRoute;
import './prefs.dart' show Prefs;
import './common.dart';
import './session.dart' show SessionWidget;

final defaultTheme = ThemeData(
    // Define the default brightness and colors.
    // brightness: Brightness.dark,
    // accentColor: Colors.cyan[600],
    scaffoldBackgroundColor: Color(0xFFF9F9F9),
    primarySwatch: Colors.red,
    fontFamily: 'Lato',
    primaryColor: Colors.red,
    backgroundColor: Colors.grey,
    textTheme: TextTheme(bodyText2: TextStyle(color: Colors.red, fontSize: 16.0)),
    appBarTheme: AppBarTheme(
      brightness: Brightness.light,
      color: Colors.transparent,
      textTheme: TextTheme().apply(displayColor: Colors.red),
      iconTheme: IconThemeData(color: Colors.red),
    ));

final app = MaterialApp(title: "Embla", home: MainRoute(), theme: defaultTheme);
final audioPlayer = AudioPlayer();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpClient.enableTimelineLogging = true;

  await Prefs().load();
  bool launched = Prefs().boolForKey('launched');
  if (launched == null || launched == false) {
    dlog("Setting default prefs on first launch");
    Prefs().setDefaults();
  }
  dlog(Prefs().desc());

  runApp(app);
}

void handleResponse(r) async {
  final j = json.decode(r.body);
  dlog(j["answer"]);
  int result = await audioPlayer.play(j["audio"]);
  print("Audio player result: $result");
}

class VoiceActivationWidget extends StatefulWidget {
  @override
  _VoiceActivationWidgetState createState() => _VoiceActivationWidgetState();
}

class _VoiceActivationWidgetState extends State<VoiceActivationWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
        child: IconButton(
      icon: ImageIcon(AssetImage('assets/images/mic.png')),
      onPressed: () {},
    ));
  }
}

class MainRoute extends StatelessWidget {
  final toggleButton = Text('Send query');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          bottomOpacity: 0.0,
          elevation: 0.0,
          leading: VoiceActivationWidget(),
          actions: <Widget>[
            // Action button
            IconButton(
              icon: ImageIcon(AssetImage('assets/images/menu.png')),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => MenuRoute()));
              },
            )
          ]),
      body: Center(child: SessionWidget()),
    );
  }
}

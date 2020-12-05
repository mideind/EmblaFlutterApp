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

// App initialization and presentation of main view

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import './menu.dart' show MenuRoute;
import './prefs.dart' show Prefs;
import './session.dart' show SessionWidget;
import './loc.dart' show LocationTracking;
import './connectivity.dart' show ConnectivityMonitor;
import './anim.dart' show preloadAnimationFrames;
import './audio.dart' show preloadAudioFiles, stopSound;
import './theme.dart' show defaultTheme, bgColor;
import './common.dart' show dlog;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpClient.enableTimelineLogging = true;

  // Load prefs and populate with default values if required
  await Prefs().load();
  bool launched = Prefs().boolForKey('launched');
  if (launched == null || launched == false) {
    dlog("Setting default prefs on first launch");
    Prefs().setDefaults();
  }
  dlog("Shared prefs: " + Prefs().desc());

  // Preload assets
  await preloadAudioFiles();
  await preloadAnimationFrames();

  // Start monitoring internet connectivity
  await ConnectivityMonitor().start();

  // Set up location tracking
  if (Prefs().boolForKey('share_location')) {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission != LocationPermission.denied && permission != LocationPermission.deniedForever) {
      LocationTracking().start();
    }
  }

  // Launch app
  runApp(MaterialApp(title: "Embla", home: MainRoute(), theme: defaultTheme));
}

// Top left button to toggle voice activation
class ToggleVoiceActivationWidget extends StatefulWidget {
  @override
  _ToggleVoiceActivationWidgetState createState() => _ToggleVoiceActivationWidgetState();
}

class _ToggleVoiceActivationWidgetState extends State<ToggleVoiceActivationWidget> {
  @override
  Widget build(BuildContext context) {
    String iconName = Prefs().boolForKey('voice_activation') ? 'mic.png' : 'mic-slash.png';
    return IconButton(
      icon: ImageIcon(AssetImage('assets/images/' + iconName)),
      onPressed: () {
        setState(() {
          Prefs().setBoolForKey('voice_activation', !Prefs().boolForKey('voice_activation'));
        });
      },
    );
  }
}

// Main screen
class MainRoute extends StatefulWidget {
  @override
  _MainRouteState createState() => _MainRouteState();
}

class _MainRouteState extends State<MainRoute> {
  @override
  Widget build(BuildContext context) {
    // Present menu route
    void pushMenu() async {
      stopSound();
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MenuRoute(),
        ),
      ).then((val) {
        // Make sure we rebuild main route when menu route is popped in navigation
        // stack. This ensures that the state of the voice activation button is
        // updated to reflect potential changes in Settings.
        setState(() {});
      });
    }

    return Scaffold(
      appBar: AppBar(
          backgroundColor: bgColor,
          bottomOpacity: 0.0,
          elevation: 0.0,
          leading: ToggleVoiceActivationWidget(),
          actions: <Widget>[
            IconButton(icon: ImageIcon(AssetImage('assets/images/menu.png')), onPressed: pushMenu)
          ]),
      body: SessionWidget(),
    );
  }
}
